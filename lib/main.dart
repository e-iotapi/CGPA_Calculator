import 'package:cgpa_calculator/app/theme/circle_reveal.dart';
import 'package:cgpa_calculator/auth_util.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/firebase_options.dart';
import 'package:cgpa_calculator/home_page.dart';
import 'package:cgpa_calculator/script.dart';
import 'package:cgpa_calculator/sync.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cgpa_calculator/core/models/marks.dart';
import 'package:cgpa_calculator/features/auth/sign_in_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Phone browsers deliver touches out of step with frames, so a drag moves
  // the list unevenly. Resampling lines the touches up with the frames.
  GestureBinding.instance.resamplingEnabled = true;
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Hive.initFlutter();
  Hive.registerAdapter(CourseAdapter());
  registerMarksAdapters();
  await Sync.openBoxes();
  final user = await FirebaseAuth.instance.authStateChanges().first;
  if (user == null || !isBitsEmail(user.email)) {
    // A session that predates the restriction, or a non-BITS account.
    if (user != null) await FirebaseAuth.instance.signOut();
    runApp(const SignInApp());
  } else {
    await startApp(user);
  }
}

/// Pulls the user's data down before basicStartup() reads settings into globals.
Future<void> startApp(User user) async {
  await Sync.init(user.uid);
  await basicStartup();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(MyApp());
}

class SignInApp extends StatefulWidget {
  const SignInApp({super.key});

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
      final cred = await FirebaseAuth.instance.signInWithPopup(provider);
      final user = cred.user;
      if (user == null) throw FirebaseAuthException(code: 'no-user');
      if (!isBitsEmail(user.email)) {
        final rejected = user.email ?? 'that account';
        await FirebaseAuth.instance.signOut();
        throw 'Sign in with your BITS email. $rejected is not a '
            'BITS Pilani campus account.';
      }
      await startApp(user); // replaces this app with the real one
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _messengerKey.currentState?.showSnackBar(
        SnackBar(
          backgroundColor: thm.cardcolor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: thm.bordcolor.withValues(alpha: 0.2)),
          ),
          content: Text(
            e is String
                ? e
                : 'Sign-in failed: '
                    '${e is FirebaseAuthException ? (e.message ?? e.code) : e}',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 13,
              color: thm.textcolor,
            ),
          ),
        ),
      );
    }
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
          (_, _, _) => MaterialApp(
            title: 'Pointer',
            theme: thm.materialTheme,
            builder:
                (_, child) =>
                    ThemeReveal.root(TapOriginTracker(child: child!)),
            home: const MyHomePage(title: 'Pointer'),
          ),
    );
  }
}
