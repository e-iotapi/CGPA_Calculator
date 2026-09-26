import 'package:cgpa_calculator/constants.dart';
import 'package:cgpa_calculator/core/grading/requirements.dart';
import 'package:cgpa_calculator/core/models/elective.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/settings.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'dart:math';
import 'script.dart';

class Analytics extends StatefulWidget {
  const Analytics({Key? key}) : super(key: key);

  List<Course> get sitemslist =>
  Hive.box<Course>('coursesBox').values
      .where(
  (course) =>
  (course.discipline ==
  ((selecteddiscipline.substring(0, 2) != "--")
  ? selecteddiscipline.substring(0, 2)
      : selecteddiscipline.substring(2, 4)) ||
  course.discipline ==
  ((selecteddiscipline.substring(0, 2) != "--")
  ? selecteddiscipline.substring(2, 4)
      : "ccccc")),
  )
      .toList();

  @override
  State<Analytics> createState() => _AnalyticsState();
}

double creds(String s, List<Course> si) =>
    earnedCredits(Elective.fromTag(s)!, si);

class _AnalyticsState extends State<Analytics> {
  // Reference data lives in core/grading/requirements.dart.
  final creditsforcourses = {
    for (final e in requirements.entries)
      e.key: [
        e.value.cdcCourses,
        e.value.cdcCredits,
        e.value.delCourses,
        e.value.delCredits,
      ],
  };
  @override
  Widget build(BuildContext context) {
    //print(((MediaQuery.of(context).size.height -max((40+min(MediaQuery.of(context).size.width * 0.28,100)),100)) > 3*MediaQuery.of(context).size.width*0.50 )?20:(MediaQuery.of(context).size.height*0.78 -(40+min(MediaQuery.of(context).size.width * 0.28,100)))/3);
    // print(widget.sitemslist.where((Course) => Course.elective == Elective.cdc1.tag && (Course.grade1 > 0 || Course.grade1==-3),).length.toString());
    // `print`(widget.sitemslist.where((Course) => Course.elective == Elective.cdc2.tag && (Course.grade1 > 0 || Course.grade1==-3),).length.toString());
    var thm = themes.firstWhere((theme) => theme.theme == selected_theme);
    setnavcolor();
    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(
          color:
              thm
                  .textcolor,
        ),
        title: Text(
          "Analytics",
          style: TextStyle(
            fontFamily: "Montserrat",
            fontSize: 20,
            color:
                thm
                    .textcolor,
          ),
        ),
        backgroundColor:
            thm
                .backcolor,
      ),
      backgroundColor:
          thm
              .backcolor, //themes[0].backcolor,
      body: SafeArea(child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(height: 10),
          SizedBox(
            height: min(MediaQuery.of(context).size.width * 0.28,100),
            width: MediaQuery.of(context).size.width * 0.90,
            child: InkWell(
              onTap:
                  (selecteddiscipline == "----")
                      ? () async {
                        await Navigator.of(context)
                            .push(
                              MaterialPageRoute(
                                builder: (context) => Settings(),
                              ),
                            )
                            .then((value) async {
                              selected_theme = selected_theme;
                              await settheme();
                              profile1n = profile1n;
                              profile2n = profile2n;
                              await setprof();
                              currentsem = currentsem;
                              selecteddiscipline = selecteddiscipline;
                              await setdis();
                              await initializeCourses();
                              setState(() {
                                profile1n = profile1n;
                                selecteddiscipline = selecteddiscipline;
                                selected_theme = selected_theme;
                                // items = courselist
                                //     .where((course) => course.sem == currentsem && course.discipline == selecteddiscipline)
                                //     .toList();
                              });
                            });
                      }
                      : null,
              child: Card(
                elevation: 3,
                color:
                    thm
                        .cardcolor,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            (selecteddiscipline != "----")
                                ? "Total Credits "
                                : "Select Discipline to View Analytics",
                            softWrap: true,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color:
                                  (selecteddiscipline != "----")
                                      ? thm
                                          .textcolor
                                      : thm
                                          .highcolor,
                              fontSize: 18,
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Spacer(flex: 1),
                        Text(
                          (selecteddiscipline != "----") ? "$ccred1 / 144".replaceAll('.0', '') : "",
                          style: TextStyle(
                            color:
                                thm
                                    .textcolor,
                            fontSize: 22,
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Spacer(flex: 1),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 20),
          Center(
            child: Row(
              children: [
                Spacer(flex: 1),
                if (selecteddiscipline.substring(2, 4).startsWith("A"))
                  Column(
                    children: [
                      SizedBox(
                        height: ((MediaQuery.of(context).size.height -max((40+min(MediaQuery.of(context).size.width * 0.28,100)),100)) > 3*MediaQuery.of(context).size.width*0.50 )?MediaQuery.of(context).size.width * 0.42:(MediaQuery.of(context).size.height*0.78 -(40+min(MediaQuery.of(context).size.width * 0.28,100)))/3,
                        width: ((MediaQuery.of(context).size.height -max((40+min(MediaQuery.of(context).size.width * 0.28,100)),100)) > 3*MediaQuery.of(context).size.width*0.50 )?MediaQuery.of(context).size.width * 0.42:(MediaQuery.of(context).size.height*0.78 -(40+min(MediaQuery.of(context).size.width * 0.28,100)))/3,
                        child: Card(
                          elevation: 3,
                          color:
                              thm
                                  .cardcolor,
                          child: Column(
                            children: [
                              SizedBox(height: 10),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  "CDC (" +
                                      selecteddiscipline.substring(2, 4) +
                                      ")",
                                  textAlign: TextAlign.center,
                                  softWrap: true,
                                  style: TextStyle(
                                    color:
                                        thm
                                            .textcolor,
                                    fontSize: 13,
                                    fontFamily: 'Montserrat',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Spacer(flex: 4),
                              Row(
                                children: [
                                  Text(
                                    "  Courses",
                                    style: TextStyle(
                                      color:
                                          thm
                                              .textcolor,
                                      fontSize: 13,
                                      fontFamily: 'Montserrat',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Spacer(flex: 1),
                                  Text(
                                    widget.sitemslist
                                            .where(
                                              (Course) =>
                                                  Course.elective == Elective.cdc2.tag &&
                                                      (Course.grade1 > 0 || Course.grade1==-3),
                                            )
                                            .length
                                            .toString() +
                                        "/" +
                                        creditsforcourses[selecteddiscipline
                                                .substring((2))]![0]
                                            .toString() +
                                        "  ",
                                    style: TextStyle(
                                      color:
                                          thm
                                              .textcolor,
                                      fontSize: 13,
                                      fontFamily: 'Montserrat',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Text(
                                    "  Credits",
                                    style: TextStyle(
                                      color:
                                          thm
                                              .textcolor,
                                      fontSize: 13,
                                      fontFamily: 'Montserrat',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Spacer(flex: 1),
                                  Text(
                                    creds(
                                          Elective.cdc2.tag,
                                          widget.sitemslist,
                                        ).toString().replaceAll('.0', '') +
                                        "/" +
                                        creditsforcourses[selecteddiscipline
                                                .substring((2))]![1]
                                            .toString() +
                                        "  ",
                                    style: TextStyle(
                                      color:
                                          thm
                                              .textcolor,
                                      fontSize: 13,
                                      fontFamily: 'Montserrat',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Spacer(flex: 1),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                SizedBox(width: MediaQuery.of(context).size.width * 0.03),
                if (selecteddiscipline.substring(2, 4).startsWith("A"))
                  Column(
                    children: [
                      SizedBox(
                        height: ((MediaQuery.of(context).size.height -max((40+min(MediaQuery.of(context).size.width * 0.28,100)),100)) > 3*MediaQuery.of(context).size.width*0.50 )?MediaQuery.of(context).size.width * 0.42:(MediaQuery.of(context).size.height*0.78 -(40+min(MediaQuery.of(context).size.width * 0.28,100)))/3,
                        width: ((MediaQuery.of(context).size.height -max((40+min(MediaQuery.of(context).size.width * 0.28,100)),100)) > 3*MediaQuery.of(context).size.width*0.50 )?MediaQuery.of(context).size.width * 0.42:(MediaQuery.of(context).size.height*0.78 -(40+min(MediaQuery.of(context).size.width * 0.28,100)))/3,
                        child: Card(
                          elevation: 3,
                          color:
                              thm
                                  .cardcolor,
                          child: Column(
                            children: [
                              SizedBox(height: 10),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  "Disciplinary Electives (" +
                                      selecteddiscipline.substring(2, 4) +
                                      ")",
                                  softWrap: true,
                                  style: TextStyle(
                                    color:
                                        thm
                                            .textcolor,
                                    fontSize: 13,
                                    fontFamily: 'Montserrat',
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Spacer(flex: 4),
                              Row(
                                children: [
                                  Text(
                                    "  Courses",
                                    style: TextStyle(
                                      color:
                                          thm
                                              .textcolor,
                                      fontSize: 13,
                                      fontFamily: 'Montserrat',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Spacer(flex: 1),
                                  Text(
                                    widget.sitemslist
                                            .where(
                                              (Course) =>
                                                  Course.elective ==
                                                      Elective.del2.tag &&
                                                      (Course.grade1 > 0 || Course.grade1 == -3),
                                            )
                                            .length
                                            .toString() +
                                        "/" +
                                        creditsforcourses[selecteddiscipline
                                                .substring((2))]![2]
                                            .toString() +
                                        "  ",
                                    style: TextStyle(
                                      color:
                                          thm
                                              .textcolor,
                                      fontSize: 13,
                                      fontFamily: 'Montserrat',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Text(
                                    "  Credits",
                                    style: TextStyle(
                                      color:
                                          thm
                                              .textcolor,
                                      fontSize: 13,
                                      fontFamily: 'Montserrat',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Spacer(flex: 1),
                                  Text(
                                    creds(
                                          Elective.del2.tag,
                                          widget.sitemslist,
                                        ).toString().replaceAll('.0', '') +
                                        "/" +
                                        creditsforcourses[selecteddiscipline
                                                .substring((2))]![3]
                                            .toString() +
                                        "  ",
                                    style: TextStyle(
                                      color:
                                          thm
                                              .textcolor,
                                      fontSize: 13,
                                      fontFamily: 'Montserrat',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Spacer(flex: 1),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                Spacer(flex: 1),
              ],
            ),
          ),
          if (selecteddiscipline.startsWith("B"))
            SizedBox(height: MediaQuery.of(context).size.width * 0.03),
          if (selecteddiscipline.startsWith("B"))
            Center(
              child: Row(
                children: [
                  Spacer(flex: 1),
                  Column(
                    children: [
                      SizedBox(
                        height: ((MediaQuery.of(context).size.height -max((40+min(MediaQuery.of(context).size.width * 0.28,100)),100)) > 3*MediaQuery.of(context).size.width*0.50 )?MediaQuery.of(context).size.width * 0.42:(MediaQuery.of(context).size.height*0.78 -(40+min(MediaQuery.of(context).size.width * 0.28,100)))/3,
                        width: ((MediaQuery.of(context).size.height -max((40+min(MediaQuery.of(context).size.width * 0.28,100)),100)) > 3*MediaQuery.of(context).size.width*0.50 )?MediaQuery.of(context).size.width * 0.42:(MediaQuery.of(context).size.height*0.78 -(40+min(MediaQuery.of(context).size.width * 0.28,100)))/3,
                        child: Card(
                          elevation: 3,
                          color:
                              thm
                                  .cardcolor,
                          child: Column(
                            children: [
                              SizedBox(height: 10),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  "CDC (" +
                                      selecteddiscipline.substring(0, 2) +
                                      ")",
                                  textAlign: TextAlign.center,
                                  softWrap: true,
                                  style: TextStyle(
                                    color:
                                        thm
                                            .textcolor,
                                    fontSize: 13,
                                    fontFamily: 'Montserrat',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Spacer(flex: 4),
                              Row(
                                children: [
                                  Text(
                                    "  Courses",
                                    style: TextStyle(
                                      color:
                                          thm
                                              .textcolor,
                                      fontSize: 13,
                                      fontFamily: 'Montserrat',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Spacer(flex: 1),
                                  Text(
                                    widget.sitemslist
                                            .where(
                                              (Course) =>
                                                  Course.elective == Elective.cdc1.tag &&
                                                      (Course.grade1 > 0 || Course.grade1==-3),
                                            )
                                            .length
                                            .toString() + ((!selecteddiscipline.startsWith("B-"))?(
    "/" +
    creditsforcourses[selecteddiscipline
                                               .substring(0, 2)]![0]
                                           .toString() +
                                        "  "):"  "),
                                    style: TextStyle(
                                      color:
                                          thm
                                              .textcolor,
                                      fontSize: 13,
                                      fontFamily: 'Montserrat',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Text(
                                    "  Credits",
                                    style: TextStyle(
                                      color:
                                          thm
                                              .textcolor,
                                      fontSize: 13,
                                      fontFamily: 'Montserrat',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Spacer(flex: 1),
                                  Text(
                                    creds(
                                          Elective.cdc1.tag,
                                          widget.sitemslist,
                                        ).toString().replaceAll('.0', '') +((!selecteddiscipline.startsWith("B-"))?(
                                        "/" +
                                            creditsforcourses[selecteddiscipline
                                                .substring(0, 2)]![1]
                                                .toString() +
                                            "  "):"  "),
                                    style: TextStyle(
                                      color:
                                          thm
                                              .textcolor,
                                      fontSize: 13,
                                      fontFamily: 'Montserrat',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Spacer(flex: 1),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: MediaQuery.of(context).size.width * 0.03),
                  Column(
                    children: [
                      SizedBox(
                        height: ((MediaQuery.of(context).size.height -max((40+min(MediaQuery.of(context).size.width * 0.28,100)),100)) > 3*MediaQuery.of(context).size.width*0.50 )?MediaQuery.of(context).size.width * 0.42:(MediaQuery.of(context).size.height*0.78 -(40+min(MediaQuery.of(context).size.width * 0.28,100)))/3,
                        width: ((MediaQuery.of(context).size.height -max((40+min(MediaQuery.of(context).size.width * 0.28,100)),100)) > 3*MediaQuery.of(context).size.width*0.50 )?MediaQuery.of(context).size.width * 0.42:(MediaQuery.of(context).size.height*0.78 -(40+min(MediaQuery.of(context).size.width * 0.28,100)))/3,
                        child: Card(
                          elevation: 3,
                          color:
                              thm
                                  .cardcolor,
                          child: Column(
                            children: [
                              SizedBox(height: 10),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  "Disciplinary Electives (" +
                                      selecteddiscipline.substring(0, 2) +
                                      ")",
                                  softWrap: true,
                                  style: TextStyle(
                                    color:
                                        thm
                                            .textcolor,
                                    fontSize: 13,
                                    fontFamily: 'Montserrat',
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Spacer(flex: 4),
                              Row(
                                children: [
                                  Text(
                                    "  Courses",
                                    style: TextStyle(
                                      color:
                                          thm
                                              .textcolor,
                                      fontSize: 13,
                                      fontFamily: 'Montserrat',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Spacer(flex: 1),
                                  Text(
                                    widget.sitemslist
                                            .where(
                                              (Course) =>
                                                  Course.elective ==
                                                      Elective.del1.tag &&
                                                      (Course.grade1 > 0 || Course.grade1==-3),
                                            )
                                            .length
                                            .toString() +((!selecteddiscipline.startsWith("B-"))?(
                                        "/" +
                                            creditsforcourses[selecteddiscipline
                                                .substring(0, 2)]![2]
                                                .toString() +
                                            "  "):"  "),
                                    style: TextStyle(
                                      color:
                                          thm
                                              .textcolor,
                                      fontSize: 13,
                                      fontFamily: 'Montserrat',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Text(
                                    "  Credits",
                                    style: TextStyle(
                                      color:
                                          thm
                                              .textcolor,
                                      fontSize: 13,
                                      fontFamily: 'Montserrat',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Spacer(flex: 1),
                                  Text(
                                    creds(
                                          Elective.del1.tag,
                                          widget.sitemslist,
                                        ).toString().replaceAll('.0', '') +((!selecteddiscipline.startsWith("B-"))?(
                                        "/" +
                                            creditsforcourses[selecteddiscipline
                                                .substring(0, 2)]![3]
                                                .toString() +
                                            "  "):"  "),
                                    style: TextStyle(
                                      color:
                                          thm
                                              .textcolor,
                                      fontSize: 13,
                                      fontFamily: 'Montserrat',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Spacer(flex: 1),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  Spacer(flex: 1),
                ],
              ),
            ),
          SizedBox(height: MediaQuery.of(context).size.width * 0.03),
          Center(
            child: Row(
              children: [
                Spacer(flex: 1),
                Column(
                  children: [
                    if (selecteddiscipline != "----")
                      Column(
                        children: [
                          SizedBox(
                            height: ((MediaQuery.of(context).size.height -max((40+min(MediaQuery.of(context).size.width * 0.28,100)),100)) > 3*MediaQuery.of(context).size.width*0.50 )?MediaQuery.of(context).size.width * 0.42:(MediaQuery.of(context).size.height*0.78 -(40+min(MediaQuery.of(context).size.width * 0.28,100)))/3,
                            width: ((MediaQuery.of(context).size.height -max((40+min(MediaQuery.of(context).size.width * 0.28,100)),100)) > 3*MediaQuery.of(context).size.width*0.50 )?MediaQuery.of(context).size.width * 0.42:(MediaQuery.of(context).size.height*0.78 -(40+min(MediaQuery.of(context).size.width * 0.28,100)))/3,
                            child: Card(
                              elevation: 3,
                              color:
                                  thm
                                      .cardcolor,
                              child: Column(
                                children: [
                                  SizedBox(height: 10),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: Text(
                                      "Humanity Electives",
                                      textAlign: TextAlign.center,
                                      softWrap: true,
                                      style: TextStyle(
                                        color:
                                            thm
                                                .textcolor,
                                        fontSize: 13,
                                        fontFamily: 'Montserrat',
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Spacer(flex: 4),
                                  Row(
                                    children: [
                                      Text(
                                        "  Courses",
                                        style: TextStyle(
                                          color:
                                              thm
                                                  .textcolor,
                                          fontSize: 13,
                                          fontFamily: 'Montserrat',
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Spacer(flex: 1),
                                      Text(
                                        widget.sitemslist
                                                .where(
                                                  (Course) =>
                                                      Course.elective ==
                                                          Elective.humanity.tag &&
                                                          (Course.grade1 > 0 || Course.grade1==-3),
                                                )
                                                .length
                                                .toString() +
                                            "/3  ",
                                        style: TextStyle(
                                          color:
                                              thm
                                                  .textcolor,
                                          fontSize: 13,
                                          fontFamily: 'Montserrat',
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        "  Credits",
                                        style: TextStyle(
                                          color:
                                              thm
                                                  .textcolor,
                                          fontSize: 13,
                                          fontFamily: 'Montserrat',
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Spacer(flex: 1),
                                      Text(
                                        creds(
                                              Elective.humanity.tag,
                                              widget.sitemslist,
                                            ).toString().replaceAll('.0', '') +
                                            "/8  ",
                                        style: TextStyle(
                                          color:
                                              thm
                                                  .textcolor,
                                          fontSize: 13,
                                          fontFamily: 'Montserrat',
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Spacer(flex: 1),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                if (selecteddiscipline != "----")
                  SizedBox(width: MediaQuery.of(context).size.width * 0.03),
                if (selecteddiscipline != "----")
                  SizedBox(
                    height: ((MediaQuery.of(context).size.height -max((40+min(MediaQuery.of(context).size.width * 0.28,100)),100)) > 3*MediaQuery.of(context).size.width*0.50 )?MediaQuery.of(context).size.width * 0.42:(MediaQuery.of(context).size.height*0.78 -(40+min(MediaQuery.of(context).size.width * 0.28,100)))/3,
                    width: ((MediaQuery.of(context).size.height -max((40+min(MediaQuery.of(context).size.width * 0.28,100)),100)) > 3*MediaQuery.of(context).size.width*0.50 )?MediaQuery.of(context).size.width * 0.42:(MediaQuery.of(context).size.height*0.78 -(40+min(MediaQuery.of(context).size.width * 0.28,100)))/3,
                    child: Stack(
                      children: [
                        Card(
                          elevation: 3,
                          color:
                              thm
                                  .cardcolor,
                          child: Column(
                            children: [
                              SizedBox(height: 10),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  "Open Electives",
                                  textAlign: TextAlign.center,
                                  softWrap: true,
                                  style: TextStyle(
                                    color:
                                        thm
                                            .textcolor,
                                    fontSize: 13,
                                    fontFamily: 'Montserrat',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Spacer(flex: 4),
                              Row(
                                children: [
                                  Text(
                                    "  Courses",
                                    style: TextStyle(
                                      color:
                                          thm
                                              .textcolor,
                                      fontSize: 13,
                                      fontFamily: 'Montserrat',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Spacer(flex: 1),
                                  Text(
                                    widget.sitemslist
                                            .where(
                                              (Course) =>
                                                  Course.elective ==
                                                      Elective.open.tag &&
                                                      (Course.grade1 > 0 || Course.grade1==-3),
                                            )
                                            .length
                                            .toString() + ((selecteddiscipline.startsWith("B"))?"  ":
                                        "/5  "),
                                    style: TextStyle(
                                      color:
                                          thm
                                              .textcolor,
                                      fontSize: 13,
                                      fontFamily: 'Montserrat',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Text(
                                    "  Credits",
                                    style: TextStyle(
                                      color:
                                          thm
                                              .textcolor,
                                      fontSize: 13,
                                      fontFamily: 'Montserrat',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Spacer(flex: 1),
                                  Text(
                                    creds(
                                          Elective.open.tag,
                                          widget.sitemslist,
                                        ).toString().replaceAll('.0', '') + ((selecteddiscipline.startsWith("B"))?"  ":
                                        "/15  "),
                                    style: TextStyle(
                                      color:
                                          thm
                                              .textcolor,
                                      fontSize: 13,
                                      fontFamily: 'Montserrat',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Spacer(flex: 1),
                            ],
                          ),
                        ),
                        if (selecteddiscipline.startsWith("B") &&
                            selecteddiscipline.substring(2).startsWith("A"))
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                color: thm
                                    .backcolor
                                    .withValues(alpha: 0),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                Spacer(flex: 1),
              ],
            ),
          ),

          Spacer(flex: 1),
          Text(
            "Calculation is based on $profile1n grades",
            style: TextStyle(
              color:
                  thm
                      .textcolor,
              fontSize: 13,
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      )),
    );
  }
}
