import 'package:cgpa_calculator/constants.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/mastercourselist.dart';
import 'package:cgpa_calculator/settings.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:marquee/marquee.dart';
import 'dart:math';
import 'script.dart';

class Offshoot extends StatefulWidget {


  const Offshoot({Key? key}) : super(key: key);

  @override
  State<Offshoot> createState() => _OffshootState();
}

double creds(String s, List<Course> si) {
  double sum = 0;
  for (int i = 0; i < si.length; i++) {
    if (si[i].elective == s && (si[i].grade1 > 0 || si[i].grade1 == -3)) {
      sum += si[i].credits;
    }
  }
  return sum;
}

class _OffshootState extends State<Offshoot> {
  var creditsforcourses = {
    'AD': [15, 48, 4, 12], //cdc course,cdc credits, del course,del credits
    'AA': [14, 48, 4, 12],
    'AB': [15, 48, 4, 12],
    'AC': [14, 48, 4, 12],
    'AJ': [14, 48, 4, 12],
    'A1': [15, 45, 5, 15],
    'A2': [17, 57, 4, 12],
    'A3': [15, 49, 4, 12],
    'A4': [19, 56, 4, 12],
    'A5': [16, 48, 4, 12],
    'A7': [14, 48, 4, 12],
    'A8': [14, 48, 4, 12],
    'A9': [13, 43, 5, 15],
    'B1': [14, 44, 5, 15],
    'B2': [12, 37, 5, 15],
    'B3': [14, 42, 6, 18],
    'B4': [14, 42, 5, 15],
    'B5': [15, 45, 4, 15],
    'B7': [15, 45, 5, 15],
    'B-': [0, 0, 0, 0],
  };
  final distBwData = 8.0;
  String currentsorto = "Sort by Grades(Des)";
  bool _isSearched = false;
  bool _isClosing = false;
  bool _isCardOpen = false;
  bool _isrightswipe = false;
  bool _isCourseCardOpen = false;
  bool _isClosingCourse = false;
  bool _isGradeChanged = false;
  int _offshoot = 0;
  double _credits = 0;
  int _courses = 0;
  int selectedprofileo = 1;
  String name1 =
      mcourselist
          .firstWhere(
            (course) => course.id == ("$addcourse $addcourseid"),
            orElse: () => Mastercourselist(id: '', title: '', credits: 0),
          )
          .title;
  double credits1 =
      mcourselist
          .firstWhere(
            (course) => course.id == ("$addcourse $addcourseid"),
            orElse: () => Mastercourselist(id: '', title: '', credits: 0),
          )
          .credits;
  List<Course> get offshootItems =>
      Hive.box<Course>('offshootBox').values.toList();

  @override
  Widget build(BuildContext context) {
    //print(((MediaQuery.of(context).size.height -max((40+min(MediaQuery.of(context).size.width * 0.28,100)),100)) > 3*MediaQuery.of(context).size.width*0.50 )?20:(MediaQuery.of(context).size.height*0.78 -(40+min(MediaQuery.of(context).size.width * 0.28,100)))/3);
    // print(widget.sitemslist.where((Course) => Course.elective == "CDC1" && (Course.grade1 > 0 || Course.grade1==-3),).length.toString());
    // `print`(widget.sitemslist.where((Course) => Course.elective == "CDC2" && (Course.grade1 > 0 || Course.grade1==-3),).length.toString());
    var thm = themes.firstWhere((theme) => theme.theme == selected_theme);
    var wid = MediaQuery.of(context).size.width;
    var hei = MediaQuery.of(context).size.height;
    name1 =
        mcourselist
            .firstWhere(
              (course) => course.id == ("$addcourse $addcourseid"),
              orElse: () => Mastercourselist(id: '', title: '', credits: 0),
            )
            .title;

    credits1 =
        mcourselist
            .firstWhere(
              (course) => course.id == ("$addcourse $addcourseid"),
              orElse: () => Mastercourselist(id: '', title: '', credits: 0),
            )
            .credits;

    List<Course> offshootList = offshootItems.toList();
    sorto(offshootList, currentsorto);
    _offshoot = 0;
    _credits = 0;
    _courses = 0;
    for (var i in offshootList) {
      _offshoot +=
          (selectedprofileo == 1 && (i.grade1 == -3 || i.grade1 > 0))
              ? i.grade1
              : (selectedprofileo == 2 && (i.grade2 == -3 || i.grade2 > 0))
              ? i.grade2
              : 0;
      _credits +=
          (0 !=
                  ((selectedprofileo == 1 && (i.grade1 == -3 || i.grade1 > 0))
                      ? i.grade1
                      : (selectedprofileo == 2 &&
                          (i.grade2 == -3 || i.grade2 > 0))
                      ? i.grade2
                      : 0))
              ? i.credits
              : 0;
      if((selectedprofileo == 1 && (i.grade1 == -3 || i.grade1 > 0))){
        _courses +=1;
      }else if((selectedprofileo == 2 && (i.grade2 == -3 || i.grade2 > 0))){
        _courses +=1;
      }
    }

    setnavcolor();
    return
      Scaffold(
      // appBar: AppBar(
      //   elevation: 0,
      //   //: IconThemeData(color: thm.textcolor),
      //   title: Text(
      //     "Minor Offshoot",
      //     style: TextStyle(
      //       fontFamily: "Montserrat",
      //       fontSize: 20,
      //       color: thm.textcolor,
      //     ),
      //   ),
      //   surfaceTintColor: Colors.transparent,
      //   backgroundColor: thm.backcolor,
      // ),
      backgroundColor: thm.backcolor, //themes[0].backcolor,
          body: SafeArea(
            top: true,    // Only top padding (status bar)
            bottom: false, // No bottom padding (navigation bar)
            left: false,
            right: false,
            child: Stack(
        children: [
          Column(
            children: [
              if(selectedprofileo!=3)
                Row(children: [
                  Padding(padding: EdgeInsets.only(left: 15),child:
                Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Offshoot",textAlign: TextAlign.left, style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 24,
                      fontWeight: FontWeight.normal,
                      color: thm.textcolor,
                    ),),
                    SizedBox(height: distBwData),
                    Text("Credits",textAlign: TextAlign.left, style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 20,
                      fontWeight: FontWeight.normal,
                      color: thm.textcolor,
                    ),),
                    SizedBox(height: distBwData),
                    Text("Courses",textAlign: TextAlign.left, style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 20,
                      fontWeight: FontWeight.normal,
                      color: thm.textcolor,
                    ),),
                  ],
                ),),
                  Padding(padding: EdgeInsets.only(left: 18),child:
                  Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_offshoot.toString(),textAlign: TextAlign.left, style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 24,
                      fontWeight: FontWeight.normal,
                      color: thm.textcolor,
                    ),),
                    SizedBox(height: distBwData),
                    Text(_credits.toString().replaceAll('.0', ''),textAlign: TextAlign.left, style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 20,
                      fontWeight: FontWeight.normal,
                      color: thm.textcolor,
                    ),),
                    SizedBox(height: distBwData),
                    Text(_courses.toString(),textAlign: TextAlign.left, style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 20,
                      fontWeight: FontWeight.normal,
                      color: thm.textcolor,
                    ),),
                  ],
                ),),],),


              if (selectedprofileo != 3)
                Row(
                  children: [
                    SizedBox(width: 5),
                    SizedBox(
                      height: hei * 0.05,
                      width: wid * 0.50,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: thm.bordcolor),
                        ),
                        onPressed: () {
                          setState(() {
                            _isSearched = false;
                            _isCardOpen = true;
                          });
                        },
                        child: Text(
                          "Add Courses",
                          style: TextStyle(
                            color: thm.highcolor,
                            fontSize: 16,
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 2),
                    Spacer(flex: 1),
                    Transform.scale(
                      scale: 1,
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          inputDecorationTheme: InputDecorationTheme(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 8,
                            ),
                            constraints: BoxConstraints.tightFor(
                              height: hei * 0.05,
                            ),
                          ),
                        ),
                        child: DropdownMenu(
                          width: wid * 0.31,
                          onSelected: (value) {
                            setState(() {
                              currentsorto = value!;
                              sorto(offshootList, currentsorto);
                            });
                          },
                          initialSelection: currentsorto,
                          textStyle: TextStyle(
                            fontSize: (selectedprofile != 3) ? 12 : 0,
                            fontWeight: FontWeight.normal,
                            fontFamily: "Montserrat",
                            color: thm.textcolor,
                          ),
                          inputDecorationTheme: InputDecorationTheme(
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: thm.bordcolor,
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: thm.bordcolor,
                                width: 1,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: thm.bordcolor,
                                width: 1,
                              ),
                            ),
                          ),
                          menuStyle: MenuStyle(
                            backgroundColor: WidgetStateProperty.all(
                              thm.backcolor,
                            ),
                          ),
                          dropdownMenuEntries: [
                            DropdownMenuEntry(
                              value: "Sort by Credits(Asc)",
                              enabled: (selectedprofile != 3),
                              leadingIcon: Icon(
                                Icons.keyboard_arrow_down_outlined,
                                color: thm.textcolor,
                              ),
                              label: "Asc Credits",
                              style: MenuItemButton.styleFrom(
                                textStyle: TextStyle(fontFamily: 'Montserrat'),
                                foregroundColor: thm.textcolor,
                              ),
                            ),
                            DropdownMenuEntry(
                              value: "Sort by Credits(Des)",
                              enabled: (selectedprofile != 3),

                              leadingIcon: Icon(
                                Icons.keyboard_arrow_up_outlined,
                                color: thm.textcolor,
                              ),
                              label: "Desc Credits",
                              style: MenuItemButton.styleFrom(
                                textStyle: TextStyle(fontFamily: 'Montserrat'),
                                foregroundColor: thm.textcolor,
                              ),
                            ),
                            DropdownMenuEntry(
                              enabled: (selectedprofile != 3),
                              value: "Sort by Grades(Asc)",

                              leadingIcon: Icon(
                                Icons.keyboard_arrow_down_outlined,
                                color: thm.textcolor,
                              ),
                              label: "Asc Grades",
                              style: MenuItemButton.styleFrom(
                                textStyle: TextStyle(fontFamily: 'Montserrat'),
                                foregroundColor: thm.textcolor,
                              ),
                            ),
                            DropdownMenuEntry(
                              enabled: (selectedprofile != 3),
                              value: "Sort by Grades(Des)",

                              leadingIcon: Icon(
                                Icons.keyboard_arrow_up_outlined,
                                color: thm.textcolor,
                              ),
                              label: "Desc Grades",
                              style: MenuItemButton.styleFrom(
                                textStyle: TextStyle(fontFamily: 'Montserrat'),
                                foregroundColor: thm.textcolor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Transform.scale(
                      scale: 1.4,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: thm.backcolor,
                          shape: CircleBorder(),
                        ),
                        onPressed: () async {
                          final sitemsAsMaps =
                              offshootList
                                  .map(
                                    (course) => {
                                      'credits': course.credits,
                                      'name': course.title,
                                      'grade':
                                          (selectedprofile == 1)
                                              ? course.grade1
                                              : course.grade2,
                                    },
                                  )
                                  .toList();
                          var imgpath = await saveDataAsImage(
                            sitemsAsMaps,
                            semester: currentsem,
                            thisSemCredits: _credits,
                            totalCredits:
                                (selectedprofile == 1) ? ccred1 : ccred2,
                            gpa: _offshoot.toDouble(),
                            cgpa: 0,
                            isOffshoot: true,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                "$imgpath",
                                style: TextStyle(
                                  fontFamily: "Montserrat",
                                  fontWeight: FontWeight.normal,
                                  fontSize: 16,
                                ),
                              ),
                              duration: Duration(seconds: 3),
                            ),
                          );
                        },
                        child: Icon(
                          Icons.save_alt_outlined,
                          color: thm.textcolor,
                        ),
                      ),
                    ),
                  ],
                ),
              if (selectedprofileo == 3)
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        color: thm.cardcolor,
                        margin: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Offshoot",
                                      style: TextStyle(
                                        fontFamily: 'Montserrat',
                                        fontSize: 18,
                                        fontWeight: FontWeight.normal,
                                        color: thm.textcolor,
                                      ),
                                    ),
                                    Text(
                                      "Credits",
                                      style: TextStyle(
                                        fontFamily: 'Montserrat',
                                        fontSize: 16,
                                        fontWeight: FontWeight.normal,
                                        color: thm.textcolor,
                                      ),
                                    ),

                                    Text(
                                      "Courses",
                                      style: TextStyle(
                                        fontFamily: 'Montserrat',
                                        fontSize: 16,
                                        fontWeight: FontWeight.normal,
                                        color: thm.textcolor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: wid * 0.260,
                                //0.229,
                                child: IntrinsicHeight(
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceEvenly,
                                          children: [
                                            Text(
                                              compareOffshoot(offshootList)[0],
                                              style: TextStyle(
                                                fontFamily: "Montserrat",
                                                fontSize: 18,
                                                color: thm.highcolor,
                                              ),
                                            ),
                                            Text(
                                              compareOffshoot(
                                                offshootList,
                                              )[1].replaceAll('.0', ''),
                                              style: TextStyle(
                                                fontFamily: "Montserrat",
                                                fontSize: 16,
                                                color: thm.highcolor,
                                              ),
                                            ),
                                            Text(
                                              compareOffshoot(
                                                offshootList,
                                              )[4].replaceAll('.0', ''),
                                              style: TextStyle(
                                                fontFamily: "Montserrat",
                                                fontSize: 16,
                                                color: thm.highcolor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      FractionallySizedBox(
                                        heightFactor: 0.98,
                                        child: Container(
                                          width: 1,
                                          color: thm.sepcolor,
                                          margin: EdgeInsets.symmetric(
                                            horizontal: 2,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceEvenly,
                                          children: [
                                            Text(
                                              compareOffshoot(offshootList)[2],
                                              style: TextStyle(
                                                fontFamily: "Montserrat",
                                                fontSize: 18,
                                                color: thm.highcolor,
                                              ),
                                            ),
                                            Text(
                                              compareOffshoot(
                                                offshootList,
                                              )[3].replaceAll('.0', ''),
                                              style: TextStyle(
                                                fontFamily: "Montserrat",
                                                fontSize: 16,
                                                color: thm.highcolor,
                                              ),
                                            ),
                                            Text(
                                              compareOffshoot(
                                                offshootList,
                                              )[5].replaceAll('.0', ''),
                                              style: TextStyle(
                                                fontFamily: "Montserrat",
                                                fontSize: 16,
                                                color: thm.highcolor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragEnd: (details) {
                    setState(() {
                      if (details.primaryVelocity! < 0 &&
                          selectedprofileo < 3) {
                        selectedprofileo += 1;
                        _isrightswipe = true;
                      } else if (details.primaryVelocity! > 0 &&
                          selectedprofileo > 1) {
                        selectedprofileo -= 1;
                        _isrightswipe = false;
                      }
                    });
                  },
                  child: AnimatedSwitcher(
                    duration: Duration(milliseconds: 350),
                    transitionBuilder: (
                      Widget child,
                      Animation<double> animation,
                    ) {
                      return SlideTransition(
                        position: Tween<Offset>(
                          begin: Offset(
                            (!_isrightswipe)
                                ? (MediaQuery.of(context).size.width > wid)
                                    ? -0.07
                                    : -1
                                : (MediaQuery.of(context).size.width > wid)
                                ? 0.07
                                : 1,
                            0.0,
                          ),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      );
                    },
                    child: ListView.builder(
                      key: ValueKey(selectedprofileo),
                      padding: EdgeInsets.only(top: 0),
                      itemCount: offshootList.length,
                      itemBuilder: (BuildContext context, int index) {
                        return (selectedprofileo != 4)
                            ? Card(
                              color: thm.cardcolor,
                              margin: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ListTile(
                                title: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Text(
                                    offshootList[index].title,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontFamily: 'Montserrat',
                                      fontWeight: FontWeight.normal,
                                      color: thm.textcolor,
                                    ),
                                  ),
                                ),
                                subtitle: Text(
                                  offshootList[index].id,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'Montserrat',
                                    fontWeight: FontWeight.normal,
                                    color: thm.textcolor,
                                  ),
                                ),
                                leading:
                                    (selectedprofileo != 3)
                                        ? Stack(
                                          children: [
                                            SizedBox(
                                              width: wid * 0.13,
                                              child: Container(
                                                color: Colors.transparent,
                                                child: Row(
                                                  children: [
                                                    Column(
                                                      children: [
                                                        Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .center,
                                                          children: [
                                                            Text(
                                                              offshootList[index]
                                                                  .credits
                                                                  .toString()
                                                                  .replaceAll(
                                                                    '.0',
                                                                    '',
                                                                  ),
                                                              style: TextStyle(
                                                                fontSize: 21.5,
                                                                fontFamily:
                                                                    'Montserrat',
                                                                color:
                                                                    thm.textcolor,
                                                              ),
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                            ),
                                                          ],
                                                        ),
                                                        Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .center,
                                                          children: [
                                                            Text(
                                                              "Credit",
                                                              style: TextStyle(
                                                                fontFamily:
                                                                    'Montserrat',
                                                                color:
                                                                    thm.textcolor,
                                                                fontSize: 12,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            Padding(
                                              padding: EdgeInsets.only(
                                                left: wid * 0.132,
                                              ),
                                              child: Container(
                                                width: 1,
                                                height: 60,
                                                color: thm.sepcolor,
                                              ),
                                            ),
                                          ],
                                        )
                                        : null,
                                trailing:
                                    (selectedprofileo != 3)
                                        ? Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Padding(
                                              padding: EdgeInsets.only(
                                                right: wid * (0.120),
                                              ),
                                              child: Container(
                                                width: 1,
                                                height: 60,
                                                color: thm.sepcolor,
                                              ),
                                            ),
                                            Padding(
                                              padding: EdgeInsets.only(
                                                left: wid * 0.035,
                                              ),
                                              child: Text(
                                                (selectedprofileo == 1)
                                                    ? gradecalc(
                                                      offshootList[index]
                                                          .grade1,
                                                    )
                                                    : (selectedprofileo == 2)
                                                    ? gradecalc(
                                                      offshootList[index]
                                                          .grade2,
                                                    )
                                                    : "-3",
                                                style: TextStyle(
                                                  fontSize:
                                                      (gradecalc(
                                                                (selectedprofileo ==
                                                                        1)
                                                                    ? offshootList[index]
                                                                        .grade1
                                                                    : (selectedprofileo ==
                                                                        2)
                                                                    ? offshootList[index]
                                                                        .grade2
                                                                    : -3,
                                                              ) ==
                                                              "CLR")
                                                          ? 16
                                                          : (gradecalc(
                                                                    (selectedprofileo ==
                                                                            1)
                                                                        ? offshootList[index]
                                                                            .grade1
                                                                        : (selectedprofileo ==
                                                                            2)
                                                                        ? offshootList[index]
                                                                            .grade2
                                                                        : -3,
                                                                  ) ==
                                                                  "NC" ||
                                                              gradecalc(
                                                                    (selectedprofileo ==
                                                                            1)
                                                                        ? offshootList[index]
                                                                            .grade1
                                                                        : (selectedprofileo ==
                                                                            2)
                                                                        ? offshootList[index]
                                                                            .grade2
                                                                        : -3,
                                                                  ) ==
                                                                  "GD")
                                                          ? 18
                                                          : 20,
                                                  fontFamily: "Montserrat",
                                                  fontWeight: FontWeight.bold,
                                                  color: thm.highcolor,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ],
                                        )
                                        : SizedBox(
                                          width: wid * 0.220,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              SizedBox(
                                                width: wid * 0.0945,
                                                child: Text(
                                                  (((offshootList[index].grade1 >
                                                                      0)
                                                                  ? gradecalc(
                                                                    offshootList[index]
                                                                        .grade1,
                                                                  )
                                                                  : "–")
                                                              .length) ==
                                                          2
                                                      ? (offshootList[index]
                                                                  .grade1 >
                                                              0)
                                                          ? gradecalc(
                                                            offshootList[index]
                                                                .grade1,
                                                          )
                                                          : "–" + "‎ "
                                                      : ((offshootList[index]
                                                                      .grade1 >
                                                                  0)
                                                              ? gradecalc(
                                                                offshootList[index]
                                                                    .grade1,
                                                              )
                                                              : "–") +
                                                          "‎ ‎ ",

                                                  textAlign: TextAlign.right,
                                                  style: TextStyle(
                                                    fontSize: 20,
                                                    fontFamily: 'Montserrat',
                                                    color: thm.highcolor,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                width: 1,
                                                height: 60,
                                                color: thm.sepcolor,
                                                margin: EdgeInsets.symmetric(
                                                  horizontal: 5,
                                                ),
                                              ),
                                              SizedBox(
                                                width: wid * 0.0945,
                                                child: Text(
                                                  "‎" +
                                                      ((offshootList[index]
                                                                  .grade2 >
                                                              0)
                                                          ? gradecalc(
                                                            offshootList[index]
                                                                .grade2,
                                                          )
                                                          : "–"),
                                                  textAlign: TextAlign.left,
                                                  style: TextStyle(
                                                    fontSize: 20,
                                                    fontFamily: 'Montserrat',
                                                    color: thm.highcolor,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                onTap: () {
                                  setState(() {
                                    if (selectedprofileo != 3) {
                                      tapid = index;
                                      addcourse =
                                          offshootList[index].id.split(" ")[0];
                                      addcourseid =
                                          offshootList[index].id.split(" ")[1];
                                      _isCourseCardOpen = true;
                                    }
                                  });
                                },
                              ),
                            )
                            : Padding(
                              padding: EdgeInsets.only(left: 15, right: 15),
                              child: Table(
                                columnWidths: const <int, TableColumnWidth>{
                                  0: FlexColumnWidth(),
                                  1: FractionColumnWidth(0.13),
                                  2: FractionColumnWidth(0.13),
                                },
                                border: TableBorder.all(color: thm.textcolor),
                                children: [
                                  TableRow(
                                    children: [
                                      Text(
                                        offshootList[index].title,
                                        style: TextStyle(
                                          fontFamily: 'Montserrat',
                                          fontSize: 20,
                                          fontWeight: FontWeight.normal,
                                        ),
                                      ),
                                      Text(
                                        gradecalc(offshootList[index].grade1),
                                        style: TextStyle(
                                          fontFamily: 'Montserrat',
                                          fontSize: 20,
                                          fontWeight: FontWeight.normal,
                                        ),
                                      ),
                                      Text(
                                        gradecalc(offshootList[index].grade2),
                                        style: TextStyle(
                                          fontFamily: 'Montserrat',
                                          fontSize: 20,
                                          fontWeight: FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          AnimatedSwitcher(
            duration: Duration(milliseconds: 400),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            child:
                _isCardOpen
                    ? Stack(
                      children: [
                        AnimatedOpacity(
                          opacity: _isClosing ? 0.0 : 0.6,
                          duration: Duration(milliseconds: 500),
                          child: GestureDetector(
                            onTap: () async {
                              setState(() {
                                addcourse = "AN";
                                addcourseid = "F311";
                                //electiveSetter();
                                dropdownid =
                                    mcourselist
                                        .where(
                                          (course) =>
                                              course.id.startsWith("AN" + ' '),
                                        )
                                        .map(
                                          (course) => course.id.replaceFirst(
                                            "AN" + ' ',
                                            '',
                                          ),
                                        )
                                        .toList();
                                dropdownid.sort((a, b) => a.compareTo(b));
                                _isClosing = true;
                              });
                              Future.delayed(Duration(milliseconds: 500));
                              setState(() {
                                _isClosing = false;
                                _isCardOpen = false;
                              });
                            },
                            child: Container(
                              color: thm.backcolor,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
                        ),
                        Center(
                          child: AnimatedScale(
                            scale: _isClosing ? 0 : 1.0,
                            duration: Duration(milliseconds: 100),
                            curve: Curves.easeOut,
                            child: Card(
                              key: ValueKey('open'),
                              color: thm.backcolor,
                              elevation: 40,
                              margin: EdgeInsets.all(16),
                              shape: RoundedRectangleBorder(
                                side: BorderSide(
                                  color: thm.textcolor,
                                  width: 2.0,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(wid * 0.025),
                                child: SizedBox(
                                  height: hei * 0.50,
                                  width: wid * 0.85,
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          SizedBox(
                                            width: wid * 0.34,
                                            child: DropdownMenu(
                                              initialSelection:
                                                  (_isSearched)
                                                      ? addcourse
                                                      : "AN",
                                              textStyle: TextStyle(
                                                fontFamily: 'Montserrat',
                                                fontSize: 15,
                                                fontWeight: FontWeight.normal,
                                                color: thm.textcolor,
                                              ),
                                              onSelected: (value) {
                                                setState(() {
                                                  addcourse = value!;
                                                  //electiveSetter();
                                                  dropdownid =
                                                      mcourselist
                                                          .where(
                                                            (course) => course
                                                                .id
                                                                .startsWith(
                                                                  '$value ',
                                                                ),
                                                          )
                                                          .map(
                                                            (course) => course
                                                                .id
                                                                .replaceFirst(
                                                                  '$value ',
                                                                  '',
                                                                ),
                                                          )
                                                          .toList();
                                                  dropdownid.sort(
                                                    (a, b) => a.compareTo(b),
                                                  );
                                                  addcourseid = dropdownid[0];
                                                  //electiveSetter();
                                                });
                                              },
                                              inputDecorationTheme:
                                                  InputDecorationTheme(
                                                    enabledBorder:
                                                        OutlineInputBorder(
                                                          borderSide: BorderSide(
                                                            color:
                                                                thm.bordcolor,
                                                            width: 1,
                                                          ),
                                                        ),
                                                    focusedBorder:
                                                        OutlineInputBorder(
                                                          borderSide: BorderSide(
                                                            color:
                                                                thm.bordcolor,
                                                            width: 1,
                                                          ),
                                                        ),
                                                    border: OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color: thm.bordcolor,
                                                        width: 1,
                                                      ),
                                                    ),
                                                  ),
                                              menuStyle: MenuStyle(
                                                backgroundColor:
                                                    WidgetStateProperty.all(
                                                      thm.backcolor,
                                                    ),
                                              ),
                                              dropdownMenuEntries:
                                                  depts
                                                      .map(
                                                        (
                                                          id,
                                                        ) => DropdownMenuEntry(
                                                          value: id,
                                                          label: id,
                                                          style: MenuItemButton.styleFrom(
                                                            textStyle: TextStyle(
                                                              fontFamily:
                                                                  'Montserrat',
                                                            ),
                                                            foregroundColor:
                                                                thm.textcolor,
                                                          ),
                                                        ),
                                                      )
                                                      .toList(),
                                            ),
                                          ),
                                          Spacer(flex: 1),
                                          SizedBox(
                                            width: wid * 0.27,
                                            child: DropdownMenu(
                                              initialSelection:
                                                  (_isSearched)
                                                      ? addcourseid
                                                      : dropdownid[0],
                                              textStyle: TextStyle(
                                                fontFamily: 'Montserrat',
                                                fontSize: 15,
                                                fontWeight: FontWeight.normal,
                                                color: thm.textcolor,
                                              ),
                                              onSelected: (value) {
                                                setState(() {
                                                  addcourseid = value!;
                                                  // electiveSetter();
                                                });
                                              },
                                              inputDecorationTheme:
                                                  InputDecorationTheme(
                                                    enabledBorder:
                                                        OutlineInputBorder(
                                                          borderSide: BorderSide(
                                                            color:
                                                                thm.bordcolor,
                                                            width: 1,
                                                          ),
                                                        ),
                                                    focusedBorder:
                                                        OutlineInputBorder(
                                                          borderSide: BorderSide(
                                                            color:
                                                                thm.bordcolor,
                                                            width: 1,
                                                          ),
                                                        ),
                                                    border: OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color: thm.bordcolor,
                                                        width: 1,
                                                      ),
                                                    ),
                                                  ),
                                              menuStyle: MenuStyle(
                                                backgroundColor:
                                                    WidgetStateProperty.all(
                                                      thm.backcolor,
                                                    ),
                                              ),

                                              dropdownMenuEntries:
                                                  dropdownid
                                                      .map(
                                                        (
                                                          id,
                                                        ) => DropdownMenuEntry(
                                                          value: id,
                                                          label: id,
                                                          style: MenuItemButton.styleFrom(
                                                            textStyle: TextStyle(
                                                              fontFamily:
                                                                  'Montserrat',
                                                            ),
                                                            foregroundColor:
                                                                thm.textcolor,
                                                          ),
                                                        ),
                                                      )
                                                      .toList(),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Spacer(flex: 1),
                                      Theme(
                                        data: Theme.of(context).copyWith(
                                          iconTheme: IconThemeData(
                                            color: thm.textcolor,
                                          ),
                                        ),
                                        child: Theme(
                                          data: Theme.of(context).copyWith(
                                            inputDecorationTheme:
                                                InputDecorationTheme(
                                                  labelStyle: TextStyle(
                                                    fontFamily: "Montserrat",
                                                    color: thm.textcolor,
                                                  ),
                                                  hintStyle: TextStyle(
                                                    fontFamily: 'Montserrat',
                                                    color: thm.textcolor,
                                                  ),
                                                  border: InputBorder.none,
                                                  focusedBorder:
                                                      InputBorder.none,
                                                  enabledBorder:
                                                      InputBorder.none,
                                                ),
                                            textSelectionTheme:
                                                TextSelectionThemeData(
                                                  cursorColor: thm.textcolor,
                                                  selectionColor: thm.textcolor,
                                                  selectionHandleColor:
                                                      thm.textcolor,
                                                ),
                                          ),
                                          child: SizedBox(
                                            width: wid * 0.8,
                                            child: SearchAnchor.bar(
                                              barSide: WidgetStatePropertyAll(
                                                BorderSide(
                                                  color: thm.bordcolor,
                                                  width: 1,
                                                ),
                                              ),
                                              barElevation:
                                                  WidgetStateProperty.all(0),
                                              viewConstraints: BoxConstraints(
                                                minHeight: 0,
                                                maxHeight: hei * 0.3,
                                              ),
                                              barTextStyle:
                                                  WidgetStateProperty.resolveWith(
                                                    (states) {
                                                      if (states.contains(
                                                        WidgetState.focused,
                                                      ))
                                                        return TextStyle(
                                                          fontFamily:
                                                              "Montserrat",
                                                          color: thm.textcolor,
                                                        );
                                                      return TextStyle(
                                                        fontFamily:
                                                            "Montserrat",
                                                        color: thm.textcolor,
                                                      );
                                                    },
                                                  ),
                                              barBackgroundColor:
                                                  WidgetStateProperty.all(
                                                    thm.backcolor,
                                                  ),
                                              viewBackgroundColor:
                                                  (selected_theme == "Black")
                                                      ? Color(0xFF3F3C3C)
                                                      : (selected_theme ==
                                                          "Blue")
                                                      ? Color(0xFF2E2E50)
                                                      : thm.backcolor,
                                              barHintText: 'Search Courses',
                                              barHintStyle:
                                                  WidgetStateProperty.all(
                                                    TextStyle(
                                                      color: thm.textcolor,
                                                      fontFamily: 'Montserrat',
                                                    ),
                                                  ),
                                              suggestionsBuilder: (
                                                context,
                                                controller,
                                              ) {
                                                final query =
                                                    controller.text
                                                        .toLowerCase();
                                                final results =
                                                    mcourselist
                                                        .map((course) => course)
                                                        .toList()
                                                        .where(
                                                          (item) => item.title
                                                              .toLowerCase()
                                                              .contains(query),
                                                        )
                                                        .toList();
                                                return results.map(
                                                  (item) => ListTile(
                                                    title: Text(
                                                      item.title +
                                                          " (" +
                                                          item.id +
                                                          ")",
                                                      style: TextStyle(
                                                        fontFamily:
                                                            "Montserrat",
                                                        color: thm.textcolor,
                                                      ),
                                                    ),
                                                    onTap: () {
                                                      setState(() {
                                                        _isSearched = true;
                                                        addcourse =
                                                            item.id.split(
                                                              " ",
                                                            )[0];
                                                        //electiveSetter();
                                                        dropdownid =
                                                            mcourselist
                                                                .where(
                                                                  (
                                                                    course,
                                                                  ) => course.id
                                                                      .startsWith(
                                                                        addcourse +
                                                                            ' ',
                                                                      ),
                                                                )
                                                                .map(
                                                                  (
                                                                    course,
                                                                  ) => course.id
                                                                      .replaceFirst(
                                                                        addcourse +
                                                                            ' ',
                                                                        '',
                                                                      ),
                                                                )
                                                                .toList();
                                                        dropdownid.sort(
                                                          (a, b) =>
                                                              a.compareTo(b),
                                                        );
                                                        addcourseid =
                                                            item.id.split(
                                                              " ",
                                                            )[1];
                                                        //electiveSetter();
                                                      });
                                                      controller.closeView(
                                                        item.title,
                                                      );
                                                    },
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                      Spacer(flex: 1),
                                      Row(
                                        children: [
                                          SizedBox(height: hei * 0.1),
                                          Container(
                                            padding: EdgeInsets.only(right: 0),
                                            height: hei * 0.08,
                                            width: wid * 0.62,
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: thm.bordcolor,
                                                width: 1.0,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),

                                            child: Center(
                                              child: Marquee(
                                                text: "  $name1  ",
                                                scrollAxis: Axis.horizontal,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                blankSpace: 10,
                                                velocity: 30,
                                                startPadding: 2.0,

                                                style: TextStyle(
                                                  fontWeight: FontWeight.normal,
                                                  fontFamily: 'Montserrat',
                                                  fontSize: 21,
                                                  color: thm.textcolor,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Spacer(flex: 1),
                                          Container(
                                            height: hei * 0.08,
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: thm.bordcolor,
                                                width: 1.0,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Center(
                                              child: Text(
                                                "    $credits1    ".replaceAll(
                                                  '.0',
                                                  '',
                                                ),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.normal,
                                                  fontFamily: 'Montserrat',
                                                  fontSize: 22,
                                                  color: thm.textcolor,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Spacer(flex: 1),
                                        ],
                                      ),
                                      Spacer(flex: 1),
                                      Row(
                                        children: [
                                          SizedBox(
                                            width: wid * 0.57,
                                            child: Theme(
                                              data: Theme.of(context).copyWith(
                                                inputDecorationTheme:
                                                    InputDecorationTheme(
                                                      isDense: true,
                                                      contentPadding:
                                                          EdgeInsets.symmetric(
                                                            vertical: 8,
                                                            horizontal: 8,
                                                          ),
                                                      constraints:
                                                          BoxConstraints.tightFor(
                                                            height: hei * 0.07,
                                                          ),
                                                    ),
                                              ),
                                              child: DropdownMenu(
                                                textStyle: TextStyle(
                                                  fontSize: 18,
                                                  fontFamily: 'Montserrat',
                                                  fontWeight: FontWeight.normal,
                                                  color: thm.textcolor,
                                                ),
                                                initialSelection:
                                                    (selectedelective == "None")
                                                        ? "CDCN"
                                                        : selectedelective,
                                                inputDecorationTheme:
                                                    InputDecorationTheme(
                                                      enabledBorder:
                                                          OutlineInputBorder(
                                                            borderSide: BorderSide(
                                                              color:
                                                                  thm.bordcolor,
                                                              width: 1,
                                                            ),
                                                          ),
                                                      focusedBorder:
                                                          OutlineInputBorder(
                                                            borderSide: BorderSide(
                                                              color:
                                                                  thm.bordcolor,
                                                              width: 1,
                                                            ),
                                                          ),
                                                      border: OutlineInputBorder(
                                                        borderSide: BorderSide(
                                                          color: thm.bordcolor,
                                                          width: 1,
                                                        ),
                                                      ),
                                                    ),
                                                menuStyle: MenuStyle(
                                                  backgroundColor:
                                                      WidgetStateProperty.all(
                                                        thm.backcolor,
                                                      ),
                                                ),
                                                dropdownMenuEntries: [
                                                  DropdownMenuEntry(
                                                    value: "CDCN",
                                                    label: "None",
                                                    style:
                                                        MenuItemButton.styleFrom(
                                                          textStyle: TextStyle(
                                                            fontFamily:
                                                                'Montserrat',
                                                          ),
                                                          foregroundColor:
                                                              thm.textcolor,
                                                        ),
                                                  ),
                                                  DropdownMenuEntry(
                                                    value: "CDC2",
                                                    label:
                                                        "CDC (" +
                                                        selecteddiscipline
                                                            .substring(2, 4) +
                                                        ")",
                                                    style:
                                                        MenuItemButton.styleFrom(
                                                          textStyle: TextStyle(
                                                            fontFamily:
                                                                'Montserrat',
                                                          ),
                                                          foregroundColor:
                                                              thm.textcolor,
                                                        ),
                                                  ),
                                                  DropdownMenuEntry(
                                                    value: "Open Elective",
                                                    label: "Open Elective",
                                                    style:
                                                        MenuItemButton.styleFrom(
                                                          textStyle: TextStyle(
                                                            fontFamily:
                                                                'Montserrat',
                                                          ),
                                                          foregroundColor:
                                                              thm.textcolor,
                                                        ),
                                                  ),
                                                  DropdownMenuEntry(
                                                    value: "Humanity Elective",
                                                    label: "Humanity Elective",
                                                    style:
                                                        MenuItemButton.styleFrom(
                                                          textStyle: TextStyle(
                                                            fontFamily:
                                                                'Montserrat',
                                                          ),
                                                          foregroundColor:
                                                              thm.textcolor,
                                                        ),
                                                  ),
                                                  DropdownMenuEntry(
                                                    value:
                                                        "Disciplinary Elective2",
                                                    label:
                                                        "Disciplinary Elective (" +
                                                        selecteddiscipline
                                                            .substring(2, 4) +
                                                        ")",
                                                    style:
                                                        MenuItemButton.styleFrom(
                                                          textStyle: TextStyle(
                                                            fontFamily:
                                                                'Montserrat',
                                                          ),
                                                          foregroundColor:
                                                              thm.textcolor,
                                                        ),
                                                  ),
                                                  if (selecteddiscipline
                                                      .startsWith("B"))
                                                    DropdownMenuEntry(
                                                      value: "CDC1",
                                                      label:
                                                          "CDC (" +
                                                          selecteddiscipline
                                                              .substring(0, 2) +
                                                          ")",
                                                      style:
                                                          MenuItemButton.styleFrom(
                                                            textStyle: TextStyle(
                                                              fontFamily:
                                                                  'Montserrat',
                                                            ),
                                                            foregroundColor:
                                                                thm.textcolor,
                                                          ),
                                                    ),
                                                  if (selecteddiscipline
                                                      .startsWith("B"))
                                                    DropdownMenuEntry(
                                                      value:
                                                          "Disciplinary Elective1",
                                                      label:
                                                          "Disciplinary Elective (" +
                                                          selecteddiscipline
                                                              .substring(0, 2) +
                                                          ")",
                                                      style:
                                                          MenuItemButton.styleFrom(
                                                            textStyle: TextStyle(
                                                              fontFamily:
                                                                  'Montserrat',
                                                            ),
                                                            foregroundColor:
                                                                thm.textcolor,
                                                          ),
                                                    ),
                                                ],
                                                onSelected: (value) {
                                                  selectedelective = value!;
                                                },
                                              ),
                                            ),
                                          ),
                                          Spacer(flex: 1),
                                          SizedBox(
                                            width: wid * 0.26,
                                            child: Theme(
                                              data: Theme.of(context).copyWith(
                                                inputDecorationTheme:
                                                    InputDecorationTheme(
                                                      isDense: true,
                                                      contentPadding:
                                                          EdgeInsets.symmetric(
                                                            vertical: 8,
                                                            horizontal: 8,
                                                          ),
                                                      constraints:
                                                          BoxConstraints.tightFor(
                                                            height: hei * 0.07,
                                                          ),
                                                    ),
                                              ),
                                              child: DropdownMenu(
                                                textStyle: TextStyle(
                                                  fontSize: 20,
                                                  fontFamily: 'Montserrat',
                                                  fontWeight: FontWeight.normal,
                                                  color: thm.textcolor,
                                                ),
                                                initialSelection: "A",
                                                inputDecorationTheme:
                                                    InputDecorationTheme(
                                                      enabledBorder:
                                                          OutlineInputBorder(
                                                            borderSide: BorderSide(
                                                              color:
                                                                  thm.bordcolor,
                                                              width: 1,
                                                            ),
                                                          ),
                                                      focusedBorder:
                                                          OutlineInputBorder(
                                                            borderSide: BorderSide(
                                                              color:
                                                                  thm.bordcolor,
                                                              width: 1,
                                                            ),
                                                          ),
                                                      border: OutlineInputBorder(
                                                        borderSide: BorderSide(
                                                          color: thm.bordcolor,
                                                          width: 1,
                                                        ),
                                                      ),
                                                    ),
                                                menuStyle: MenuStyle(
                                                  backgroundColor:
                                                      WidgetStateProperty.all(
                                                        thm.backcolor,
                                                      ),
                                                ),
                                                dropdownMenuEntries:
                                                    grades
                                                        .map(
                                                          (
                                                            id,
                                                          ) => DropdownMenuEntry(
                                                            value: id,
                                                            label: id,
                                                            style: MenuItemButton.styleFrom(
                                                              textStyle: TextStyle(
                                                                fontFamily:
                                                                    'Montserrat',
                                                              ),
                                                              foregroundColor:
                                                                  thm.textcolor,
                                                            ),
                                                          ),
                                                        )
                                                        .toList(),
                                                onSelected: (value) {
                                                  selectedgrade =
                                                      reversegradecalc(value!);
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Spacer(flex: 1),
                                      Row(
                                        children: [
                                          Spacer(flex: 1),
                                          SizedBox(
                                            height: hei * 0.08,
                                            width: wid * 0.8,
                                            child: FloatingActionButton(
                                              backgroundColor: thm.butcolor,
                                              child: Text(
                                                "Add Course",
                                                style: TextStyle(
                                                  fontFamily: 'Montserrat',
                                                  fontWeight: FontWeight.normal,
                                                  fontSize: 22,
                                                  color: thm.highcolor,
                                                ),
                                              ),
                                              onPressed: () {
                                                _isSearched = false;
                                                setState(() {
                                                  if (offshootList.any(
                                                    (course) =>
                                                        course.id ==
                                                        "$addcourse $addcourseid",
                                                  )) {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          style: TextStyle(
                                                            fontFamily:
                                                                "Montserrat",
                                                            fontWeight:
                                                                FontWeight
                                                                    .normal,
                                                            fontSize: 16,
                                                          ),
                                                          "This course already exists",
                                                        ),
                                                        duration: Duration(
                                                          seconds: 3,
                                                        ),
                                                      ),
                                                    );
                                                  } else {
                                                    Mastercourselist?
                                                    tempcourse = mcourselist
                                                        .lastWhere(
                                                          (course) =>
                                                              course.id ==
                                                              "$addcourse $addcourseid",
                                                        );
                                                    if (selectedprofileo == 1) {
                                                      addOrUpdateCourseOffshoot(
                                                        Course(
                                                          elective:
                                                              selectedelective,
                                                          title:
                                                              tempcourse.title,
                                                          sem: currentsem,
                                                          id:
                                                              "$addcourse $addcourseid",
                                                          discipline:
                                                              ((selecteddiscipline
                                                                          .substring(
                                                                            0,
                                                                            2,
                                                                          ) !=
                                                                      "--")
                                                                  ? selecteddiscipline
                                                                      .substring(
                                                                        0,
                                                                        2,
                                                                      )
                                                                  : selecteddiscipline
                                                                      .substring(
                                                                        2,
                                                                        4,
                                                                      )),
                                                          grade1: selectedgrade,
                                                          grade2: -2,
                                                          credits:
                                                              tempcourse
                                                                  .credits,
                                                        ),
                                                      );
                                                      selectedelective = "None";
                                                    } else if (selectedprofileo ==
                                                        2) {
                                                      addOrUpdateCourseOffshoot(
                                                        Course(
                                                          elective:
                                                              selectedelective,
                                                          title:
                                                              tempcourse.title,
                                                          sem: currentsem,
                                                          id:
                                                              "$addcourse $addcourseid",
                                                          discipline:
                                                              ((selecteddiscipline
                                                                          .substring(
                                                                            0,
                                                                            2,
                                                                          ) !=
                                                                      "--")
                                                                  ? selecteddiscipline
                                                                      .substring(
                                                                        0,
                                                                        2,
                                                                      )
                                                                  : selecteddiscipline
                                                                      .substring(
                                                                        2,
                                                                        4,
                                                                      )),
                                                          grade1: -2,
                                                          grade2: selectedgrade,
                                                          credits:
                                                              tempcourse
                                                                  .credits,
                                                        ),
                                                      );
                                                      selectedelective = "None";
                                                    }
                                                    selectedgrade = 10;
                                                    //currentsem = currentsem;
                                                    selecteddiscipline =
                                                        selecteddiscipline;
                                                    batch = batch;
                                                    addcourse = "AN";
                                                    addcourseid = "F311";
                                                    //electiveSetter();
                                                    dropdownid =
                                                        mcourselist
                                                            .where(
                                                              (course) => course
                                                                  .id
                                                                  .startsWith(
                                                                    "AN" + ' ',
                                                                  ),
                                                            )
                                                            .map(
                                                              (course) => course
                                                                  .id
                                                                  .replaceFirst(
                                                                    "AN" + ' ',
                                                                    '',
                                                                  ),
                                                            )
                                                            .toList();
                                                    dropdownid.sort(
                                                      (a, b) => a.compareTo(b),
                                                    );
                                                    //sort(sitems);
                                                  }
                                                });
                                                setState(() {
                                                  _isClosing =
                                                      true; // Start close animation
                                                });
                                                Future.delayed(
                                                  const Duration(
                                                    milliseconds: 500,
                                                  ),
                                                  () {
                                                    if (!mounted) return;
                                                    setState(() {
                                                      _isCardOpen = false;
                                                      _isClosing = false;
                                                    });
                                                  },
                                                );
                                              },
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
                          ),
                        ),
                      ],
                    )
                    : SizedBox.shrink(key: ValueKey('closed')),
          ),
          AnimatedSwitcher(
            duration: Duration(milliseconds: 400),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            child:
            _isCourseCardOpen
                ? Stack(
              children: [
                AnimatedOpacity(
                  opacity: !_isClosingCourse ? 0.6 : 0.0,
                  duration: Duration(milliseconds: 100),
                  child: GestureDetector(
                    onTap: () async {
                      setState(() {
                        addcourse = "AN";
                        addcourseid = "F311";
                        //electiveSetter();
                        dropdownid =
                            mcourselist
                                .where(
                                  (course) => course.id.startsWith(
                                "AN" + ' ',
                              ),
                            )
                                .map(
                                  (course) => course.id.replaceFirst(
                                "AN" + ' ',
                                '',
                              ),
                            )
                                .toList();
                        dropdownid.sort((a, b) => a.compareTo(b));
                        _isClosingCourse = true;
                      });
                      Future.delayed(Duration(milliseconds: 100));
                      setState(() {
                        _isCourseCardOpen = false;
                        _isClosingCourse = false;
                      });
                    },
                    child: Container(
                      color: thm.backcolor,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                ),
                Center(
                  child: AnimatedScale(
                    scale: _isCourseCardOpen ? 1.0 : 0.8,
                    duration: Duration(milliseconds: 500),
                    curve: Curves.easeOutBack,
                    child: Card(
                      key: ValueKey("open"),
                      color: thm.cardcolor,
                      elevation: 40,
                      margin: EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          color: thm.textcolor,
                          width: 2.0,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: SizedBox(
                          height: hei * 0.44,
                          width: wid * 0.85,
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Spacer(flex: 1),
                                  Text(
                                    "${offshootList[tapid].id.split(" ")[0]} ",
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.normal,
                                      fontFamily: 'Montserrat',
                                      color: thm.textcolor,
                                    ),
                                  ),
                                  Text(
                                    offshootList[tapid].id.split(" ")[1],
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.normal,
                                      fontFamily: 'Montserrat',
                                      color: thm.textcolor,
                                    ),
                                  ),
                                  Spacer(flex: 1),
                                ],
                              ),
                              Row(
                                mainAxisAlignment:
                                MainAxisAlignment.center,
                                children: [
                                  Text(
                                    electiveFinder(
                                      offshootList[tapid].elective,
                                    ),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.normal,
                                      fontFamily: 'Montserrat',
                                      color: thm.textcolor,
                                    ),
                                  ),
                                ],
                              ),
                              Spacer(flex: 1),
                              Row(
                                children: [
                                  Spacer(flex: 1),
                                  SizedBox(height: hei * 0.1),
                                  Container(
                                    margin: EdgeInsets.only(right: 0),
                                    height: hei * 0.08,
                                    width: wid * 0.8,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: thm.bordcolor,
                                        width: 1.0,
                                      ),
                                      borderRadius:
                                      BorderRadius.circular(8),
                                    ),

                                    child: Center(
                                      child: Marquee(
                                        text: "  $name1  ",
                                        scrollAxis: Axis.horizontal,
                                        crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                        blankSpace: 10,
                                        velocity: 30,
                                        startPadding: 2.0,

                                        style: TextStyle(
                                          fontWeight:
                                          FontWeight.normal,
                                          fontFamily: 'Montserrat',
                                          fontSize: 22,
                                          color: thm.textcolor,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Spacer(flex: 1),
                                ],
                              ),
                              Spacer(flex: 1),
                              Row(
                                children: [
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: wid * 0.025,
                                    ),
                                    child: SizedBox(
                                      width: wid * 0.79,
                                      child: Row(
                                        children: [
                                          Container(
                                            height: hei * 0.08,
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: thm.bordcolor,
                                                width: 1.0,
                                              ),
                                              borderRadius:
                                              BorderRadius.circular(
                                                8,
                                              ),
                                            ),
                                            child: Center(
                                              child: Text(
                                                "    $credits1    "
                                                    .replaceAll(
                                                  '.0',
                                                  '',
                                                ),
                                                style: TextStyle(
                                                  fontWeight:
                                                  FontWeight
                                                      .normal,
                                                  fontFamily:
                                                  'Montserrat',
                                                  fontSize: 22,
                                                  color:
                                                  thm.textcolor,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Spacer(flex: 1),
                                          Theme(
                                            data: Theme.of(
                                              context,
                                            ).copyWith(
                                              inputDecorationTheme:
                                              InputDecorationTheme(
                                                isDense: true,
                                                contentPadding:
                                                EdgeInsets.symmetric(
                                                  vertical: 8,
                                                  horizontal:
                                                  8,
                                                ),
                                                constraints:
                                                BoxConstraints.tightFor(
                                                  height:
                                                  double
                                                      .infinity,
                                                ),
                                              ),
                                            ),
                                            child: DropdownMenu(
                                              textStyle: TextStyle(
                                                fontSize: 20,
                                                fontFamily:
                                                'Montserrat',
                                                fontWeight:
                                                FontWeight.normal,
                                                color: thm.textcolor,
                                              ),
                                              initialSelection: gradecalc(
                                                (selectedprofileo == 1)
                                                    ? offshootList[tapid]
                                                    .grade1
                                                    : (selectedprofileo ==
                                                    2)
                                                    ? offshootList[tapid]
                                                    .grade2
                                                    : -3,
                                              ),
                                              inputDecorationTheme: InputDecorationTheme(
                                                enabledBorder:
                                                OutlineInputBorder(
                                                  borderSide:
                                                  BorderSide(
                                                    color:
                                                    thm.bordcolor,
                                                    width: 1,
                                                  ),
                                                ),
                                                focusedBorder:
                                                OutlineInputBorder(
                                                  borderSide:
                                                  BorderSide(
                                                    color:
                                                    thm.bordcolor,
                                                    width: 1,
                                                  ),
                                                ),
                                                border: OutlineInputBorder(
                                                  borderSide: BorderSide(
                                                    color:
                                                    thm.bordcolor,
                                                    width: 1,
                                                  ),
                                                ),
                                              ),
                                              menuStyle: MenuStyle(
                                                backgroundColor:
                                                WidgetStateProperty.all(
                                                  thm.backcolor,
                                                ),
                                              ),
                                              dropdownMenuEntries:
                                              grades.map<
                                                  DropdownMenuEntry<
                                                      String
                                                  >
                                              >((String value) {
                                                return DropdownMenuEntry<
                                                    String
                                                >(
                                                  value: value,
                                                  label: value,
                                                  style: MenuItemButton.styleFrom(
                                                    textStyle: TextStyle(
                                                      fontFamily:
                                                      'Montserrat',
                                                    ),
                                                    foregroundColor:
                                                    thm.textcolor,
                                                  ),
                                                );
                                              }).toList(),
                                              onSelected: (
                                                  value,
                                                  ) async {
                                                _isGradeChanged =
                                                true;
                                                selectedgrade =
                                                    reversegradecalc(
                                                      value!,
                                                    );
                                                if (selectedprofileo !=
                                                    3) {
                                                  if (_isGradeChanged) {
                                                    Course
                                                    tempcourse = offshootList
                                                        .lastWhere(
                                                          (course) =>
                                                      course
                                                          .id ==
                                                          "$addcourse $addcourseid",
                                                    );
                                                    // await removeCourseById(
                                                    //   "$addcourse $addcourseid",
                                                    // );
                                                    if (selectedprofileo ==
                                                        1) {
                                                      await addOrUpdateCourseOffshoot(
                                                        Course(
                                                          elective:
                                                          tempcourse
                                                              .elective,
                                                          title:
                                                          tempcourse
                                                              .title,
                                                          sem:
                                                          currentsem,
                                                          id:
                                                          "$addcourse $addcourseid",
                                                          discipline:
                                                          tempcourse
                                                              .discipline,
                                                          grade1:
                                                          selectedgrade,
                                                          grade2:
                                                          tempcourse
                                                              .grade2,
                                                          credits:
                                                          tempcourse
                                                              .credits,
                                                        ),
                                                      );
                                                      selectedelective =
                                                      "None";
                                                    } else if (selectedprofileo ==
                                                        2) {
                                                      await addOrUpdateCourseOffshoot(
                                                        Course(
                                                          elective:
                                                          tempcourse
                                                              .elective,
                                                          title:
                                                          tempcourse
                                                              .title,
                                                          sem:
                                                          currentsem,
                                                          id:
                                                          "$addcourse $addcourseid",
                                                          discipline:
                                                          ((selecteddiscipline.substring(
                                                            0,
                                                            2,
                                                          ) !=
                                                              "--")
                                                              ? selecteddiscipline.substring(
                                                            0,
                                                            2,
                                                          )
                                                              : selecteddiscipline.substring(
                                                            2,
                                                            4,
                                                          )),
                                                          grade1:
                                                          tempcourse
                                                              .grade1,
                                                          grade2:
                                                          selectedgrade,
                                                          credits:
                                                          tempcourse
                                                              .credits,
                                                        ),
                                                      );
                                                      selectedelective =
                                                      "None";
                                                    }
                                                  }
                                                } else {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        style: TextStyle(
                                                          fontFamily:
                                                          "Montserrat",
                                                          fontWeight:
                                                          FontWeight
                                                              .normal,
                                                          fontSize:
                                                          16,
                                                        ),
                                                        "Select Profile First",
                                                      ),
                                                      duration:
                                                      Duration(
                                                        seconds:
                                                        3,
                                                      ),
                                                    ),
                                                  );
                                                }
                                                setState(() {
                                                  if (_isGradeChanged) {
                                                    addcourse = "AN";
                                                    addcourseid =
                                                    "F311";
                                                    //electiveSetter();
                                                    dropdownid =
                                                        mcourselist
                                                            .where(
                                                              (
                                                              course,
                                                              ) => course.id.startsWith(
                                                            "AN" +
                                                                ' ',
                                                          ),
                                                        )
                                                            .map(
                                                              (
                                                              course,
                                                              ) => course.id.replaceFirst(
                                                            "AN" +
                                                                ' ',
                                                            '',
                                                          ),
                                                        )
                                                            .toList();
                                                    dropdownid.sort(
                                                          (a, b) =>
                                                          a.compareTo(
                                                            b,
                                                          ),
                                                    );
                                                    sort(offshootList,currentsorto);
                                                    _isCourseCardOpen =
                                                    false;
                                                    _isGradeChanged =
                                                    false;
                                                  } else {
                                                    sort(offshootList,currentsorto);
                                                    _isCourseCardOpen =
                                                    false;
                                                  }
                                                  selectedgrade = 10;
                                                });
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Spacer(flex: 1),
                              Row(
                                children: [
                                  Spacer(flex: 1),
                                  SizedBox(
                                    height: hei * 0.08,
                                    width: wid * 0.8,
                                    child: Row(
                                      children: [
                                        Spacer(flex: 1),
                                        Container(
                                          height: double.infinity,
                                          width: wid * 0.20,
                                          child: OutlinedButton(
                                            style: OutlinedButton.styleFrom(
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                BorderRadius.circular(
                                                  14,
                                                ),
                                              ),
                                              foregroundColor:
                                              Colors.red,
                                              side: BorderSide(
                                                color: Colors.red,
                                                width: 2,
                                              ),
                                            ),
                                            child: Transform.scale(
                                              scale: 2,
                                              child: Icon(
                                                Icons
                                                    .delete_outline_rounded,
                                              ),
                                              // Image.asset(
                                              //   'images/trash.png',
                                              //   color: Colors.red,
                                              // ),
                                            ),

                                            onPressed: () async {
                                              await removeOffshootCourseById(
                                                "$addcourse $addcourseid",
                                              );
                                              setState(() {
                                                addcourse = "AN";
                                                addcourseid = "F311";
                                                //electiveSetter();
                                                dropdownid =
                                                    mcourselist
                                                        .where(
                                                          (
                                                          course,
                                                          ) => course
                                                          .id
                                                          .startsWith(
                                                        "AN" +
                                                            ' ',
                                                      ),
                                                    )
                                                        .map(
                                                          (
                                                          course,
                                                          ) => course
                                                          .id
                                                          .replaceFirst(
                                                        "AN" +
                                                            ' ',
                                                        '',
                                                      ),
                                                    )
                                                        .toList();
                                                dropdownid.sort(
                                                      (a, b) =>
                                                      a.compareTo(b),
                                                );
                                                sort(offshootList,currentsorto);
                                                _isCourseCardOpen =
                                                false;
                                              });
                                            },
                                          ),
                                        ),
                                      ],
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
                  ),
                ),
              ],
            )
                : SizedBox.shrink(key: ValueKey("closed")),
          ),
        ],
      ),),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.grey.withValues(alpha: 0.05),
          highlightColor: Colors.grey.withValues(alpha: 0.05),
          hoverColor: Colors.grey.withValues(alpha: 0.05),
        ),
        child: BottomNavigationBar(
          backgroundColor: thm.backcolor,
          selectedItemColor: thm.highcolor,
          unselectedItemColor: thm.unscolor,
          currentIndex: selectedprofileo - 1,
          onTap: (index) {
            setState(() {
              if (index + 1 > selectedprofileo) {
                _isrightswipe = true;
              } else {
                _isrightswipe = false;
              }
              selectedprofileo = index + 1;
            });
          },

          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.account_box_outlined),
              label: profile1n,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_box_outlined),
              label: profile2n,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.comment_bank_outlined),
              label: "Compare",
            ),
          ],
          selectedLabelStyle: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
          unselectedLabelStyle: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.normal,
            fontSize: 8,
          ),
        ),
      ),
    );
  }
}
