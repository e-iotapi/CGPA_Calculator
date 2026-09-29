// The UI-only demo: the real app over the test fakes, with no backend.
// Every sign-in is the owner (Owner One, a made-up address); the data is
// test/helpers/fake_seed.dart, reseeded on each load; Firebase is a local
// stand-in, so nothing leaves the browser. Build with
// `flutter build web -t demo/main.dart` (demo/build.sh).
// ignore_for_file: depend_on_referenced_packages, invalid_use_of_visible_for_testing_member
import 'package:cgpa_calculator/app/router.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/core/catalog/catalog_store.dart';
import 'package:cgpa_calculator/core/resources/resource_store.dart';
import 'package:cgpa_calculator/core/reviews/review_store.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/core/storage/offerings.dart';
import 'package:cgpa_calculator/features/auth/sign_in_view.dart';
import 'package:cgpa_calculator/features/marks/official.dart';
import 'package:cgpa_calculator/features/roles/role_switch_page.dart';
import 'package:cgpa_calculator/main.dart' show MyApp;
import 'package:cgpa_calculator/script.dart' as app;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../test/helpers/fake_seed.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FirebasePlatform.instance = _Core();
  FirebaseAuthPlatform.instance = _auth;
  await Firebase.initializeApp();
  await Hive.initFlutter('pointer_demo');
  await fillDevice();
  await app.setdis();
  sharedDb = FakeFirebaseFirestore();
  await seedFirestore(sharedDb);
  runApp(const _SignIn());
}

/// The real sign-in view with the same staggered intro; the button makes
/// you the owner.
class _SignIn extends StatefulWidget {
  const _SignIn();

  @override
  State<_SignIn> createState() => _SignInState();
}

class _SignInState extends State<_SignIn> with SingleTickerProviderStateMixin {
  bool _busy = false;
  late final _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
  )..forward();

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  Widget _entrance(int order, Widget child) {
    final start = (order * 0.1).clamp(0.0, 0.7);
    final curve = CurvedAnimation(
      parent: _intro,
      curve: Interval(
        start,
        (start + 0.45).clamp(0.0, 1.0),
        curve: Curves.easeOutCubic,
      ),
    );
    if (MediaQuery.disableAnimationsOf(context)) return child;
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
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await _startAsOwner();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.byName(app.selected_theme);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: p.materialTheme,
      home: Builder(
        builder:
            (c) =>
                SignInView(busy: _busy, onSignIn: _signIn, entrance: _entrance),
      ),
    );
  }
}

/// startApp's steps with the fakes in place of Firestore and Sync.
Future<void> _startAsOwner() async {
  _auth.user = _User(_auth);
  await loadCatalog();
  await openOfferings();
  offeringSource = publishedOfferings();
  await app.basicStartup();
  await openDeviceBox();
  await openResources();
  await openReviews();
  myUid = 'u-owner';
  stripNavigate = appRouter.go;
  roleStore = RoleStore(sharedDb, me: As.owner.email, myName: As.owner.name);
  myRoles.value = As.owner.roles;
  runApp(const MyApp());
}

// ---- A local Firebase: one app, one signed-in owner, no network ----------

final _auth = _Auth();

class _Core extends FirebasePlatform {
  final _app = _App();

  @override
  List<FirebaseAppPlatform> get apps => [_app];

  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) => _app;

  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async => _app;
}

class _App extends FirebaseAppPlatform {
  _App()
    : super(
        defaultFirebaseAppName,
        const FirebaseOptions(
          apiKey: 'demo',
          appId: 'demo',
          messagingSenderId: 'demo',
          projectId: 'demo',
        ),
      );
}

class _Auth extends FirebaseAuthPlatform {
  UserPlatform? user;

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) => this;

  @override
  UserPlatform? get currentUser => user;

  @override
  Stream<UserPlatform?> authStateChanges() => Stream.value(user);

  @override
  Stream<UserPlatform?> idTokenChanges() => Stream.value(user);

  @override
  Stream<UserPlatform?> userChanges() => Stream.value(user);

  @override
  Future<void> signOut() async => user = null;
}

class _Factor extends MultiFactorPlatform {
  _Factor(super.auth);
}

class _User extends UserPlatform {
  _User(FirebaseAuthPlatform auth)
    : super(
        auth,
        _Factor(auth),
        InternalUserDetails(
          userInfo: InternalUserInfo(
            uid: 'u-owner',
            email: As.owner.email,
            displayName: As.owner.name,
            isAnonymous: false,
            isEmailVerified: true,
          ),
          providerData: const [],
        ),
      );
}
