// import 'dart:ffi';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cgpa_calculator/constants.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/mastercourselist.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'dart:io';
import 'package:flutter_media_store/flutter_media_store.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:saver_gallery/saver_gallery.dart';

 // import 'dart:html' as html;
void saveImageWeb(Uint8List bytes, String filename) {
  // final blob = html.Blob([bytes], 'image/png');
  // final url = html.Url.createObjectUrlFromBlob(blob);
  // final anchor = html.AnchorElement(href: url)
  //   ..download = filename
  //   ..style.display = 'none';
  // html.document.body!.append(anchor);
  // anchor.click();
  // anchor.remove();
  // html.Url.revokeObjectUrl(url);
}

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
  await Hive.openBox<Course>('offshootBox');
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

List<String> compareOffshoot(List<Course> of){
  int O1=0,O2=0;
  double c1=0,c2=0;
  int co1=0,co2=0;
  for(int i =0;i<of.length;i++){
    O2+=(of[i].grade2>0)?of[i].grade2:0;
    O1+=(of[i].grade1>0)?of[i].grade1:0;
    c1+=(of[i].grade1>0)?of[i].credits:0;
    c2+=(of[i].grade2>0)?of[i].credits:0;
    co1+=(of[i].grade1>0 || of[i].grade1==-3)?1:0;
    co2+=(of[i].grade2>0 || of[i].grade2==-3)?1:0;

  }
  return [O1.toString(),c1.toString(),O2.toString(),c2.toString(),co1.toString(),co2.toString()];
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

void sorto(List<Course> offshootList, String cs) {
  if (selectedprofile == 1) {
    if (cs == "Sort by Credits(Asc)") {
      offshootList.sort((a, b) => a.credits.compareTo(b.credits));
    } else if (cs == "Sort by Credits(Des)") {
      offshootList.sort((a, b) => b.credits.compareTo(a.credits));
    } else if (cs == "Sort by Grades(Des)") {
      offshootList.sort((a, b) => b.grade1.compareTo(a.grade1));
    } else if (cs == "Sort by Grades(Asc)") {
      offshootList.sort((a, b) => a.grade1.compareTo(b.grade1));
    }
  } else if (selectedprofile == 2) {
    if (cs == "Sort by Credits(Asc)") {
      offshootList.sort((a, b) => a.credits.compareTo(b.credits));
    } else if (cs == "Sort by Credits(Des)") {
      offshootList.sort((a, b) => b.credits.compareTo(a.credits));
    } else if (cs == "Sort by Grades(Des)") {
      offshootList.sort((a, b) => b.grade2.compareTo(a.grade2));
    } else if (cs == "Sort by Grades(Asc)") {
      offshootList.sort((a, b) => a.grade2.compareTo(b.grade2));
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

Future<void> removeCourseById(String targetId) async {
  try {
    var box = Hive.box<Course>('coursesBox');
    await box.delete(targetId);
    await box.flush();
    await box.compact();
  } catch (e) {}
}
Future<void> removeOffshootCourseById(String targetId) async {
  try {
    var box = Hive.box<Course>('offshootBox');
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

Future<void> addOrUpdateCourseOffshoot(Course course) async {
  try {
    var box = Hive.box<Course>('offshootBox');
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



double sgcalc(String s) {
  var allCourses = Hive.box<Course>('coursesBox').values.where(
    (course) =>
        course.sem == s &&
        (course.discipline == selecteddiscipline.substring(0, 2) ||
            course.discipline == selecteddiscipline.substring(2, 4)),
  );
  double dontCount = 0;
  double s1 = 0;
  if (selectedprofile == 1) {
    for (Course i in allCourses) {
      s1 += (i.grade1 > 0 || i.grade1 == -3) ? i.credits : 0;
      if (i.grade1 == -3) {
        dontCount += i.credits;
      }
    }
    double sum = 0;
    for (Course i in allCourses) {
      sum += (i.grade1 > 0) ? (i.grade1 * i.credits) : 0;
    }
    return ((s1 - dontCount) != 0)
        ? double.parse(((sum) / (s1 - dontCount)).toStringAsFixed(2))
        : 0;
  } else if (selectedprofile == 2) {
    for (Course i in allCourses) {
      s1 += (i.grade2 > 0 || i.grade2 == -3) ? i.credits : 0;
      if (i.grade2 == -3) {
        dontCount += i.credits;
      }
    }
    double sum = 0;
    for (Course i in allCourses) {
      sum += (i.grade2 > 0) ? (i.grade2 * i.credits) : 0;
    }
    return ((s1 - dontCount) != 0)
        ? double.parse(((sum) / (s1 - dontCount)).toStringAsFixed(2))
        : 0;
  } else {
    return -3.0;
  }
}

String sgcomp(String s) {
  var allCourses = Hive.box<Course>('coursesBox').values.where(
    (course) =>
        course.sem == currentsem &&
        (course.discipline == selecteddiscipline.substring(0, 2) ||
            course.discipline == selecteddiscipline.substring(2, 4)),
  );
  double dontCount = 0;
  double s1 = 0;
  String ans = "";
  for (Course i in allCourses) {
    s1 += (i.grade1 > 0 || i.grade1 == -3) ? i.credits : 0;
    if (i.grade1 == -3) {
      dontCount += i.credits;
    }
  }
  double sum = 0;
  for (Course i in allCourses) {
    sum += (i.grade1 > 0) ? (i.grade1 * i.credits) : 0;
  }
  ans =
      ((s1 - dontCount) != 0)
          ? ((sum) / (s1 - dontCount)).toStringAsFixed(2)
          : "0";
  ans += ' ';
  s1 = 0;
  dontCount = 0;
  for (Course i in allCourses) {
    s1 += (i.grade2 > 0 || i.grade2 == -3) ? i.credits : 0;
    if (i.grade2 == -3) {
      dontCount += i.credits;
    }
  }
  sum = 0;
  for (Course i in allCourses) {
    sum += (i.grade2 > 0) ? (i.grade2 * i.credits) : 0;
  }
  return ans +
      (((s1 - dontCount) != 0)
          ? ((sum) / (s1 - dontCount)).toStringAsFixed(2)
          : "0");
}

double cgcalc() {
  var allCourses = Hive.box<Course>('coursesBox').values.where(
    (course) =>
        (course.discipline == selecteddiscipline.substring(0, 2) ||
            course.discipline == selecteddiscipline.substring(2, 4)),
  );
  double dontCount = 0;
  double s1 = 0;
  if (selectedprofile == 1) {
    for (Course i in allCourses) {
      s1 += (i.grade1 > 0 || i.grade1 == -3) ? i.credits : 0;
      if (i.grade1 == -3) {
        dontCount += i.credits;
      }
    }
    double sum = 0;
    for (Course i in allCourses) {
      sum += (i.grade1 > 0) ? (i.grade1 * i.credits) : 0;
    }
    return ((s1 - dontCount) != 0)
        ? double.parse(((sum) / (s1 - dontCount)).toStringAsFixed(2))
        : 0;
  } else if (selectedprofile == 2) {
    for (Course i in allCourses) {
      s1 += (i.grade2 > 0 || i.grade2 == -3) ? i.credits : 0;
      if (i.grade2 == -3) {
        dontCount += i.credits;
      }
    }
    double sum = 0;
    for (Course i in allCourses) {
      sum += (i.grade2 > 0) ? (i.grade2 * i.credits) : 0;
    }
    return ((s1 - dontCount) != 0)
        ? double.parse(((sum) / (s1 - dontCount)).toStringAsFixed(2))
        : 0;
  }
  return -3.0;
}

String cgcomp() {
  var allCourses = Hive.box<Course>('coursesBox').values.where(
    (course) =>
        (course.discipline == selecteddiscipline.substring(0, 2) ||
            course.discipline == selecteddiscipline.substring(2, 4)),
  );
  String ans = "";
  double dontCount = 0;
  double s1 = 0;
  for (Course i in allCourses) {
    s1 += (i.grade1 > 0 || i.grade1 == -3) ? i.credits : 0;
    if (i.grade1 == -3) {
      dontCount += i.credits;
    }
  }
  double sum = 0;
  for (Course i in allCourses) {
    sum += (i.grade1 > 0) ? (i.grade1 * i.credits) : 0;
  }
  ans =
      ((s1 - dontCount) != 0)
          ? ((sum) / (s1 - dontCount)).toStringAsFixed(2)
          : "0";
  ans += " ";
  s1 = 0;
  dontCount = 0;
  for (Course i in allCourses) {
    s1 += (i.grade2 > 0 || i.grade2 == -3) ? i.credits : 0;
    if (i.grade2 == -3) {
      dontCount += i.credits;
    }
  }
  sum = 0;
  for (Course i in allCourses) {
    sum += (i.grade2 > 0) ? (i.grade2 * i.credits) : 0;
  }
  return ans +
      (((s1 - dontCount) != 0)
          ? ((sum) / (s1 - dontCount)).toStringAsFixed(2)
          : "0");
}



void electiveSetter() {
  if (addcourse == "HSS" ||
      addcourse == "GS" ||
      huel.contains(addcourse + " " + addcourseid)) {
    selectedelective = "Humanity Elective";
  } else if (del[selecteddiscipline.substring(2, 4)]!.contains(
    addcourse + " " + addcourseid,
  )) {
    selectedelective = "Disciplinary Elective2";
  } else if (del[selecteddiscipline.substring(0, 2)]!.contains(
    addcourse + " " + addcourseid,
  )) {
    selectedelective = "Disciplinary Elective1";
  } else if (nonelist.contains(addcourse + " " + addcourseid)) {
    selectedelective = "CDCN";
  } else {
    selectedelective = "Open Elective";
  }
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
double scred1 = 0;
double scred2 = 0;
double ccred1 = 0;
double ccred2 = 0;
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
    //drawInfoText("CGPA: ${cgpa.toStringAsFixed(2)}", xOffset,yOffset);
    yOffset=25*scale;
    xOffset += 42 * scale;
    drawInfoText("Credits: $thisSemCredits",xOffset, yOffset);
    yOffset=width*0.82-40*scale;
    //drawInfoText("Credits: $totalCredits", xOffset,yOffset);
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


  //drawInfoText("GPA: ${gpa.toStringAsFixed(2)}  CGPA: ${cgpa.toStringAsFixed(2)}",xOffset, yOffset);

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
      (row['grade'] > -4) ? gradecalc(row['grade']):"",// :  (row['grade'] == -2) ? "GD":"CLR",
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
  if (true) {
    if (kIsWeb) {
      saveImageWeb(pngBytes, "Gradesheet.png");
      return "Saved as Image";
    } else if (Platform.isAndroid) {
      //   String downloadsPath = '/storage/emulated/0/Download';
      //   File file = File('$downloadsPath/Gradesheet.png');
      //   if(await file.exists()){
      //     for(int i=1;i<100;i++) {
      //       file = File('$downloadsPath/Gradesheet($i).png');
      //       print("A");
      //       if (!await file.exists()) {
      //         break;
      //       }
      //     }
      //   }
      //   await file.writeAsBytes(pngBytes);
      //   return file.path;
      bool permissionGranted = await requestAllStoragePermissions();
      if (!permissionGranted) {
        return "Storage permission denied";
      }

      try {
        final result = await SaverGallery.saveImage(
          pngBytes,
          quality: 100,
          androidRelativePath: "Pictures/CGPA Calculator", fileName: "Gradesheet.png", skipIfExists: false,
        );

        if (result.isSuccess) {
          //print('File saved: Pictures/CGPA Calculator/Gradesheet.png');
          return "Saved at: Pictures/CGPA Calculator/Gradesheet.png";
        } else {
          //print('Error saving file: ${result.errorMessage}');
          return "Could not save";
        }
      } catch (e) {
       // print('Exception saving file: $e');
        return "Could not save";
      }
    }
  }
  return "Could not Save";
}


Future<bool> requestAllStoragePermissions() async {
  // Try traditional Storage permission
  if(kIsWeb){
    return true;
  }
  if(Platform.isAndroid) {
    var status = await Permission.photos.request();

    if (status.isGranted) {
      return true;
    }

    if (status.isPermanentlyDenied) {
      // Show a dialog to open app settings
      await openAppSettings();
      return false;
    }

    // If denied (but not permanently)
    return false;
  }

  // If none are granted, permissions are denied!
  return false;
}