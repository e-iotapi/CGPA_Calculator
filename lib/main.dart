import 'dart:async';

import 'package:cgpa_calculator/app/theme/circle_reveal.dart';
import 'package:cgpa_calculator/core/catalog/catalog_store.dart';
import 'package:cgpa_calculator/core/env/app_env.dart';
import 'package:cgpa_calculator/core/env/test_sign_in.dart';
import 'package:cgpa_calculator/core/storage/course_link.dart';
import 'package:cgpa_calculator/core/storage/offerings.dart';
import 'package:cgpa_calculator/features/marks/official.dart';
import 'package:cgpa_calculator/core/resources/resource_store.dart';
import 'package:cgpa_calculator/core/reviews/review_store.dart';
import 'package:cgpa_calculator/features/roles/rep_profile.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/features/roles/role_switch_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cgpa_calculator/auth_util.dart';
import 'package:cgpa_calculator/core/platform/browser.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/firebase_options.dart';
import 'package:cgpa_calculator/firebase_options_staging.dart';
import 'package:cgpa_calculator/app/router.dart';
import 'package:cgpa_calculator/script.dart';
import 'package:cgpa_calculator/sync.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cgpa_calculator/core/models/marks.dart';
import 'package:cgpa_calculator/features/auth/sign_in_view.dart';

void main() async {
  // Real paths (/calculator/stats), not #/stats (ARCHITECTURE.md §7).
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  // Phone browsers deliver touches out of step with frames, so a drag moves
  // the list unevenly. Resampling lines the touches up with the frames.
  GestureBinding.instance.resamplingEnabled = true;
  await Firebase.initializeApp(
    options: appEnv == AppEnv.staging
        ? StagingFirebaseOptions.currentPlatform
        : DefaultFirebaseOptions.currentPlatform,
  );
  configureEnv();
  await Hive.initFlutter();
  Hive.registerAdapter(CourseAdapter());
  registerMarksAdapters();
  await Sync.openBoxes();
  String? message;
  if (signsInByRedirect()) {
    // Back from Google on a fresh load: the result, or why it failed.
    try {
      await FirebaseAuth.instance.getRedirectResult();
    } on FirebaseAuthException catch (e) {
      message = 'Sign-in failed: ${e.message ?? e.code}';
    }
  }
  if (isTestEnv) await testSignIn();
  final user = await FirebaseAuth.instance.authStateChanges().first;
  final allowed = user == null ? false : await mayUseApp(user);
  if (user == null || allowed != true) {
    // A session that predates the restriction, or a non-BITS account that
    // is not an owner. Unknown (offline) keeps the session for next time.
    if (user != null && allowed == false) {
      await FirebaseAuth.instance.signOut();
      message = refusal(user, allowed);
    }
    runApp(SignInApp(message: message));
  } else {
    await startApp(user);
  }
}

/// Pulls the user's data down before basicStartup() reads settings into globals.
Future<void> startApp(User user) async {
  // Boot from the cached or shipped catalogue; a newer published one is
  // fetched in the background and used from then on (ARCHITECTURE.md §3).
  // Before Sync: stored courses link to it by id.
  await loadCatalog();
  await Sync.init(user.uid);
  await openOfferings();
  offeringSource = FirestoreOfferingSource();
  unawaited(refreshCatalog(
    FirestoreCatalogSource(),
    beforeUse: relinkStoredCourses,
  ));
  await basicStartup();
  unawaited(refreshCurrentOfferings());
  // Roles (ARCHITECTURE.md §4): the last known set opens at once, the live
  // one follows.
  await openDeviceBox();
  await openResources();
  await openReviews();
  myUid = user.uid;
  stripNavigate = appRouter.go;
  restoreMyRoles();
  final email = user.email;
  // startApp only ever runs once mayUseApp(user) was true, i.e. a BITS
  // address or an owner (auth_util.dart) — never neither, so roleStore
  // covers a non-BITS owner too. Only recordSignIn below needs a campus.
  if (email != null) {
    final store = roleStore = RoleStore(
      FirebaseFirestore.instance,
      me: email,
      myName: user.displayName ?? '',
      actingAs: actingNow,
    );
    if (campusOfAddress(email) case final campus?) {
      unawaited(store
          .recordSignIn(name: user.displayName ?? '', campus: campus)
          .catchError((_) {}));
    }
    unawaited(refreshMyRoles().then((_) => checkProfile()));
  }
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(MyApp());
}

/// A home-screen app on iOS loses the popup: Safari blocks it, or it opens
/// and never reports back. There the sign-in is a redirect instead, which
/// works only because the auth helper is served from this site (authDomain,
/// landing/__/auth/).
bool signsInByRedirect() =>
    kIsWeb && isStandalone() && installTarget().device == InstallDevice.ios;

/// Why [user] was turned away; [allowed] is what mayUseApp said.
String refusal(User user, bool? allowed) {
  final rejected = user.email ?? 'that account';
  return allowed == null
      ? 'Could not check $rejected. Check your connection and try again.'
      : 'Sign in with your BITS email. $rejected is not a '
          'BITS Pilani campus account.';
}

class SignInApp extends StatefulWidget {
  const SignInApp({super.key, this.message});

  /// Shown once on arrival, e.g. why a redirect sign-in was refused.
  final String? message;

  @override
  State<SignInApp> createState() => _SignInAppState();
}

class _SignInAppState extends State<SignInApp>
    with SingleTickerProviderStateMixin {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  bool _busy = false;
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
  )..forward();

  @override
  void initState() {
    super.initState();
    final message = widget.message;
    if (message != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _show(message));
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  /// Fades and lifts [child] into place, staggered by [order].
  Widget _entrance(int order, Widget child) {
    final start = (order * 0.1).clamp(0.0, 0.7);
    final curve = CurvedAnimation(
      parent: _intro,
      curve: Interval(start, (start + 0.45).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curve,
      builder:
          (_, c) => Opacity(
            opacity: curve.value,
            child: Transform.translate(
              offset: Offset(0, 18 * (1 - curve.value)),
              child: c,
            ),
          ),
      child: child,
    );
  }

  Future<void> _signIn() async {
    setState(() => _busy = true);
    try {
      final provider =
          GoogleAuthProvider()
            // Let people pick their BITS account even if a personal Google
            // session is already active in the browser.
            ..setCustomParameters({'prompt': 'select_account'});
      if (signsInByRedirect()) {
        // Leaves the page; main() picks the result up on the way back.
        await FirebaseAuth.instance.signInWithRedirect(provider);
        return;
      }
      final UserCredential cred;
      try {
        cred = await FirebaseAuth.instance.signInWithPopup(provider);
      } on FirebaseAuthException catch (e) {
        // A browser that blocks the popup can still take the redirect.
        if (e.code != 'popup-blocked') rethrow;
        await FirebaseAuth.instance.signInWithRedirect(provider);
        return;
      }
      final user = cred.user;
      if (user == null) throw FirebaseAuthException(code: 'no-user');
      final allowed = await mayUseApp(user);
      if (allowed != true) {
        await FirebaseAuth.instance.signOut();
        throw refusal(user, allowed);
      }
      await startApp(user); // replaces this app with the real one
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _show(
        e is String
            ? e
            : 'Sign-in failed: '
                '${e is FirebaseAuthException ? (e.message ?? e.code) : e}',
      );
    }
  }

  void _show(String text) {
    _messengerKey.currentState?.showSnackBar(
      SnackBar(
        backgroundColor: thm.cardcolor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: thm.bordcolor.withValues(alpha: 0.2)),
        ),
        content: Text(
          text,
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 13,
            color: thm.textcolor,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pointer',
      scaffoldMessengerKey: _messengerKey,
      debugShowCheckedModeBanner: false,
      theme: thm.materialTheme,
      home: SignInView(busy: _busy, onSignIn: _signIn, entrance: _entrance),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuilt when the theme changes, under the circle reveal.
    return ValueListenableBuilder(
      valueListenable: themeVersion,
      builder:
          (_, _, _) => MaterialApp.router(
            title: 'Pointer',
            theme: thm.materialTheme,
            routerConfig: appRouter,
            builder:
                (_, child) => ThemeReveal.root(
                  TapOriginTracker(child: RoleStrip(child: child!)),
                ),
          ),
    );
  }
}
