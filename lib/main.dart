import 'dart:async';

import 'package:cgpa_calculator/features/setup/owner_setup_page.dart';
import 'package:cgpa_calculator/app/theme/circle_reveal.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/cache/cache_first.dart';
import 'package:cgpa_calculator/core/perf/device_tier.dart';
import 'package:cgpa_calculator/core/catalog/catalog_store.dart';
import 'package:cgpa_calculator/core/env/app_env.dart';
import 'package:cgpa_calculator/core/env/test_sign_in.dart';
import 'package:cgpa_calculator/core/perf/perf.dart';
import 'package:cgpa_calculator/core/storage/course_link.dart';
import 'package:cgpa_calculator/core/storage/offerings.dart';
import 'package:cgpa_calculator/features/marks/official.dart';
import 'package:cgpa_calculator/core/resources/resource_store.dart';
import 'package:cgpa_calculator/core/reviews/review_store.dart';
import 'package:cgpa_calculator/features/roles/rep_profile.dart';
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
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:cgpa_calculator/core/models/marks.dart';
import 'package:cgpa_calculator/features/auth/sign_in_view.dart';

void main() async {
  // Real paths (/calculator/stats), not #/stats (ARCHITECTURE.md §7).
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  // Phone browsers deliver touches out of step with frames, so a drag moves
  // the list unevenly. Resampling lines the touches up with the frames.
  GestureBinding.instance.resamplingEnabled = true;
  beforeFirebase();
  await Firebase.initializeApp(
    options: appEnv == AppEnv.staging
        ? StagingFirebaseOptions.currentPlatform
        // The emulators hold one project's data per id: the seed's.
        : appEnv == AppEnv.emulator
        ? DefaultFirebaseOptions.currentPlatform
            .copyWith(projectId: 'demo-pointer')
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
  // Budget: timing only (P0); loadCatalog/Sync.init read no Firestore
  // documents worth counting on their own — Sync.pull's users/{uid} get is
  // counted inside sync.dart.
  // openOfferings/openSharedCache are independent Hive boxes: start them
  // alongside the catalogue load instead of after it.
  final catalogDone = Perf.time('startup.loadCatalog', loadCatalog);
  final offeringsDone = openOfferings();
  final sharedCacheDone = openSharedCache();
  await catalogDone;
  await Perf.time('startup.syncInit', () => Sync.init(user.uid));
  await offeringsDone;
  await sharedCacheDone; // before anything reads a campus head
  offeringSource = FirestoreOfferingSource();
  final bootCampus = Hive.box('settingsBox').get('campus') as String?;
  unawaited(refreshCatalog(
    bootCampus == null ? FirestoreCatalogSource() : HeadCatalogSource(bootCampus),
    beforeUse: relinkStoredCourses,
  ));
  await Perf.time('startup.basicStartup', basicStartup);
  unawaited(refreshCurrentOfferings());
  // Roles (ARCHITECTURE.md §4): the last known set opens at once, the live
  // one follows.
  await Future.wait([openDeviceBox(), openResources(), openReviews()]);
  myUid = user.uid;
  stripNavigate = appRouter.go;
  restoreMyRoles(email: user.email);
  final email = user.email;
  ownerSetupDue.value = ownerSetupNeeded(
    myRoles.value,
    email,
    Hive.box('settingsBox').get('campus') as String?,
  );
  if (email != null) {
    // ignore: invalid_use_of_visible_for_testing_member
    startRoles(
      FirebaseFirestore.instance,
      email: email,
      name: user.displayName ?? '',
    );
    final rolesDone = refreshMyRolesIfDue().then((_) => checkProfile());
    // A deep link on a first sign-in has no cached roles yet, and its guard
    // (/maintain, /admin) would send it Home: wait for them (BUG-51).
    if (Uri.base.path.length > 1 && !myRoles.value.privileged) {
      await rolesDone.catchError((Object _) {});
    } else {
      unawaited(rolesDone);
    }
  }
  // A platform-channel round trip; the lock takes effect whenever it lands
  // and does not need to gate the first frame.
  unawaited(SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]));
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
  if (allowed == false && isBitsEmail(rejected)) {
    return "Pointer is for BITS students. Faculty and staff accounts can't "
        'use it.';
  }
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
    // Reduced motion: everything is in place at once.
    if (MediaQuery.disableAnimationsOf(context)) return child;
    // UI_OPT O4.1: the fade is a FadeTransition (no Opacity layer per frame);
    // only the 18 px lift is a transform.
    return FadeTransition(
      opacity: curve,
      child: AnimatedBuilder(
        animation: curve,
        builder:
            (_, c) => Transform.translate(
              offset: Offset(0, 18 * (1 - curve.value)),
              child: c,
            ),
        child: child,
      ),
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
        backgroundColor: thm.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: thm.border.withValues(alpha: 0.2)),
        ),
        content: Text(
          text,
          style: TypeScale.body.copyWith(fontSize: 13, color: thm.text),
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
      themeAnimationDuration: Duration.zero,
      home: SignInView(busy: _busy, onSignIn: _signIn, entrance: _entrance),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static bool _tierMeasured = false;

  @override
  Widget build(BuildContext context) {
    // UI_OPT O0.2: once per app run, after the first frame, never from
    // startApp.
    if (!_tierMeasured) {
      _tierMeasured = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => measureDeviceTier());
    }
    // Rebuilt when the theme changes, under the circle reveal.
    return ValueListenableBuilder(
      valueListenable: themeVersion,
      builder:
          (_, _, _) => MaterialApp.router(
            title: 'Pointer',
            theme: thm.materialTheme,
            themeAnimationDuration: Duration.zero,
            routerConfig: appRouter,
            builder:
                (_, child) => ThemeReveal.root(
                  TapOriginTracker(child: RoleStrip(child: child!)),
                ),
          ),
    );
  }
}
