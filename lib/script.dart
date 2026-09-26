import 'dart:convert';
import 'dart:ui' as ui;
import 'package:cgpa_calculator/app/theme/circle_reveal.dart';
import 'package:cgpa_calculator/core/platform/browser.dart';
import 'package:flutter/foundation.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/core/grading/cgpa.dart';
import 'package:cgpa_calculator/core/grading/grade_scale.dart';
import 'package:cgpa_calculator/core/models/semesters.dart';
import 'package:cgpa_calculator/core/storage/courses.dart';
import 'package:cgpa_calculator/core/storage/seed.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

export 'package:cgpa_calculator/core/grading/grade_scale.dart';

void saveImageWeb(Uint8List bytes, String filename) =>
    downloadBytes(bytes, filename, 'image/png');

String _csvCell(Object? v) {
  final s = v?.toString() ?? '';
  return RegExp(r'[",\n\r]').hasMatch(s)
      ? '"${s.replaceAll('"', '""')}"'
      : s;
}

/// Builds a CSV of every saved course, both grade profiles included.
String buildGradesCsv() {
  final courses = Hive.box<Course>('coursesBox').values.toList()
    ..sort((a, b) {
      final c = a.sem.compareTo(b.sem);
      return c != 0 ? c : a.id.compareTo(b.id);
    });

  final rows = <List<Object?>>[
    [
      'Course ID',
      'Title',
      'Credits',
      'Semester',
      'Discipline',
      'Type',
      '$profile1n Grade',
      '$profile1n Points',
      '$profile2n Grade',
      '$profile2n Points',
    ],
    for (final c in courses)
      [
        c.id,
        c.title,
        c.credits,
        c.sem,
        c.discipline,
        c.elective,
        gradecalc(c.grade1),
        c.grade1 < 0 ? '' : c.grade1,
        gradecalc(c.grade2),
        c.grade2 < 0 ? '' : c.grade2,
      ],
  ];

  return rows.map((r) => r.map(_csvCell).join(',')).join('\r\n');
}

/// Downloads the course list as a .csv file. Returns the filename used.
String exportGradesCsv() {
  final name =
      'CGPA_Grades_${DateTime.now().toIso8601String().split("T").first}.csv';
  // BOM so Excel opens UTF-8 correctly.
  final bytes = <int>[0xEF, 0xBB, 0xBF, ...utf8.encode(buildGradesCsv())];
  downloadBytes(bytes, name, 'text/csv;charset=utf-8');
  return name;
}

/// Reads the saved settings into the globals.
void _loadSettings(Box settingsBox) {
  selecteddiscipline = settingsBox.get(
    'selecteddiscipline',
    defaultValue: selecteddiscipline,
  );
  batch = settingsBox.get('batch', defaultValue: 24);
  // Saved names from the removed colour themes fall back to White or Black.
  selected_theme = AppPalette.resolveName(
    settingsBox.get('selected_theme', defaultValue: selected_theme),
  );
  degree_selected = settingsBox.get('degree_selected', defaultValue: false);
  currentsort = settingsBox.get('currentsort', defaultValue: currentsort);
  currentsem = settingsBox.get('currentsem', defaultValue: currentsem);
  profile1n = settingsBox.get('profile1n', defaultValue: profile1n);
  profile2n = settingsBox.get('profile2n', defaultValue: profile2n);
}

Future<void> basicStartup() async {
  var settingsBox = await Hive.openBox('settingsBox');
  await Hive.openBox<Course>('coursesBox');
  _loadSettings(settingsBox);
  await Hive.openBox<Course>('offshootBox');
}

/// Copies every Actual grade onto the Expected profile, across all semesters.
/// Writes back under each course's existing key, which may be an int (courses
/// added via box.add) or the course id — re-keying here would duplicate them.
Future<void> copyGrades() async {
  final coursesBox = await Hive.openBox<Course>('coursesBox');
  for (final k in coursesBox.keys.toList()) {
    final i = coursesBox.get(k);
    if (i == null) continue;
    await coursesBox.put(
      k,
      Course(
        title: i.title,
        sem: i.sem,
        id: i.id,
        grade1: i.grade1,
        grade2: i.grade1,
        discipline: i.discipline,
        credits: i.credits,
        elective: i.elective,
      ),
    );
  }
  await coursesBox.flush();
}

Future<void> initializeCourses() async {
  var settingsBox = await Hive.openBox('settingsBox');
  final coursesBox = await Hive.openBox<Course>('coursesBox');
  _loadSettings(settingsBox);
  final rows = chartRows(batch);
  if (erase == 1) {
    await coursesBox.clear();
    for (final c in seedCourses(selecteddiscipline, rows)) {
      await coursesBox.put(c.id, c);
    }
    setsort();
  } else if (erase == 0) {
    if (degree_selected && needsSeed(selecteddiscipline, coursesBox.values)) {
      for (final c in seedCourses(selecteddiscipline, rows)) {
        await coursesBox.put(c.id, c);
      }
      setsort();
    }
  } else if (erase == 2) {
    final plan = reseedSecondHalf(selecteddiscipline, coursesBox.toMap(), rows);
    await coursesBox.deleteAll(plan.drop);
    for (final c in plan.add) {
      await coursesBox.put(c.id, c);
    }
  }
  await placeDualPracticeSchool(coursesBox, selecteddiscipline);
}

Future<void> setdis() async {
  var settingsBox = await Hive.openBox('settingsBox');
  await settingsBox.put('batch', batch);
  await settingsBox.put('selecteddiscipline', selecteddiscipline);
  await settingsBox.put('degree_selected', true);
}

void sort(List<Course> sitems, String cs) {
  if (selectedprofile == 1) {
    if (cs == "Sort by Credits(Asc)") {
      sitems.sort((a, b) => a.credits.compareTo(b.credits));
    } else if (cs == "Sort by Credits(Des)") {
      sitems.sort((a, b) => b.credits.compareTo(a.credits));
    } else if (cs == "Sort by Grades(Des)") {
      sitems.sort((a, b) => b.grade1.compareTo(a.grade1));
    } else if (cs == "Sort by Grades(Asc)") {
      sitems.sort((a, b) => a.grade1.compareTo(b.grade1));
    }
  } else if (selectedprofile == 2) {
    if (cs == "Sort by Credits(Asc)") {
      sitems.sort((a, b) => a.credits.compareTo(b.credits));
    } else if (cs == "Sort by Credits(Des)") {
      sitems.sort((a, b) => b.credits.compareTo(a.credits));
    } else if (cs == "Sort by Grades(Des)") {
      sitems.sort((a, b) => b.grade2.compareTo(a.grade2));
    } else if (cs == "Sort by Grades(Asc)") {
      sitems.sort((a, b) => a.grade2.compareTo(b.grade2));
    }
  }
}

Future<void> setsort() async {
  var settingsBox = await Hive.openBox('settingsBox');
  await settingsBox.put('currentsort', currentsort);
}


Future<void> settheme() async {
  var settingsBox = await Hive.openBox('settingsBox');
  await settingsBox.put('selected_theme', selected_theme);
}

Future<void> setsem() async {
  var settingsBox = await Hive.openBox('settingsBox');
  await settingsBox.put('currentsem', currentsem);
}

Future<void> setprof() async {
  var settingsBox = await Hive.openBox('settingsBox');
  await settingsBox.put('profile1n', profile1n);
  await settingsBox.put('profile2n', profile2n);
}


Future<void> addOrUpdateCourse(Course course) async {
  try {
    var box = Hive.box<Course>('coursesBox');
    await box.put(course.id, course);
    await box.flush();
  } catch (e) {}
}

Future<void> clearSemesterGrades(String sem, int profile) async {
  try {
    var box = Hive.box<Course>('coursesBox');
    List<Course> courses = box.values.where((c) => c.sem == sem).toList();
    for (var course in courses) {
      Course updatedCourse = Course(
        title: course.title,
        sem: course.sem,
        id: course.id,
        grade1: (profile == 1) ? -2 : course.grade1,
        grade2: (profile == 2) ? -2 : course.grade2,
        discipline: course.discipline,
        credits: course.credits,
        elective: course.elective,
      );
      await box.put(updatedCourse.id, updatedCourse);
    }
    await box.flush();
  } catch (e) {}
}

void setnavcolor() {
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle.light.copyWith(
      systemNavigationBarColor: thm.backcolor,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
}



// GPA maths lives in core/grading/cgpa.dart. These keep the old names and the
// globals for screens that have not been rebuilt yet.

GpaTally _semTally(String sem, Profile p) => semesterTally(
  Hive.box<Course>('coursesBox').values,
  sem: sem,
  discipline: selecteddiscipline,
  profile: p,
);

GpaTally _cumTally(Profile p) => cumulativeTally(
  Hive.box<Course>('coursesBox').values,
  discipline: selecteddiscipline,
  profile: p,
);

/// SGPA of [s] for the selected profile, rounded; -3.0 if no profile.
double sgcalc(String s) {
  final p = Profile.fromId(selectedprofile);
  return p == null ? -3.0 : _semTally(s, p).rounded;
}

/// CGPA for the selected profile, rounded; -3.0 if no profile.
double cgcalc() {
  final p = Profile.fromId(selectedprofile);
  return p == null ? -3.0 : _cumTally(p).rounded;
}

/// Credits shown beside the SGPA/CGPA, per profile, into the scred/ccred
/// globals.
void creditTotals() {
  scred1 = _semTally(currentsem, Profile.actual).shownCredits;
  scred2 = _semTally(currentsem, Profile.expected).shownCredits;
  ccred1 = _cumTally(Profile.actual).shownCredits;
  ccred2 = _cumTally(Profile.expected).shownCredits;
}

var thm = AppPalette.byName(selected_theme);
double sgpa = 0.00;
double cgpa = 0.00;
int batch = 24;
String selecteddiscipline = "----"; //store

/// Halves of [selecteddiscipline] as the first-run discipline dialog edits
/// them.
String selectdual = selecteddiscipline.substring(0, 2);
String selecengg = selecteddiscipline.substring(2, 4);
int selectedprofile = 1;
String currentsem = "1 - 1"; // store
double scred1 = 0;
double scred2 = 0;
double ccred1 = 0;
double ccred2 = 0;
String profile1n = "Actual";
String profile2n = "Expected";

String currentsort = "Sort by Credits(Asc)"; //store
String selected_theme = "White";
bool degree_selected = false;
int erase = 0;
final List<String> grades = pickerGrades;
final List<String> sems = baseSemesters;
/// Switches light or dark under the circle reveal and saves it. [then]
/// runs with the change, while the old screen still covers it.
Future<void> switchTheme(bool dark, {VoidCallback? then}) async {
  final name = dark ? 'Black' : 'White';
  if (name == selected_theme) return;
  await ThemeReveal.run(() {
    selected_theme = name;
    thm = AppPalette.byName(selected_theme);
    setnavcolor();
    themeVersion.value++;
    then?.call();
  });
  await settheme();
}

/// Bumped when [thm] changes, so the app rebuilds with the new theme.
final themeVersion = ValueNotifier(0);

/// Codes in [degreelist] not offered at Goa or Hyderabad (A9 Biotechnology,
/// AB Manufacturing). Kept for anyone already on them, never offered anew.
const notOfferedHere = {'A9', 'AB'};

/// [degreelist] without [notOfferedHere], for pickers.
List<String> get offeredDegrees =>
    degreelist.where((d) => !notOfferedHere.contains(d)).toList();

final List<String> degreelist = [
  "B1",
  "B2",
  "B3",
  "B4",
  "B5",
  "B7",
  "A1",
  "A2",
  "A3",
  "A4",
  "A5",
  "A7",
  "A8",
  "A9",
  "AA",
  "AB",
  "AC",
  "AD",
  "AJ",
];

Future<String> saveDataAsImage(
    List<Map<String, dynamic>> data, {
      required String semester,
      required double thisSemCredits,
      required double totalCredits,
      required double gpa,
      required double cgpa,
      required bool isOffshoot,
    }) async
{
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  final double scale = 4.0;
  final double width = 700 * scale;
  final double headerHeight = 56 * scale;
  final double rowHeight = 40 * scale;
  final int numberOfRows = data.length;

  // Height reserved for summary info on top
  final double infoHeight = 150 * scale;
  final double height = infoHeight + headerHeight + numberOfRows * rowHeight;
  final double borderRadius = 16 * scale;
  final List<double> colWidths = [100 * scale, 400 * scale, 70 * scale];

  // Shadow for card
  final shadowPaint = Paint()
    ..color = Color(0x11000000)
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 * scale);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(14 * scale, 18 * scale, width - 28 * scale, height + 42 * scale),
      Radius.circular(borderRadius),
    ),
    shadowPaint,
  );

  // Card background
  final cardPaint = Paint()..color = Color(0xFFF4F7FA);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, width, height-2),
      Radius.circular(borderRadius),
    ),
    cardPaint,
  );

  // Draw top info background
  final infoBackgroundPaint = Paint()..color = Color(0xFFF3E8FE);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, width, infoHeight),
      Radius.circular(borderRadius),
    ),
    infoBackgroundPaint,
  );

  // Text painter for drawing text
  final textPainter = TextPainter(
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.left,
  );

  // Function to draw summary text lines with vertical spacing
  double yOffset = 20 * scale;
  double xOffset = 20 * scale;
  void drawInfoText(String text, double y, double x) {
    textPainter.text = TextSpan(
      text: text,
      style: TextStyle(
        fontSize: 26 * scale,
        color: Color(0xFF2D3E50),
        fontWeight: FontWeight.w600,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(x, y));
  }

  // Draw the additional details on top
  yOffset=width*0.45;
  if(isOffshoot){
    drawInfoText("Minor", xOffset, yOffset);
    yOffset=25*scale;
    xOffset += 42 * scale;
    drawInfoText("Offshoot: ${gpa.toStringAsFixed(2)}", xOffset,yOffset);
    yOffset=width*0.82-40*scale;
    yOffset=25*scale;
    xOffset += 42 * scale;
    drawInfoText("Credits: $thisSemCredits",xOffset, yOffset);
    yOffset=width*0.82-40*scale;
  }else{
    drawInfoText("Semester: $semester", xOffset, yOffset);
    yOffset=25*scale;
    xOffset += 42 * scale;
    drawInfoText("SGPA: ${gpa.toStringAsFixed(2)}", xOffset,yOffset);
    yOffset=width*0.82-40*scale;
    drawInfoText("CGPA: ${cgpa.toStringAsFixed(2)}", xOffset,yOffset);
    yOffset=25*scale;
    xOffset += 42 * scale;
    drawInfoText("Credits: $thisSemCredits",xOffset, yOffset);
    yOffset=width*0.82-40*scale;
    drawInfoText("Credits: $totalCredits", xOffset,yOffset);
  }



  // Draw header gradient bar below info section
  final headerGradient = Paint()
    ..shader = ui.Gradient.linear(
      Offset(3, infoHeight + 3), Offset(width - 8, infoHeight + 3),
      [Color(0xB3C51499), Color(0xB34B02B0)],
    );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(5, infoHeight + 8, width - 10, headerHeight - 16),
      Radius.circular(borderRadius),
    ),
    headerGradient,
  );

  // Draw header text
  double x = 0, y = infoHeight;
  final headers = ['Credits', 'Course', 'Grade'];
  for (int i = 0; i < headers.length; i++) {
    textPainter.text = TextSpan(
      text: headers[i],
      style: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 21 * scale,
        color: Color(0xFFFFFFFF),
        letterSpacing: 1.35 * scale,
      ),
    );
    textPainter.layout(minWidth: colWidths[i], maxWidth: colWidths[i]);
    textPainter.paint(canvas, Offset(x + 25 * scale, y + (headerHeight - textPainter.height) / 2));
    x += colWidths[i];
  }

  y += headerHeight;
  for (int rowIdx = 0; rowIdx < data.length; rowIdx++) {
    var row = data[rowIdx];
    x = 0;
    final bool even = rowIdx % 2 == 0;

    final rowPaint = Paint()..color = even ? Color(0xFFFFFFFF) : Color(
        0xFFE9DFEF);
    canvas.drawRect(Rect.fromLTWH(0, y, width, rowHeight), rowPaint);

    final borderPaint = Paint()
      ..color = Color(0xFFC7C6C6)
      ..strokeWidth = 2.0 * scale;
    canvas.drawLine(Offset(0, y), Offset(width, y), borderPaint);

    final cellTexts = [
      row['credits'].toString(),
      row['name'],
      (row['grade'] > -4 || row['grade'] == -6 || row['grade'] == -7)
          ? gradecalc(row['grade'])
          : "",// :  (row['grade'] == -2) ? "GD":"CLR",
    ];
    for (int i = 0; i < cellTexts.length; i++) {
      textPainter.text = TextSpan(
        text: cellTexts[i].toString(),
        style: TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: 19 * scale,
          color: Color(0xFF34495E),
        ),
      );
      textPainter.layout(minWidth: colWidths[i], maxWidth: colWidths[i]);
      textPainter.paint(canvas, Offset(x + 25 * scale, y + (rowHeight - textPainter.height) / 2));
      if (i < cellTexts.length - 1) {
        canvas.drawLine(
          Offset(x + colWidths[i], y + 7 * scale),
          Offset(x + colWidths[i], y + rowHeight - 7 * scale),
          borderPaint,
        );
      }
      x += colWidths[i];
    }
    y += rowHeight;
  }

  final headerBorderPaint = Paint()
    ..color = Color(0xFFB6C2CD)
    ..strokeWidth = 3.0 * scale;
  canvas.drawLine(Offset(0, infoHeight + headerHeight), Offset(width, infoHeight + headerHeight), headerBorderPaint);

  // End recording, create image, and save as before
  final picture = recorder.endRecording();
  final img = await picture.toImage(width.toInt(), height.toInt());
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  final pngBytes = byteData!.buffer.asUint8List();
  saveImageWeb(pngBytes, "Gradesheet.png");
  return "Saved as Image";
}
