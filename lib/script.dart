import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cgpa_calculator/constants.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/mastercourselist.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'dart:io';
import 'dart:html' as html;

import 'package:path_provider/path_provider.dart';

Future<void> basicStartup() async {
  var settingsBox = await Hive.openBox('settingsBox');
  final coursesBox = await Hive.openBox<Course>('coursesBox');
  selecteddiscipline = settingsBox.get(
    'selecteddiscipline',
    defaultValue: selecteddiscipline,
  );
  batch = settingsBox.get('batch', defaultValue: 24);
  selectedcampus = settingsBox.get(
    'selectedcampus',
    defaultValue: selectedcampus,
  );
  selected_theme = settingsBox.get(
    'selected_theme',
    defaultValue: selected_theme,
  );
  degree_selected = settingsBox.get('degree_selected', defaultValue: false);
  currentsort = settingsBox.get('currentsort', defaultValue: currentsort);
  currentsem = settingsBox.get('currentsem', defaultValue: currentsem);
  profile1n = settingsBox.get('profile1n', defaultValue: profile1n);
  profile2n = settingsBox.get('profile2n', defaultValue: profile2n);
}

Future<void> copyGrades() async{
  final coursesBox = await Hive.openBox<Course>('coursesBox');
  for(var i in coursesBox.values){
    if(i.sem==currentsem) {
      await coursesBox.put(i.id, Course(title: i.title, sem: i.sem, id: i.id, grade1: i.grade1, grade2: i.grade1, discipline: i.discipline, credits: i.credits, elective: i.elective));
    }
  }
}

Future<void> initializeCourses() async {
  var settingsBox = await Hive.openBox('settingsBox');
  final coursesBox = await Hive.openBox<Course>('coursesBox');
  selecteddiscipline = settingsBox.get(
    'selecteddiscipline',
    defaultValue: selecteddiscipline,
  );
  batch = settingsBox.get('batch', defaultValue: 24);
  selectedcampus = settingsBox.get(
    'selectedcampus',
    defaultValue: selectedcampus,
  );
  selected_theme = settingsBox.get(
    'selected_theme',
    defaultValue: selected_theme,
  );
  degree_selected = settingsBox.get('degree_selected', defaultValue: false);
  currentsort = settingsBox.get('currentsort', defaultValue: currentsort);
  currentsem = settingsBox.get('currentsem', defaultValue: currentsem);
  profile1n = settingsBox.get('profile1n', defaultValue: profile1n);
  profile2n = settingsBox.get('profile2n', defaultValue: profile2n);
  if (erase == 1) {
    await coursesBox.clear();
    String tempsem = "";
    List<String> tempaddedcourses = [];
    for (var course
    in ((batch < 25)
        ? (selectedcampus == "Hyd")
        ? hydCourseList
        : (selectedcampus == "Goa")
        ? goaCourseList
        : pilaniCourseList
        : (selectedcampus == "Hyd")
        ? hydCourseListNew
        : (selectedcampus == "Goa")
        ? goaCourseListNew
        : pilaniCourseListNew)) {
      if (course.discipline ==
          ((selecteddiscipline.substring(0, 2) != "--")
              ? selecteddiscipline.substring(0, 2)
              : selecteddiscipline.substring(2, 4))) {
        await coursesBox.put(course.id, course);
        tempaddedcourses.add(course.title);
      }
      if (course.discipline ==
          ((selecteddiscipline.substring(0, 2) != "--")
              ? selecteddiscipline.substring(2, 4)
              : "cccc")) {
        if (course.elective == "CDC2" &&
            !tempaddedcourses.contains(course.title)) {
          if (selecteddiscipline == "B5AA" ||
              selecteddiscipline == "B5A3" ||
              selecteddiscipline == "B5A8" ||
              selecteddiscipline == "B2AA" ||
              selecteddiscipline == "B2A3" ||
              selecteddiscipline == "B2A8" ||
              selecteddiscipline == "B4AD") {
            if ((course.title == "Algebra I" ||
                course.title == "Discrete Mathematics" ||
                course.title == "Elementary Real Analysis" ||
                course.title == "Numerical Analysis" ||
                course.title == "Electromagnetic Theory")) {
            } else {
              tempsem = course.sem;
              tempsem =
                  (int.parse(tempsem.substring(0, 1)) + 1).toString() +
                      tempsem.substring(1, 5);
              //print(tempsem);
              Course Course1 = Course(
                title: course.title,
                sem: tempsem,
                id: course.id,
                grade1: course.grade1,
                grade2: course.grade2,
                discipline: course.discipline,
                credits: course.credits,
                elective: course.elective,
              );
              try {
                await coursesBox.put(Course1.id, Course1);
                //print('Stored modified course with id: ${course.id}');
              } catch (e) {
                //print('Error storing course: $e');
              }
            }
          } else {
            tempsem = course.sem;
            tempsem =
                (int.parse(tempsem.substring(0, 1)) + 1).toString() +
                    tempsem.substring(1, 5);
            //print(tempsem);
            Course Course1 = Course(
              title: course.title,
              sem: tempsem,
              id: course.id,
              grade1: course.grade1,
              grade2: course.grade2,
              discipline: course.discipline,
              credits: course.credits,
              elective: course.elective,
            );
            try {
              await coursesBox.put(Course1.id, Course1);
              //print('Stored modified course with id: ${course.id}');
            } catch (e) {
              //print('Error storing course: $e');
            }
          }
        }
      }
    }
    //print("All keys in coursesBox: ${coursesBox.keys}");
    setsort();
  } else if (erase == 0) {
    if (degree_selected == true) {
      if (!coursesBox.values.any(
            (course) =>
        course.discipline ==
            ((selecteddiscipline.startsWith("B"))
                ? selecteddiscipline.substring(0, 2)
                : selecteddiscipline.substring(2, 4)) ||
            course.discipline ==
                ((selecteddiscipline.startsWith("B"))
                    ? selecteddiscipline.substring(2, 4)
                    : "ccccc"),
      )) {
        String tempsem = "";
        for (var course
        in ((batch < 25)
            ? (selectedcampus == "Hyd")
            ? hydCourseList
            : (selectedcampus == "Goa")
            ? goaCourseList
            : pilaniCourseList
            : (selectedcampus == "Hyd")
            ? hydCourseListNew
            : (selectedcampus == "Goa")
            ? goaCourseListNew
            : pilaniCourseListNew)) {
          if (course.discipline ==
              ((selecteddiscipline.substring(0, 2) != "--")
                  ? selecteddiscipline.substring(0, 2)
                  : selecteddiscipline.substring(2, 4))) {
            await coursesBox.put(course.id, course);
          }
          if (course.discipline ==
              ((selecteddiscipline.substring(0, 2) != "--")
                  ? selecteddiscipline.substring(2, 4)
                  : "cccc")) {
            if (selecteddiscipline == "B5AA" ||
                selecteddiscipline == "B5A3" ||
                selecteddiscipline == "B5A8" ||
                selecteddiscipline == "B4AD") {
              if ((course.title == "Algebra I" ||
                  course.title == "Discrete Mathematics" ||
                  course.title == "Elementary Real Analysis" ||
                  course.title == "Numerical Analysis" ||
                  course.title == "Electromagnetic Theory")) {
              } else {
                if (course.elective == "CDC2") {
                  tempsem = course.sem;
                  tempsem =
                      (int.parse(tempsem.substring(0, 1)) + 1).toString() +
                          tempsem.substring(1, 5);
                  //print(tempsem);
                  Course Course1 = Course(
                    title: course.title,
                    sem: tempsem,
                    id: course.id,
                    grade1: course.grade1,
                    grade2: course.grade2,
                    discipline: course.discipline,
                    credits: course.credits,
                    elective: course.elective,
                  );

                  try {
                    await coursesBox.put(Course1.id, Course1);
                    //print('Stored modified course with id: ${course.id}');
                  } catch (e) {
                    //print('Error storing course: $e');
                  }
                }
              }
            } else {
              if (course.elective == "CDC2") {
                tempsem = course.sem;
                tempsem =
                    (int.parse(tempsem.substring(0, 1)) + 1).toString() +
                        tempsem.substring(1, 5);
                //print(tempsem);
                Course Course1 = Course(
                  title: course.title,
                  sem: tempsem,
                  id: course.id,
                  grade1: course.grade1,
                  grade2: course.grade2,
                  discipline: course.discipline,
                  credits: course.credits,
                  elective: course.elective,
                );

                try {
                  await coursesBox.put(Course1.id, Course1);
                  //print('Stored modified course with id: ${course.id}');
                } catch (e) {
                  //print('Error storing course: $e');
                }
              }
            }
          }
          //print("All keys in coursesBox: ${coursesBox.keys}");
          setsort();
        }
      }
    }
  } else if (erase == 2) {
    final keysToDelete = [];
    final tempcourses = [];
    for (final entry in coursesBox.toMap().entries) {
      final key = entry.key;
      final item = entry.value;
      if (item.discipline.startsWith("B")) {
        tempcourses.add(item.title);
      }
      if (item.discipline.startsWith("A") &&
          item.elective == "CDC2" &&
          !item.sem.startsWith("1")) {
        if (selecteddiscipline.startsWith("B") && !item.sem.startsWith("1")) {
          keysToDelete.add(key);
        } else if (!selecteddiscipline.startsWith("B")) {
          keysToDelete.add(key);
        }
      }
    }
    if (keysToDelete.isNotEmpty) {
      await coursesBox.deleteAll(keysToDelete);
    }
    String tempsem = "";
    for (var course
    in ((batch < 25)
        ? (selectedcampus == "Hyd")
        ? hydCourseList
        : (selectedcampus == "Goa")
        ? goaCourseList
        : pilaniCourseList
        : (selectedcampus == "Hyd")
        ? hydCourseListNew
        : (selectedcampus == "Goa")
        ? goaCourseListNew
        : pilaniCourseListNew)) {
      //print("0");
      if (course.discipline == selecteddiscipline.substring(2, 4)) {
        //print("A");
        if (!tempcourses.contains(course.title)) {
          //print("B");
          if (selecteddiscipline == "B5AA" ||
              selecteddiscipline == "B5A3" ||
              selecteddiscipline == "B5A8" ||
              selecteddiscipline == "B4AD") {
            //print("C");
            if (!(course.title == "Algebra I" ||
                course.title == "Discrete Mathematics" ||
                course.title == "Elementary Real Analysis" ||
                course.title == "Numerical Analysis" ||
                course.title == "Electromagnetic Theory")) {
              // print("D");
              if (course.elective == "CDC2" &&
                  selecteddiscipline.startsWith("B")) {
                tempsem = course.sem;
                tempsem =
                    (int.parse(tempsem.substring(0, 1)) + 1).toString() +
                        tempsem.substring(1, 5);
                //print(tempsem);
                Course Course1 = Course(
                  title: course.title,
                  sem: tempsem,
                  id: course.id,
                  grade1: course.grade1,
                  grade2: course.grade2,
                  discipline: course.discipline,
                  credits: course.credits,
                  elective: course.elective,
                );
                try {
                  await coursesBox.put(Course1.id, Course1);
                  //print('Stored modified course with id: ${course.id}');
                } catch (e) {
                  //print('Error storing course: $e');
                }
              }
            }
          } else {
            if (course.elective == "CDC2" &&
                selecteddiscipline.startsWith("B")) {
              tempsem = course.sem;
              tempsem =
                  (int.parse(tempsem.substring(0, 1)) + 1).toString() +
                      tempsem.substring(1, 5);
              //print(tempsem);
              Course Course1 = Course(
                title: course.title,
                sem: tempsem,
                id: course.id,
                grade1: course.grade1,
                grade2: course.grade2,
                discipline: course.discipline,
                credits: course.credits,
                elective: course.elective,
              );
              try {
                await coursesBox.put(Course1.id, Course1);
              } catch (e) {
                //print('Error storing course: $e');
              }
            }
          }
        }
      } else if (selecteddiscipline.startsWith("--")) {
        //print("abc");
        await coursesBox.put(course.id, course);
      }
      //await coursesBox.put(course.id, course);
    }
  }
  //print("All keys in coursesBox: ${coursesBox.keys}");
}

Future<void> setdis() async {
  var settingsBox = await Hive.openBox('settingsBox');
  await settingsBox.put('batch', batch);
  await settingsBox.put('selecteddiscipline', selecteddiscipline);
  await settingsBox.put('selectedcampus', selectedcampus);
  await settingsBox.put('degree_selected', true);
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

Future<void> removeCourseById(String targetId) async {
  try {
    var box = Hive.box<Course>('coursesBox');
    await box.delete(targetId);
    await box.flush();
    await box.compact();
  } catch (e) {}
}

Future<void> addCourse(Course course) async {
  try {
    var box = Hive.box<Course>('coursesBox');
    await box.add(course);
    await box.flush();
  } catch (e) {}
}

Future<void> addOrUpdateCourse(Course course) async {
  try {
    var box = Hive.box<Course>('coursesBox');
    await box.put(course.id, course);
    await box.flush();
  } catch (e) {}
}

String gradecalc(int s) {
  return (s == 10)
      ? "A"
      : (s == 9)
      ? "A-"
      : (s == 8)
      ? "B"
      : (s == 7)
      ? "B-"
      : (s == 6)
      ? "C"
      : (s == 5)
      ? "C-"
      : (s == 4)
      ? "D"
      : (s == 2)
      ? "E"
      : (s == -1)
      ? "NC"
      : (s == -2)
      ? "CLR"
      : (s == -3)
      ? "GD"
      : (s == -5)
      ? "–"
      : "?";
}

String electiveFinder(String s) {
  if (s == "CDC2") {
    return selecteddiscipline.substring(2, 4) + " " + "CDC";
  } else if (s == "CDC1") {
    return selecteddiscipline.substring(0, 2) + " " + "CDC";
  } else if (s == "CDCN") {
    return "None";
  } else if (s == "Open Elective") {
    return "Open Elective";
  } else if (s == "Disciplinary Elective2") {
    return selecteddiscipline.substring(2, 4) + " " + "Disciplinary Elective";
  } else if (s == "Disciplinary Elective1") {
    return selecteddiscipline.substring(0, 2) + " " + "Disciplinary Elective";
  } else if (s == "Humanity Elective") {
    return "Humanity Elective";
  } else {
    return s;
  }
}

int reversegradecalc(String s) {
  return (s == "A")
      ? 10
      : (s == "A-")
      ? 9
      : (s == "B")
      ? 8
      : (s == "B-")
      ? 7
      : (s == "C")
      ? 6
      : (s == "C-")
      ? 5
      : (s == "D")
      ? 4
      : (s == "E")
      ? 2
      : (s == "NC")
      ? -1
      : (s == "CLR" || s=="")
      ? -2
      : (s == "GD")
      ? -3
      : -100;
}

void setnavcolor() {
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle.light.copyWith(
      systemNavigationBarColor: thm.backcolor,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
}



var thm = themes.firstWhere((x) => x.theme == selected_theme);
double sgpa = 0.00;
double cgpa = 0.00;
int tapid = 0;
int batch = 24;
String selecteddiscipline = "----"; //store
String selectedcampus = "Hyd";
int selectedprofile = 1;
int selectedgrade = 10;
String selectedelective = "None";
String currentsem = "1 - 1"; // store
int scred1 = 0;
int scred2 = 0;
int ccred1 = 0;
int ccred2 = 0;
String profile1n = "Actual";
String profile2n = "Expected";

String addcourse = "AN";
String currentsort = "Sort by Credits(Asc)"; //store
String selected_theme = "White";
bool degree_selected = false;
int erase = 0;
bool isUpdating = false;
String addcourseid = dropdownid[0];
List<String> anCourseIds =
mcourselist
    .where((course) => course.id.startsWith('AN '))
    .map((course) => course.id.replaceFirst('AN ', ''))
    .toList();
List<String> dropdownid = anCourseIds;
final List<String> depts = [
  "AN",
  "BIO",
  "BIOT",
  "BITS",
  "CE",
  "CHE",
  "CHEM",
  "CS",
  "ECE",
  "ECON",
  "ECOM",
  "EEE",
  "FIN",
  "GS",
  "HSS",
  "INSTR",
  "IS",
  "MAC",
  "MATH",
  "ME",
  "MF",
  "MGTS",
  "MSE",
  "MST",
  "PHA",
  "PHY",
  "SNS",
];
final List<String> grades = [
  "A",
  "A-",
  "B",
  "B-",
  "C",
  "C-",
  "D",
  "E",
  "NC",
  "CLR",
  "GD",
  ""
];
final List<String> sems = [
  "1 - 1",
  "1 - 2",
  "2 - 1",
  "2 - 2",
  "PS 1",
  "3 - 1",
  "3 - 2",
  "ST 1",
  "4 - 1",
  "4 - 2",
];
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
final List<String> campuslist = ["Pilani", "Goa", "Hyd"];

Future<String> saveDataAsImage(List<Map<String, dynamic>> data) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  final double scale = 4.0;
  final double width = 700 * scale;
  final double headerHeight = 56 * scale;
  final double rowHeight = 40 * scale;
  final int numberOfRows = data.length;
  final double height = headerHeight + numberOfRows * rowHeight;
  final double borderRadius = 14 * scale;
  final List<double> colWidths = [100 * scale, 400 * scale, 70 * scale];

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

  final cardPaint = Paint()..color = Color(0xFFF4F7FA);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, width, height),
      Radius.circular(borderRadius),
    ),
    cardPaint,
  );

  final headerGradient = Paint()
    ..shader = ui.Gradient.linear(
      Offset(0, 0), Offset(width, 0),
      [Color(0xFF4C74FF), Color(0xFF73C2FB)],
    );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, width, headerHeight),
      Radius.circular(borderRadius),
    ),
    headerGradient,
  );

  final textPainter = TextPainter(
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.left,
  );
  double x = 0, y = 0;
  final headers = ['Credits', 'Course', 'Grade'];
  for (int i = 0; i < headers.length; i++) {
    textPainter.text = TextSpan(
      text: headers[i],
      style: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 22 * scale,
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

    final rowPaint = Paint()..color = even ? Color(0xFFFFFFFF) : Color(0xFFF1F6FF);
    canvas.drawRect(Rect.fromLTWH(0, y, width, rowHeight), rowPaint);

    final borderPaint = Paint()
      ..color = Color(0xFFE5E5E5)
      ..strokeWidth = 2.0 * scale;
    canvas.drawLine(Offset(0, y), Offset(width, y), borderPaint);

    final cellTexts = [
      row['credits'].toString(),
      row['name'],
      (row['grade'] > 0) ? gradecalc(row['grade']) : "CLR",
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
  canvas.drawLine(Offset(0, headerHeight), Offset(width, headerHeight), headerBorderPaint);

  final picture = recorder.endRecording();
  final img = await picture.toImage(width.toInt(), height.toInt());
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  final pngBytes = byteData!.buffer.asUint8List();

  if (await requestAllStoragePermissions()) {
    if (kIsWeb) {
      saveImageWeb(pngBytes, "cgpa.png");
      return "Saved as Image";
    } else if(Platform.isAndroid){
      String downloadsPath = '/storage/emulated/0/Download';
      File file = File('$downloadsPath/cgpa.png');
      await file.writeAsBytes(pngBytes);
      return file.path;
    }
  }
  return "Could not Save";
}

void saveImageWeb(Uint8List bytes, String filename) {
  final blob = html.Blob([bytes], 'image/png');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}

Future<bool> requestAllStoragePermissions() async {
  // Try traditional Storage permission
  if(kIsWeb){
    return true;
  }
  if(Platform.isAndroid) {
    var storage = await Permission.storage.request();
    if (storage.isGranted) return true;

    // Try Manage External Storage (Android 11+)
    var manage = await Permission.manageExternalStorage.request();
    if (manage.isGranted) return true;

    // Try Media Images Write (Android 13+)
    var media = await Permission.photos.request();
    if (media.isGranted) return true;
  }
  // If none are granted, permissions are denied!
  return false;
}