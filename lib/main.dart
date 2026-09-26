import 'package:cgpa_calculator/auth_util.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/firebase_options.dart';
import 'package:cgpa_calculator/home_page.dart';
import 'package:cgpa_calculator/script.dart';
import 'package:cgpa_calculator/sync.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cgpa_calculator/core/models/marks.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      title: 'CGPA Calculator',
      scaffoldMessengerKey: _messengerKey,
      debugShowCheckedModeBanner: false,
      theme: thm.materialTheme,
      home: Scaffold(
        backgroundColor: thm.backcolor,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) {
              final narrow = c.maxWidth < 360;
              return SingleChildScrollView(
                // Scrolls rather than overflowing on short/landscape windows.
                padding: EdgeInsets.symmetric(
                  horizontal: narrow ? 20 : 26,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: c.maxHeight - 48 > 0 ? c.maxHeight - 48 : 0,
                    maxWidth: 400,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _entrance(
                          0,
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              height: 62,
                              width: 62,
                              decoration: BoxDecoration(
                                color: thm.cardcolor,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: thm.bordcolor.withValues(alpha: 0.12),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.school_rounded,
                                size: 31,
                                color: thm.highcolor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 26),
                        _entrance(
                          1,
                          Text(
                            'CGPA',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: narrow ? 34 : 41,
                              height: 1.04,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -1.2,
                              color: thm.textcolor.withValues(alpha: 0.42),
                            ),
                          ),
                        ),
                        _entrance(
                          2,
                          Text(
                            'Calculator',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: narrow ? 34 : 41,
                              height: 1.04,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -1.2,
                              color: thm.textcolor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _entrance(
                          3,
                          Text(
                            'Track every semester, compare what-ifs and plan '
                            'your offshoot. Sign in with your BITS campus ID — '
                            'Pilani, Goa, Hyderabad or Dubai — and your grades '
                            'follow you to any device.',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 13.5,
                              height: 1.55,
                              color: thm.textcolor.withValues(alpha: 0.62),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        _entrance(
                          4,
                          SizedBox(
                            height: 56,
                            child: Material(
                              color: thm.textcolor,
                              borderRadius: BorderRadius.circular(28),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(28),
                                onTap: _busy ? null : _signIn,
                                child: Center(
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 220),
                                    child:
                                        _busy
                                            ? SizedBox(
                                              key: const ValueKey('busy'),
                                              height: 20,
                                              width: 20,
                                              child:
                                                  CircularProgressIndicator(
                                                    strokeWidth: 2.4,
                                                    color: thm.backcolor,
                                                  ),
                                            )
                                            : Row(
                                              key: const ValueKey('idle'),
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  height: 26,
                                                  width: 26,
                                                  decoration: BoxDecoration(
                                                    color: thm.backcolor,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    'G',
                                                    style: TextStyle(
                                                      fontFamily: 'Montserrat',
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: thm.highcolor,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 11),
                                                Flexible(
                                                  child: Text(
                                                    'Continue with Google',
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontFamily: 'Montserrat',
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: thm.backcolor,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _entrance(
                          5,
                          Text(
                            'Based on the CGPA Calculator by Srijen Raja · Apache-2.0',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 9.5,
                              color: thm.textcolor.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.noScaling),
          child: child!,
        );
      },
      title: 'CGPA Calculator',
      theme: thm.materialTheme,
      home: const MyHomePage(title: 'CGPA CALCULATOR'),
    );
  }
}
