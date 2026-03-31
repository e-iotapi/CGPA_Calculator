import 'dart:io';
import 'dart:async';
import 'package:cgpa_calculator/offshoot.dart';
import 'package:cgpa_calculator/analytics.dart';
import 'dart:html' as html;
import 'dart:js' as js;
import 'package:cgpa_calculator/course.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:marquee/marquee.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cgpa_calculator/settings.dart';
import 'package:cgpa_calculator/script.dart';
import 'package:cgpa_calculator/mastercourselist.dart';
import 'package:cgpa_calculator/constants.dart';
import 'dart:math';
import 'package:in_app_update/in_app_update.dart';
import 'package:url_launcher/url_launcher.dart';
part 'overlays_extension.dart';
part 'main_ui_extension.dart';
//html and js imports and uses to be removed for android build

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _dropdownResetKey = 0;
  bool _showFab = true;
  int _pullSession = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!kIsWeb) {
        mcourselist = await fetchData();
      }
      if (!kIsWeb) {
        if ( Platform.isAndroid) {
          final updateInfo = await InAppUpdate.checkForUpdate();
          if (updateInfo.updateAvailability ==
              UpdateAvailability.updateAvailable) {
            if (mounted) {
              showDialog(
                context: context,
                barrierDismissible: true,
                builder:
                    (context) => AlertDialog(
                      backgroundColor: thm.backcolor,
                      title: Text(
                        'Update Available',
                        style: TextStyle(color: thm.textcolor),
                      ),
                      content: Text(
                        'An Update is Available. Update now?',
                        style: TextStyle(color: thm.textcolor),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () async {
                            Navigator.of(context).pop();
                            await launchUrl(
                              Uri.parse(
                                'https://play.google.com/store/apps/details?id=com.srijen.cgpa_calculator',
                              ),
                            );
                          },
                          child: Text(
                            'Update',
                            style: TextStyle(color: thm.highcolor),
                          ),
                        ),
                      ],
                    ),
              );
            }
          }
        }
      }
    });
  }

  List<Course> get items =>
      Hive.box<Course>('coursesBox').values
          .where(
            (course) =>
                course.sem == currentsem &&
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

  bool _isCardOpen = false;
  bool _isClosing = false;
  bool _isClosingCourse = false;
  bool _isGradeChanged = false;
  bool _isDisciplineChanged = false;
  bool _isCourseCardOpen = false;
  bool _isrightswipe = true;
  bool _isSearched = false;
  TextEditingController _batchController1 = TextEditingController(
    text: batch.toString(),
  );
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

  void setfab() {
    _showFab = true;
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted)
        setState(() => _showFab = false);
      else
        _showFab = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Course> sitems = items.toList();
    sort(sitems,currentsort);
    setdis();
    setsort();
    setsem();
    setprof();
    settheme();
    setnavcolor();
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
    sgpa = sgcalc(currentsem);
    cgpa = cgcalc();
    scred1 = 0;
    scred2 = 0;
    ccred1 = 0;
    ccred2 = 0;
    for (Course i in Hive.box<Course>('coursesBox').values.where(
      (course) =>
          (course.discipline == selecteddiscipline.substring(0, 2) ||
              course.discipline == selecteddiscipline.substring(2, 4)) &&
          course.sem == currentsem,
    )) {
      scred1 += (i.grade1 < 0 && !(i.grade1 == -3)) ? 0 : i.credits;
      scred2 += (i.grade2 < 0 && !(i.grade2 == -3)) ? 0 : i.credits;
    }

    for (Course i in Hive.box<Course>('coursesBox').values.where(
      (course) =>
          (course.discipline == selecteddiscipline.substring(0, 2) ||
              course.discipline == selecteddiscipline.substring(2, 4)),
    )) {
      ccred1 += (i.grade1 < 0 && !(i.grade1 == -3)) ? 0 : i.credits;
      ccred2 += (i.grade2 < 0 && !(i.grade2 == -3)) ? 0 : i.credits;
    }
    var wid = MediaQuery.of(context).size.width;
    var hei = MediaQuery.of(context).size.height;
    if (kIsWeb && hei < wid) {
      wid = hei * 17.9 / 18;
    }
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: thm.backcolor,
        body: Stack(
          children: [
            buildMainUI(wid, hei, sitems),
            buildCourseDetailSheet(wid, hei, sitems),
            buildSearchOverlay(wid, hei, sitems),
            AnimatedSwitcher(
              duration: Duration(milliseconds: 400),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              child:
                  !degree_selected
                      ? Stack(
                        children: [
                          AnimatedOpacity(
                            opacity: !degree_selected ? 0.6 : 0.0,
                            duration: Duration(milliseconds: 500),
                            child: GestureDetector(
                              onTap: () async {},
                              child: Container(
                                color: thm.textcolor,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                            ),
                          ),
                          Center(
                            child: buildAddCourseDialog(wid, hei, sitems),
                          ),
                        ],
                      )
                      : SizedBox.shrink(),
            ),
          ],
        ),
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
            currentIndex: selectedprofile - 1,
            onTap: (index) {
              setState(() {
                if (index + 1 > selectedprofile) {
                  _isrightswipe = true;
                } else {
                  _isrightswipe = false;
                }
                selectedprofile = index + 1;
                if (selectedprofile == 2) {
                  _showFab = true;
                  setfab();
                }
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
        floatingActionButton: AnimatedSwitcher(
          duration: Duration(milliseconds: 100),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) {
            final tween = Tween<Offset>(
              begin: const Offset(0, 0.3),
              end: Offset.zero,
            ).chain(CurveTween(curve: Curves.easeOut));
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
          child:
              (selectedprofile == 2 && _showFab)
                  ? FloatingActionButton(
                    key: const ValueKey("Button"),
                    elevation: 10,
                    backgroundColor:
                        (selected_theme == "Black" || selected_theme == "Blue")
                            ? thm.sepcolor
                            : thm.backcolor,
                    onPressed: () async {
                      await copyGrades();
                      setState(() {});
                    },
                    child: Icon(Icons.copy, color: thm.textcolor),
                  )
                  : SizedBox.shrink(),
        ),
      ),
    );
  }
}
