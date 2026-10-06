// Contains code from CGPA_Calculator by Srijen Raja (Apache License 2.0),
// modified by Siddharth Mishra. See NOTICE.
import 'dart:async';

import 'package:cgpa_calculator/features/setup/owner_setup_page.dart';
import 'package:cgpa_calculator/app/theme/circle_reveal.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/prefs/prefs_store.dart';
import 'package:cgpa_calculator/core/cache/cache_first.dart';
import 'package:cgpa_calculator/core/perf/device_tier.dart';
import 'package:cgpa_calculator/core/perf/frame_hud.dart';
import 'package:cgpa_calculator/core/catalog/catalog_store.dart';
import 'package:cgpa_calculator/core/diag/sign_in_log.dart';
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
import 'package:cgpa_calculator/app/prefetch_levels.dart';
import 'package:cgpa_calculator/app/router.dart';
import 'package:cgpa_calculator/core/live/live_heads.dart';
import 'package:cgpa_calculator/core/prefetch/prefetch.dart';
import 'package:cgpa_calculator/features/setup/campus_pick_page.dart' show viewCampus;
import 'package:cgpa_calculator/script.dart';
import 'package:cgpa_calculator/sync.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:cgpa_calculator/core/models/marks.dart';
import 'package:cgpa_calculator/features/auth/sign_in_view.dart';
import 'package:cgpa_calculator/features/auth/test_account_sheet.dart';

void main() async {
  // Real paths (/calculator/stats), not #/stats (ARCHITECTURE.md §7).
  usePathUrlStrategy();
  // Pages opened with push show their path too, so they can be bookmarked.
  GoRouter.optionURLReflectsImperativeAPIs = true;
  WidgetsFlutterBinding.ensureInitialized();
  // Touch resampling (on since 26 Sep) held the finger's position ~38 ms
  // back and let it catch up in a leap on lift; with frames on time since
  // the 2x cap, the owner found the app smoother and more responsive
  // without it (2026-10-04). ?resample=1 turns it on, to compare.
  GestureBinding.instance.resamplingEnabled =
      Uri.base.queryParameters['resample'] == '1';
  beforeFirebase();
  // Each step before the first frame is timed (perf and test builds only):
  // `window.pointerPerf.timings()` shows which one holds the app back.
  await Perf.time('startup.firebaseInit', () => Firebase.initializeApp(
    options: appEnv == AppEnv.staging
        ? StagingFirebaseOptions.currentPlatform
        // The emulators hold one project's data per id: the seed's.
        : appEnv == AppEnv.emulator
        ? DefaultFirebaseOptions.currentPlatform
            .copyWith(projectId: 'demo-pointer')
        : DefaultFirebaseOptions.currentPlatform,
  ));
  configureEnv();
  await Perf.time('startup.hiveInit', Hive.initFlutter);
  Hive.registerAdapter(CourseAdapter());
  registerMarksAdapters();
  await Perf.time('startup.openBoxes', Sync.openBoxes);
  String? message;
  if (takeSignInRedirect()) {
    // Back from Google on a fresh load: the result, or why it failed.
    try {
      await FirebaseAuth.instance.getRedirectResult();
    } on FirebaseAuthException catch (e) {
      signInFailed('redirect-result', e);
      message = 'Sign-in failed: ${e.message ?? e.code}';
    }
  }
  if (isTestEnv) {
    // A refused test sign-in (a stale password) must not stop the app
    // before its first frame: say why and fall through to sign-in.
    try {
      await Perf.time('startup.testSignIn', testSignIn);
    } on FirebaseAuthException catch (e) {
      debugPrint('[Pointer test] ?as= sign-in refused: ${e.code}');
      message = 'Test sign-in refused (${e.code}). Re-run the staging seed.';
      // A refusal can leave a half-signed-in user behind (user-token-
      // expired, TM-11); drop it so the sign-in screen shows the message.
      await FirebaseAuth.instance.signOut();
    }
  }
  final user = await Perf.time(
    'startup.authState',
    () => FirebaseAuth.instance.authStateChanges().first,
  );
  final allowed = user == null
      ? false
      : await Perf.time('startup.mayUseApp', () => mayUseApp(user));
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
  await Perf.time(
    'startup.openLocalBoxes',
    () => Future.wait([openDeviceBox(), openResources(), openReviews()]),
  );
  myUid = user.uid;
  // Prefs (B1): the device copy is read at once; the server's follows after
  // the first frame.
  final prefs = prefsStore = PrefsStore(FirebaseFirestore.instance, uid: user.uid);
  WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(prefs.pull()));
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
    // ARCHITECTURE.md §13: screens load ahead, level by level, after the
    // first frame.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(rolesDone.then((_) {}, onError: (Object _) {}).whenComplete(() {
        try {
          return runPrefetch(prefetchLevels());
        } catch (e) {
          debugPrint('prefetch: $e');
          return null;
        }
      })),
    );
    // The live socket (LOADING_SERVER_PLAN.md D3): moved markers and this
    // account's version, after the first frame. Off without POINTER_LIVE_URL.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final campus = viewCampus();
      if (campus != null) {
        LiveHeads.start(
          campus,
          () => user.getIdToken(),
          onMe: Sync.pullLive,
          loadMe: () => Sync.liveMe,
          saveMe: Sync.setLiveMe,
        );
      }
    });
    // A deep link on a first sign-in has no cached roles yet, and its guard
    // (/maintain, /admin) would send it Home: wait for them (BUG-51).
    // Match the guarded routes, not "any path": prod serves the app at /calculator/.
    final guarded = RegExp(r'/(maintain|admin)(/|$)').hasMatch(Uri.base.path);
    if (guarded && !myRoles.value.privileged) {
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

/// Phones and tablets sign in by redirect: there a popup is a separate tab
/// or window that Firebase loses track of ("the popup has been closed by
/// the user" right after the tap), and an iOS home-screen app blocks it
/// outright. The redirect works because the auth helper is served from this
/// site (authDomain, landing/__/auth/). Computers use the popup, and the
/// redirect once a popup has failed.
bool signsInByRedirect() =>
    kIsWeb && (_popupFailed || redirectsOn(installTarget().device));

/// Whether [device] signs in by redirect rather than a popup.
@visibleForTesting
bool redirectsOn(InstallDevice device) => device != InstallDevice.desktop;

bool _popupFailed = false;

/// Leaves for Google; main() picks the result up on the way back.
Future<void> _redirect(AuthProvider provider) {
  markSignInRedirect();
  return FirebaseAuth.instance.signInWithRedirect(provider);
}

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

/// The app shown to signed-out people: the sign-in screen, with an optional
/// [message] such as why an address was refused.
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
    signInStarted();
    var stage = 'popup';
    try {
      final provider =
          GoogleAuthProvider()
            // Let people pick their BITS account even if a personal Google
            // session is already active in the browser.
            ..setCustomParameters({'prompt': 'select_account'});
      if (signsInByRedirect()) {
        stage = 'redirect-start';
        await _redirect(provider);
        return;
      }
      final UserCredential cred;
      try {
        cred = await FirebaseAuth.instance.signInWithPopup(provider);
      } on FirebaseAuthException catch (e) {
        // A browser that blocks the popup can still take the redirect.
        if (e.code == 'popup-closed-by-user') _popupFailed = true;
        if (e.code != 'popup-blocked') rethrow;
        signInFailed('popup', e);
        stage = 'redirect-start';
        await _redirect(provider);
        return;
      }
      final user = cred.user;
      if (user == null) throw FirebaseAuthException(code: 'no-user');
      stage = 'may-use-app';
      final allowed = await mayUseApp(user);
      if (allowed != true) {
        await FirebaseAuth.instance.signOut();
        stage = 'refused-${allowed ?? 'unknown'}';
        throw refusal(user, allowed);
      }
      signInSucceeded();
      stage = 'start-app';
      await startApp(user); // replaces this app with the real one
      return;
    } catch (e) {
      signInFailed(stage, e);
      if (!mounted) return;
      setState(() => _busy = false);
      _show(
        e is String
            ? e
            : e is FirebaseAuthException && e.code == 'popup-closed-by-user'
            ? 'The sign-in window closed before it finished. Tap Sign in '
                'again: this time it opens Google in this tab.'
            : 'Sign-in failed: '
                '${e is FirebaseAuthException ? (e.message ?? e.code) : e}',
      );
    }
  }

  /// Staging: a test account by email and password, then the same checks
  /// as Google's.
  Future<void> _signInTestAccount() async {
    final pick = await pickTestAccount(context);
    if (pick == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final user =
          (await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: pick.email,
            password: pick.password,
          )).user!;
      final allowed = await mayUseApp(user);
      if (allowed != true) {
        await FirebaseAuth.instance.signOut();
        throw refusal(user, allowed);
      }
      await startApp(user);
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
      home: SignInView(
        busy: _busy,
        onSignIn: _signIn,
        // Staging only; production drops it (const isTestEnv).
        onTestSignIn: isTestEnv ? _signInTestAccount : null,
        entrance: _entrance,
      ),
    );
  }
}

/// The signed-in app: theme, router and the global overlays.
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
                (_, child) => FrameHud(
                  child: ThemeReveal.root(
                    TapOriginTracker(child: RoleStrip(child: child!)),
                  ),
                ),
          ),
    );
  }
}
