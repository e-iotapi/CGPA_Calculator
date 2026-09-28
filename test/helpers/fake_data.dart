// Fake data for every screen: one Goa campus with an owner, an admin, two
// presidents, two CRs and a student, their grants and contacts, professors,
// a published offering, reviews (reported and hidden), resources (rolled up
// and reported), volunteer offers, a publish draft, audit entries, and a
// student's grades, marks and Offshoot. Screens render from it as they would
// for a real account, so a test sees them full, not empty (UI.md §14).
//
// Everything is written through the app's own stores where one exists, so
// the shapes match what the screens read. No real people: every address is
// made up.
import 'dart:io';

import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/core/catalog/publish.dart';
import 'package:cgpa_calculator/core/grading/grade_scale.dart';
import 'package:cgpa_calculator/core/grading/offshoot.dart';
import 'package:cgpa_calculator/core/models/marks.dart';
import 'package:cgpa_calculator/core/models/offering.dart';
import 'package:cgpa_calculator/core/models/programmes.dart';
import 'package:cgpa_calculator/core/professors/professor.dart';
import 'package:cgpa_calculator/core/resources/resource.dart';
import 'package:cgpa_calculator/core/resources/resource_store.dart';
import 'package:cgpa_calculator/core/reviews/review_store.dart';
import 'package:cgpa_calculator/core/roles/maintain_store.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/core/storage/cache_boxes.dart';
import 'package:cgpa_calculator/core/storage/marks.dart';
import 'package:cgpa_calculator/core/storage/offerings.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/marks/official.dart';
import 'package:cgpa_calculator/script.dart' as app;
import 'package:cgpa_calculator/sync.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import '../../agent_toolchains/ui_check/ui_checks.dart';

// ---- People (made up) -------------------------------------------------------

const ownerEmail = 'f20190001@goa.bits-pilani.ac.in';
const adminEmail = 'f20200011@hyderabad.bits-pilani.ac.in';
const presEmail = 'f20230802@goa.bits-pilani.ac.in';
const pres2Email = 'f20220003@goa.bits-pilani.ac.in';
const crEmail = 'f20230456@goa.bits-pilani.ac.in';
const cr2Email = 'f20240009@goa.bits-pilani.ac.in';
const studentEmail = 'f20230123@goa.bits-pilani.ac.in';

final _far = DateTime.now().add(const Duration(days: 100));
final _soon = DateTime.now().add(const Duration(days: 4));

Grant _grant(
  GrantRole role,
  String email,
  String name,
  String scope, {
  String campus = 'goa',
  String? programme,
  DateTime? until,
}) => Grant(
  role: role,
  email: email,
  name: name,
  campus: campus,
  scope: scope,
  programme: programme,
  active: true,
  expiresAt: until ?? _far,
  grantedByEmail: ownerEmail,
  grantedByName: 'Owner One',
  grantedAt: DateTime.now().subtract(const Duration(days: 20)),
);

final presGrant = _grant(
  GrantRole.dept,
  presEmail,
  'Meera Iyer',
  'ELEC',
  programme: 'A3',
);
final pres2Grant = _grant(
  GrantRole.dept,
  pres2Email,
  'Rohan Deshpande',
  'CS',
  programme: 'A7',
  until: _soon,
);
final crGrant = _grant(GrantRole.course, crEmail, 'Arjun Rao', 'CS F372');
final cr2Grant = _grant(GrantRole.course, cr2Email, 'Ishita Menon', 'EEE F211');
final adminGrant = _grant(
  GrantRole.admin,
  adminEmail,
  'Kavya Nair',
  'all',
  campus: 'hyderabad',
);

/// Who a screen is rendered for.
enum As {
  owner(ownerEmail, 'Owner One'),
  admin(adminEmail, 'Kavya Nair'),
  president(presEmail, 'Meera Iyer'),
  president2(pres2Email, 'Rohan Deshpande'),
  cr(crEmail, 'Arjun Rao'),
  student(studentEmail, 'Priya Sharma');

  const As(this.email, this.name);
  final String email, name;

  MyRoles get roles => switch (this) {
    As.owner => MyRoles(email: email, owner: true),
    As.admin => MyRoles(email: email, grants: [adminGrant]),
    As.president => MyRoles(email: email, grants: [presGrant]),
    As.president2 => MyRoles(email: email, grants: [pres2Grant]),
    As.cr => MyRoles(email: email, grants: [crGrant]),
    As.student => MyRoles(email: email),
  };
}

/// The course a student is taking this term, with a published scheme.
const takingId = 'CS F372';
const takingTitle = 'Operating Systems';
final term = currentTerm(DateTime.now());

// ---- Firestore --------------------------------------------------------------

/// Fills [db] with everything the shared screens read.
Future<void> seedFirestore(FakeFirebaseFirestore db) async {
  Future<void> grant(Grant g) => db.collection('grants').doc(g.id).set({
    'role': g.role.key,
    'email': g.email,
    'name': g.name,
    'campus': g.campus,
    'scope': g.scope,
    if (g.programme != null) 'programme': g.programme,
    'active': true,
    'expiresAt': Timestamp.fromDate(g.expiresAt),
    'grantedBy': {'email': ownerEmail, 'name': 'Owner One'},
    'grantedAt': Timestamp.fromDate(g.grantedAt!),
  });
  for (final g in [presGrant, pres2Grant, crGrant, cr2Grant, adminGrant]) {
    await grant(g);
  }
  for (final (e, n) in [
    (ownerEmail, 'Owner One'),
    ('f20180002@pilani.bits-pilani.ac.in', 'Owner Two'),
  ]) {
    await db.collection('owners').doc(e).set({
      'email': e,
      'name': n,
      'active': true,
      'addedBy': {'email': ownerEmail, 'name': 'Owner One'},
    });
  }
  // A removed owner, for the INACTIVE rows.
  await db
      .collection('owners')
      .doc('f20150003@hyderabad.bits-pilani.ac.in')
      .set({
        'email': 'f20150003@hyderabad.bits-pilani.ac.in',
        'name': 'Owner Three',
        'active': false,
        'addedBy': {'email': ownerEmail, 'name': 'Owner One'},
      });
  for (final a in As.values) {
    await db.collection('people').doc(a.email).set({
      'name': a.name,
      'campus': a == As.admin ? 'hyderabad' : 'goa',
    });
  }
  // Staff phones, and what students see on Representatives.
  for (final (e, n, phone) in [
    (ownerEmail, 'Owner One', '+91 90000 00001'),
    (adminEmail, 'Kavya Nair', '+91 90000 00102'),
    (presEmail, 'Meera Iyer', '+91 90000 00203'),
    (crEmail, 'Arjun Rao', '+91 90000 00304'),
  ]) {
    await db.collection('staffContacts').doc(e).set({
      'name': n,
      'phone': phone,
      'email': e,
    });
  }
  Future<void> listed(String e, String n, String role, String scope) =>
      db.collection('directory').doc(e).set({
        'name': n,
        'campus': 'goa',
        'roles': [
          {'role': role, 'scope': scope, 'until': Timestamp.fromDate(_far)},
        ],
        'email': e,
        'whatsapp': '9876543210',
      });
  await listed(presEmail, 'Meera Iyer', 'dept', 'ELEC');
  await listed(pres2Email, 'Rohan Deshpande', 'dept', 'CS');
  await listed(crEmail, 'Arjun Rao', 'course', takingId);

  await db.collection('config').doc('public').set({
    'contactName': 'Owner',
    'contactMethod': 'whatsapp',
    'contactTarget': '9000000001',
    'contactEnabled': true,
    'updatedBy': {'email': adminEmail, 'name': 'Kavya Nair'},
    'updatedAt': Timestamp.fromDate(
      _midnight().subtract(const Duration(days: 2)),
    ),
    'auditId': 'contact',
  });
  await db.collection('audit').doc('contact').set({
    'actor': {'email': adminEmail, 'name': 'Kavya Nair', 'role': 'admin'},
    'summary': 'Set the public contact to Owner (whatsapp)',
    'path': 'config/public',
    'campus': 'all',
    'at': Timestamp.fromDate(_midnight().subtract(const Duration(days: 2))),
  });

  // Professors: a duplicate pair to merge, and two more.
  for (final (id, name, dept) in [
    ('p1', 'Ramesh Menon', 'CS'),
    ('p2', 'Dr. R. Menon', 'CS'),
    ('p3', 'S. Bhat', 'CS'),
    ('p4', 'A. Iyer', 'ELEC'),
  ]) {
    await db.collection('professors').doc(id).set({
      'name': name,
      'campus': 'goa',
      'department': dept,
      'aliases': <String>[],
      'mergedIds': <String>[],
      'active': true,
      'nameTokens': nameTokens(name).toList(),
    });
  }

  final roles = RoleStore(db, me: ownerEmail, myName: 'Owner One');

  // The published scheme for the course the student takes, and an ELEC one.
  final maintain = MaintainStore(roles);
  await maintain.save(takingOffering(), 'Scheme for $takingId');
  await maintain.save(
    Offering(
      courseId: 'EEE F211',
      campus: 'goa',
      term: term,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      professors: const ['p4'],
      components: [
        OfferedComponent(
          id: 'mid',
          name: 'Midsem',
          weight: 35,
          parts: [OfferedPart(name: 'Midsem', outOf: 35, average: 21)],
        ),
        OfferedComponent(
          id: 'compre',
          name: 'Compre',
          weight: 40,
          parts: [OfferedPart(name: 'Compre', outOf: 40)],
        ),
      ],
    ),
    'Scheme for EEE F211',
  );

  // Reviews: several authors, one reported twice, one hidden.
  final texts = [
    'Grading was strict but fair, and the handouts matter more than the '
        'slides. Do the lab sheets before the quiz.',
    'Heavy, but you come out knowing how an OS schedules.',
    'Reported as naming an instructor rather than describing the course.',
    'Good course; the labs are the best part.',
  ];
  for (final (i, course)
      in [
        takingId,
        takingId,
        takingId,
        'EEE F211',
        'EEE F211',
        'EEE F212',
      ].indexed) {
    await ReviewStore(db, uid: 'u$i', roles: roles).save(
      courseId: course,
      campus: 'goa',
      term: '2025-26-2',
      professorId: course == takingId ? 'p1' : 'p4',
      stars: [4, 5, 2, 4, 3, 5][i],
      recommend: i != 2,
      text: texts[i % texts.length],
    );
  }
  final entries = await db.collectionGroup('entries').get();
  for (final (i, d) in entries.docs.indexed) {
    if (i == 2) await d.reference.update({'reports': 2});
    if (i == 4) await d.reference.update({'reports': 1});
    if (i == 5) {
      await d.reference.update({
        'hidden': true,
        'hiddenReason': 'Names a person',
      });
    }
  }

  // Resources: department links, a course link that rolls up, a reported one.
  final res = ResourceStore(roles, uid: 'u-owner');
  final ids = <String>[];
  for (final r in [
    Resource(
      id: '',
      title: 'ELEC past papers — all years',
      url: 'https://drive.google.com/drive/folders/elec-papers',
      campus: 'goa',
      department: 'ELEC',
    ),
    Resource(
      id: '',
      title: 'Signals lecture videos',
      url: 'https://www.youtube.com/playlist?list=signals',
      campus: 'goa',
      department: 'ELEC',
    ),
    Resource(
      id: '',
      title: 'EEE F211 notes and solved tutorials',
      url: 'https://drive.google.com/drive/folders/eee-f211',
      campus: 'goa',
      department: 'ELEC',
      scope: 'course',
      courseIds: const ['EEE F211'],
    ),
    Resource(
      id: '',
      title: 'OS lab sheets',
      url: 'https://drive.google.com/drive/folders/os-labs',
      campus: 'goa',
      department: 'CS',
      scope: 'course',
      courseIds: const [takingId],
    ),
  ]) {
    ids.add(await res.add(r));
  }
  final reported = (await res.department('goa', 'ELEC')).first;
  await ResourceStore(
    roles,
    uid: 'u-reporter',
  ).report(reported, ReportReason.broken, note: 'The folder is empty');

  // Two students offer to be CR for a course with none.
  for (final (e, n) in [
    ('f20240101@goa.bits-pilani.ac.in', 'Nikhil Bhat'),
    ('f20240102@goa.bits-pilani.ac.in', 'Sana Kapoor'),
  ]) {
    await db.collection('volunteers').doc('goa_EEE F212_$e').set({
      'name': n,
      'email': e,
      'campus': 'goa',
      'courseId': 'EEE F212',
      'dept': 'ELEC',
      'term': term,
      'open': true,
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // A publish draft that moves CGPAs, and a cosmetic one; both differ from
  // assets/catalog.json, so Publish shows a real diff.
  final catalog = CatalogStore(roles);
  await catalog.saveDraft(
    const CourseEdit(id: 'CS F211', credits: 3),
    campus: 'goa',
  );
  await catalog.saveDraft(
    const CourseEdit(id: 'CS F213', title: 'Object-Oriented Programming'),
    campus: 'goa',
  );

  // Audit entries of every kind, oldest last.
  for (final (i, (who, name, role, what, course))
      in [
        (
          crEmail,
          'Arjun Rao',
          'cr',
          'Changed the Midsem weight in CS F372',
          takingId,
        ),
        (
          presEmail,
          'Meera Iyer',
          'president',
          'Appointed Ishita Menon CR for EEE F211',
          'EEE F211',
        ),
        (
          presEmail,
          'Meera Iyer',
          'president',
          'Added a link to EEE F211: notes',
          'EEE F211',
        ),
        (
          ownerEmail,
          'Owner One',
          'owner',
          'Published 14 changes, including EEE F211',
          null,
        ),
      ].indexed) {
    await db.collection('audit').add({
      'actor': {'email': who, 'name': name, 'role': role},
      'action': what,
      'summary': what,
      'campus': 'goa',
      if (course != null) 'course': course,
      'at': Timestamp.fromDate(
        // From midnight, so shown times never move with the clock.
        _midnight().subtract(Duration(hours: [1, 20, 72, 120][i])),
      ),
    });
  }
}

String _iso(DateTime d) => d.toIso8601String().substring(0, 10);

/// CS F372's published scheme this term: best-of parts, averages, a part
/// with no average yet, and a professor.
Offering takingOffering() => Offering(
  courseId: takingId,
  campus: 'goa',
  term: term,
  updatedAt: DateTime.now().millisecondsSinceEpoch,
  professors: const ['p1'],
  courseAverage: 63.5,
  components: [
    OfferedComponent(
      id: 'kernel',
      name: 'Kernel Assignments',
      weight: 20,
      countBest: 2,
      average: 12.4,
      parts: [
        OfferedPart(name: 'CPU Scheduling', outOf: 10, average: 7.2),
        OfferedPart(name: 'Memory Management', outOf: 10, average: 5.2),
        OfferedPart(name: 'Concurrency', outOf: 10),
      ],
    ),
    OfferedComponent(
      id: 'quiz',
      name: 'In-Lab Quiz',
      weight: 4,
      countBest: 4,
      parts: [
        for (var i = 1; i <= 6; i++)
          OfferedPart(
            name: 'Quiz $i',
            outOf: 1,
            date: _iso(DateTime.now().subtract(Duration(days: 60 - 7 * i))),
          ),
      ],
    ),
    OfferedComponent(
      id: 'mid',
      name: 'Mid Semester',
      weight: 25,
      parts: [
        OfferedPart(
          name: 'Mid Semester',
          outOf: 25,
          date: _iso(DateTime.now().add(const Duration(days: 12))),
        ),
      ],
    ),
    OfferedComponent(
      id: 'compre',
      name: 'Compre',
      weight: 30,
      parts: [
        OfferedPart(
          name: 'Compre',
          outOf: 30,
          date: _iso(DateTime.now().add(const Duration(days: 70))),
        ),
      ],
    ),
  ],
);

// ---- The student's device (Hive) -------------------------------------------

/// The published offerings, as the app reads them from Firestore.
OfferingSource publishedOfferings() => _Published();

class _Published implements OfferingSource {
  @override
  Future<Offering?> get(String courseId, String campus, String term) async =>
      courseId == takingId ? takingOffering() : null;
}

Course _course(
  String sem,
  String id,
  String title,
  double cr,
  int g1, {
  int? g2,
  String discipline = 'A7',
  String elective = 'CDC',
}) => Course(
  title: title,
  id: id,
  credits: cr,
  grade1: g1,
  grade2: g2 ?? g1,
  discipline: discipline,
  sem: sem,
  elective: elective,
);

/// Eight semesters of a B3 A7 dual degree, batch 23, at Goa: graded, NC,
/// ongoing and this term's courses, with Expected differing from Actual.
List<Course> studentCourses() => [
  _course('1 - 1', 'BITS F110', 'Engineering Graphics', 2, 10),
  _course('1 - 1', 'MATH F111', 'Mathematics I', 3, 9),
  _course('1 - 1', 'CHEM F111', 'General Chemistry', 3, 8),
  _course('1 - 2', 'MATH F112', 'Mathematics II', 3, 7),
  _course('1 - 2', 'BIO F111', 'General Biology', 3, 10),
  _course(
    '2 - 1',
    'ECON F211',
    'Principles of Economics',
    3,
    8,
    discipline: 'B3',
  ),
  _course('2 - 1', 'CS F211', 'Data Structures and Algorithms', 4, 9),
  _course('2 - 2', 'CS F212', 'Database Systems', 4, 8),
  _course(
    '2 - 2',
    'ECON F212',
    'Fundamentals of Finance and Accounts',
    3,
    9,
    discipline: 'B3',
  ),
  _course(
    '3 - 1',
    'CS F301',
    'Principles of Programming Languages',
    2,
    7,
    g2: 8,
  ),
  _course(
    '3 - 1',
    'HSS F222',
    'Linguistics',
    3,
    10,
    elective: 'Humanity Electives',
  ),
  _course('3 - 2', 'CS F351', 'Theory of Computation', 3, 8, g2: 9),
  _course(
    '3 - 2',
    'ECON F355',
    'Business Analysis and Valuation',
    3,
    GradeCode.nc,
    discipline: 'B3',
    elective: 'Disciplinary Elective1',
  ),
  _course('4 - 1', takingId, takingTitle, 4, GradeCode.clr, g2: 9),
  _course('4 - 1', 'CS F342', 'Computer Architecture', 4, GradeCode.clr, g2: 8),
  _course('4 - 1', 'BITS F112', 'Technical Report Writing', 2, GradeCode.clr),
];

/// The student's own marks on [takingId]: official parts with their marks,
/// one component made their own (detached), class average entered.
Future<void> seedMarks() async {
  // Through the offering cache, as the app does, so Marks finds the
  // professor and the published averages too.
  await refreshOffering(_Published(), takingId, 'goa', term);
  final mine = evaluativesFor(takingId);
  for (final (key, e) in mine) {
    final filled = switch (e.name) {
      'Kernel Assignments' => [8.0, 6.0, 3.0],
      'In-Lab Quiz' => [1.0, 1.0, 0.0, 1.0],
      _ => const <double>[],
    };
    for (final (i, m) in filled.indexed) {
      if (i < e.parts.length) e.parts[i].marks = m;
    }
    await saveEvaluative(e, key: key);
  }
  await saveEvaluative(
    Evaluative(
      courseId: takingId,
      name: 'Assignment 0',
      weight: 6,
      parts: [
        EvalPart(name: 'Part A', marks: 3, outOf: 3, average: 2.5),
        EvalPart(name: 'Part B', marks: 3, outOf: 3, average: 2.6),
      ],
    ),
  );
  final cfg = configFor(takingId) ?? CourseConfig(courseId: takingId);
  cfg.classAverage = 9.8;
  await saveConfig(cfg);
}

/// The fake Firestore every render reads, filled once by [seedAll].
late FakeFirebaseFirestore sharedDb;

/// Fills the device and one shared fake Firestore. Call once from
/// `setUpAll`, which runs in real time: seeding inside a widget test's fake
/// clock can stall after a screen has listened to an earlier database.
Future<void> seedAll() async {
  await seedDevice();
  sharedDb = FakeFirebaseFirestore();
  await seedFirestore(sharedDb);
}

/// Opens every Hive box the app uses and fills the student's data.
Future<Directory> seedDevice() async {
  final dir = await Directory.systemTemp.createTemp('pointer_fake');
  Hive.init(dir.path);
  if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(CourseAdapter());
  registerMarksAdapters();
  await Sync.openBoxes();
  if (!Hive.isBoxOpen(marksBoxName)) await Hive.openBox(marksBoxName);
  for (final b in cacheBoxes) {
    if (!Hive.isBoxOpen(b)) await Hive.openBox(b);
  }
  app.campus = Campus.goa;
  app.batch = 23;
  app.selecteddiscipline = 'B3A7';
  final box = Hive.box<Course>('coursesBox');
  await box.clear();
  await box.addAll(studentCourses());
  final off = Hive.box<Course>('offshootBox');
  await off.clear();
  await off.addAll([
    for (final (i, c) in offshootCourses.take(6).indexed)
      Course(
        title: c.title,
        id: c.id,
        credits: 3,
        grade1: const [9, 10, 8, 7, 10, 10][i],
        grade2: GradeCode.clr,
        discipline: 'B3',
        sem: 'Offshoot',
        elective: 'Offshoot',
      ),
  ]);
  await seedMarks();
  return dir;
}

// ---- Rendering ---------------------------------------------------------------

final shotsOut = Platform.environment['SHOTS_DIR'];

/// One render: a label, a size and a text scale.
typedef Frame = (String label, Size size, double scale);

/// 390 at the board's height, 320 × 640, and 320 at 150% text (light only);
/// 200% is not checked (UI.md §13.2.10).
List<Frame> framesFor(double tall) => [
  ('390', Size(390, tall), 1),
  ('320', const Size(320, 640), 1),
  ('320x1.5', const Size(320, 640), 1.5),
];

/// Renders [screen] as [who] over freshly seeded data, in light and dark at
/// each frame, and returns every error it raised. With SHOTS_DIR set it
/// writes `<name>_<light|dark>_<frame>.png` and a .json of its [uiIssues]. [open] runs after the first
/// frames, for a sheet or dialog opened from a launcher.
Future<List<String>> renderScreen(
  WidgetTester t,
  String name,
  Widget Function() screen, {
  As who = As.student,
  double tall = 844,
  Future<void> Function(WidgetTester t)? open,
}) async {
  final errors = <String>[];
  final old = FlutterError.onError;
  FlutterError.onError =
      (d) => errors.add(d.exceptionAsString().split('\n').first);
  final db = sharedDb;
  try {
    for (final palette in [AppPalette.light, AppPalette.dark]) {
      for (final (label, size, scale) in framesFor(tall)) {
        if (scale != 1 && palette.isDark) continue;
        final before = errors.length;
        roleStore = RoleStore(db, me: who.email, myName: who.name);
        myRoles.value = who.roles;
        myUid = 'u-${who.name.split(' ').first.toLowerCase()}';
        t.view.physicalSize = size * 2;
        t.view.devicePixelRatio = 2;
        await t.pumpWidget(
          RepaintBoundary(
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: palette.materialTheme,
              builder:
                  (c, child) => MediaQuery(
                    data: MediaQuery.of(
                      c,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
              home: screen(),
            ),
          ),
        );
        await settle(t);
        if (open != null) {
          await open(t);
          await settle(t);
        }
        final ex = t.takeException();
        if (ex != null) errors.add('$label: ${'$ex'.split('\n').first}');
        final out = shotsOut;
        if (out != null) {
          final mode = palette.isDark ? 'dark' : 'light';
          await recordRender(
            t,
            out,
            '${name}_${mode}_$label',
            errors.sublist(before),
          );
        }
        await t.pumpWidget(const SizedBox());
      }
    }
  } finally {
    FlutterError.onError = old;
    t.view.reset();
    roleStore = null;
    myRoles.value = MyRoles.none;
    myUid = null;
  }
  return errors.toSet().toList();
}

/// Lets fake Firestore futures finish and frames run, without
/// `pumpAndSettle`: the pulsing Reported tab never settles.
Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump(const Duration(milliseconds: 100));
  }
}

/// A screen that opens a sheet or dialog from its one button, for
/// [renderScreen]'s `open`.
Widget launcher(Future<void> Function(BuildContext c) open) => Scaffold(
  body: Center(
    child: Builder(
      builder:
          (c) => TextButton(
            key: const ValueKey('launch'),
            onPressed: () => open(c),
            child: const Text('open'),
          ),
    ),
  ),
);

/// Taps [launcher]'s button.
Future<void> tapLauncher(WidgetTester t) =>
    t.tap(find.byKey(const ValueKey('launch')));

/// Checks a render against the known issues: a screen listed in [known]
/// must still fail (so the list stays true), and every other must be clean.
void expectRender(String name, List<String> errors, Map<String, String> known) {
  final why = known[name];
  if (why == null) {
    expect(errors, isEmpty, reason: '$name rendered with errors');
  } else {
    expect(
      errors,
      isNotEmpty,
      reason:
          '$name is listed as broken ($why) but renders clean now: '
          'remove it from the known list and log the fix in UI.md §13',
    );
  }
}

DateTime _midnight() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}
