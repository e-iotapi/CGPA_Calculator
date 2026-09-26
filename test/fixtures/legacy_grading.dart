// The grading functions as they were in lib/script.dart before Phase 2, kept
// as an oracle. gradecalc and reversegradecalc are verbatim; the GPA loops are
// verbatim except that the Hive box and the selecteddiscipline /
// selectedprofile globals became parameters.
// ignore_for_file: prefer_is_empty, curly_braces_in_flow_control_structures

import 'package:cgpa_calculator/course.dart';

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
      : (s == -6)
      ? "RC"
      : (s == -7)
      ? "W"
      : (s == -5)
      ? "–"
      : "?";
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
      : (s == "CLR" || s == "")
      ? -2
      : (s == "GD")
      ? -3
      : (s == "RC")
      ? -6
      : (s == "W")
      ? -7
      : -100;
}

double cgcalc(
  Iterable<Course> box,
  String selecteddiscipline,
  int selectedprofile,
) {
  var allCourses = box.where(
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

/// Credits shown, as home_page.dart summed them.
double shownCredits(Iterable<Course> courses, int profile) {
  double c = 0;
  for (Course i in courses) {
    final g = profile == 1 ? i.grade1 : i.grade2;
    c += (g < 0 && !(g == -3)) ? 0 : i.credits;
  }
  return c;
}

String cgcomp(Iterable<Course> box, String selecteddiscipline) {
  var allCourses = box.where(
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
