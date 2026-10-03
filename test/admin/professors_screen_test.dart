// U9: DeptProfessors / ProfessorAdd over a fake Firestore (B3 store).
import 'package:cgpa_calculator/admin/professors.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/core/professors/professor_store.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/search_box.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;
  late ProfessorStore store;
  var n = 0;
  late String dept; // a fresh department per test: Loaded keeps a session cache

  setUp(() async {
    db = FakeFirebaseFirestore();
    final r = RoleStore(db, me: 'p@goa.bits-pilani.ac.in', myName: 'Pres');
    roleStore = r;
    store = ProfessorStore(db, roles: r);
    dept = 'D${n++}';
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(390, 1600);
    view.devicePixelRatio = 1;
  });

  tearDown(() {
    roleStore = null;
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
    view.resetViewInsets();
  });

  Future<void> show(WidgetTester t, Widget page) async {
    await t.pumpWidget(
      MaterialApp(theme: AppPalette.light.materialTheme, home: page),
    );
    await t.pumpAndSettle();
  }

  Future<void> list(WidgetTester t) =>
      show(t, DeptProfessors(campus: 'goa', dept: dept));

  Finder button(String label) => find.widgetWithText(PrimaryButton, label);
  bool enabled(WidgetTester t, String label) =>
      t.widget<PrimaryButton>(button(label)).onPressed != null;

  testWidgets('Add is enabled with an empty search and opens ProfessorAdd', (
    t,
  ) async {
    await list(t);
    expect(enabled(t, 'Add a professor'), isTrue);
    await t.tap(button('Add a professor'));
    await t.pumpAndSettle();
    expect(find.text('Add a professor'), findsWidgets);
    expect(find.byType(AppTextField), findsOneWidget);
    expect(enabled(t, 'Add'), isFalse); // no name yet
  });

  testWidgets('a near-duplicate warns; Add anyway adds; same name is blocked', (
    t,
  ) async {
    await t.runAsync(() => store.add('Ramesh Menon', 'goa', dept));
    await show(t, ProfessorAdd(campus: 'goa', dept: dept));
    await t.enterText(find.byType(TextField), 'Dr. Ramesh K Menon');
    await t.pump();
    expect(find.text('POSSIBLE DUPLICATES'), findsOneWidget);
    expect(find.text('Ramesh Menon'), findsOneWidget);
    expect(enabled(t, 'Add anyway'), isTrue);

    await t.enterText(find.byType(TextField), 'ramesh menon');
    await t.pump();
    expect(enabled(t, 'Add anyway'), isFalse);
    expect(find.textContaining('already listed'), findsOneWidget);

    await t.enterText(find.byType(TextField), 'Dr. Ramesh K Menon');
    await t.pump();
    await t.tap(button('Add anyway'));
    await t.pumpAndSettle();
    final names = (await db.collection('professors').get()).docs.map(
      (d) => d['name'],
    );
    expect(names, containsAll(['Ramesh Menon', 'Dr. Ramesh K Menon']));
  });

  testWidgets('a name with no look-alike shows Add, no warning', (t) async {
    await t.runAsync(() => store.add('Ramesh Menon', 'goa', dept));
    await show(t, ProfessorAdd(campus: 'goa', dept: dept));
    await t.enterText(find.byType(TextField), 'Anita Iyer');
    await t.pump();
    expect(find.text('POSSIBLE DUPLICATES'), findsNothing);
    expect(enabled(t, 'Add'), isTrue);
  });

  testWidgets('tapping the duplicate returns to the list showing it', (
    t,
  ) async {
    await t.runAsync(() => store.add('Ramesh Menon', 'goa', dept));
    await t.runAsync(() => store.add('Anita Iyer', 'goa', dept));
    await list(t);
    await t.tap(button('Add a professor'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'Dr. Ramesh K Menon');
    await t.pump();
    await t.tap(find.text('Tap to open instead'));
    await t.pumpAndSettle();
    expect(
      t
          .widget<TextField>(
            find.descendant(
              of: find.byType(SearchBox),
              matching: find.byType(TextField),
            ),
          )
          .controller!
          .text,
      'Ramesh Menon',
    );
    expect(find.text('Anita Iyer'), findsNothing);
  });

  testWidgets('Delete asks first; Keep changes nothing, Delete removes', (
    t,
  ) async {
    await t.runAsync(() => store.add('Ramesh Menon', 'goa', dept));
    await t.runAsync(() => store.add('Anita Iyer', 'goa', dept));
    await list(t);

    await t.tap(find.byTooltip('Delete Ramesh Menon'));
    await t.pumpAndSettle();
    expect(find.textContaining('Reviews stay under the name'), findsOneWidget);
    await t.tap(find.text('Keep'));
    await t.pumpAndSettle();
    expect(find.text('REMOVED'), findsNothing);

    await t.tap(find.byTooltip('Delete Ramesh Menon'));
    await t.pumpAndSettle();
    await t.tap(find.text('Delete').last);
    await t.pumpAndSettle();
    final doc = (await db.collection('professors').get()).docs.firstWhere(
      (d) => d['name'] == 'Ramesh Menon',
    );
    expect(doc['removed'], isTrue);
    // Removed group exists, comes after the live rows, keeps the name.
    expect(find.text('REMOVED'), findsOneWidget);
    expect(find.text('Removed · reviews stay under the name'), findsOneWidget);
    final live = t.getTopLeft(find.text('Anita Iyer')).dy;
    final gone = t.getTopLeft(find.text('Ramesh Menon')).dy;
    expect(gone, greaterThan(live));
    expect(find.byTooltip('Delete Ramesh Menon'), findsNothing);
  });

  testWidgets('a removed professor is not counted in the search hint', (
    t,
  ) async {
    final a = await t.runAsync(() => store.add('Ramesh Menon', 'goa', dept));
    await t.runAsync(() => store.add('Anita Iyer', 'goa', dept));
    await t.runAsync(() => store.remove(a!));
    await list(t);
    expect(find.text('Search 1 professors'), findsOneWidget);
  });

  testWidgets('ProfessorAdd keeps its field above the keyboard (UT-3)', (
    t,
  ) async {
    t.view.viewInsets = const FakeViewPadding(bottom: 300);
    await show(t, ProfessorAdd(campus: 'goa', dept: dept));
    final field = t.getRect(find.byType(TextField));
    expect(field.bottom, lessThanOrEqualTo(1600 - 300));
    expect(field.top, greaterThanOrEqualTo(0));
  });

  testWidgets('a prefetched list opens without a spinner (TM-16)', (t) async {
    await t.runAsync(() => store.add('Ramesh Menon', 'goa', dept));
    await t.runAsync(() => DeptProfessors.prefetch('goa', dept));
    await t.pumpWidget(
      MaterialApp(
        theme: AppPalette.light.materialTheme,
        home: DeptProfessors(campus: 'goa', dept: dept),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Ramesh Menon'), findsOneWidget);
  });
}
