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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Hive.initFlutter();
  Hive.registerAdapter(CourseAdapter());
  await Sync.openBoxes();
  final user = await FirebaseAuth.instance.authStateChanges().first;
  if (user == null) {
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

class _SignInAppState extends State<SignInApp> {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  bool _busy = false;

  Future<void> _signIn() async {
    setState(() => _busy = true);
    try {
      final cred = await FirebaseAuth.instance.signInWithPopup(
        GoogleAuthProvider(),
      );
      final user = cred.user;
      if (user == null) throw FirebaseAuthException(code: 'no-user');
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
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: thm.bordcolor, width: 1),
          ),
          content: Text(
            'Sign-in failed: ${e is FirebaseAuthException ? (e.message ?? e.code) : e}',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 14,
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: thm.highcolor),
      ),
      home: Scaffold(
        backgroundColor: thm.backcolor,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'CGPA CALCULATOR',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: thm.textcolor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Sign in to save your grades and pick them up on any device.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                      color: thm.textcolor.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 36),
                  SizedBox(
                    height: 52,
                    width: double.infinity,
                    child: FloatingActionButton.extended(
                      heroTag: 'google_sign_in',
                      backgroundColor: thm.cardcolor,
                      elevation: 1,
                      focusElevation: 0,
                      hoverElevation: 0,
                      highlightElevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: thm.bordcolor, width: 1),
                      ),
                      onPressed: _busy ? null : _signIn,
                      label:
                          _busy
                              ? SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: thm.highcolor,
                                ),
                              )
                              : Text(
                                'Sign in with Google',
                                style: TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: 17,
                                  color: thm.highcolor,
                                ),
                              ),
                    ),
                  ),
                ],
              ),
            ),
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: thm.highcolor),
      ),
      home: const MyHomePage(title: 'CGPA CALCULATOR'),
    );
  }
}
