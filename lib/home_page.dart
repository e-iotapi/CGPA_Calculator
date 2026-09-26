import 'dart:async';
import 'package:cgpa_calculator/offshoot_calc.dart';
import 'package:cgpa_calculator/analytics.dart';
import 'package:cgpa_calculator/pwa_helper/pwa_helper.dart';
import 'package:cgpa_calculator/auth_util.dart';
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
import 'package:cgpa_calculator/core/models/semesters.dart';
import 'package:cgpa_calculator/core/storage/courses.dart';
import 'package:cgpa_calculator/features/semester/semester_controller.dart';
import 'package:cgpa_calculator/features/semester/semester_page.dart';
import 'package:cgpa_calculator/shared/layout/responsive.dart';
import 'package:cgpa_calculator/shared/widgets/app_nav.dart';
import 'dart:math';
part 'overlays_extension.dart';
part 'main_ui_extension.dart';
part 'offshoot_panel_extension.dart';

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
  final ValueNotifier<double> pullOverscrollNotifier = ValueNotifier(0.0);
  @override
  void initState() {
    super.initState();
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
    sort(sitems, currentsort);
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
    creditTotals();
    // The current palette is re-injected on every build: settings change the
    // `thm` global and setState here, but MyApp above never rebuilds.
    return Theme(
      data: Theme.of(context).copyWith(extensions: [thm]),
      child: PopScope(
        canPop: false,
        child: ResponsiveScaffold(
          selectedIndex: selectedprofile - 1,
          onSelected: (index) {
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
          destinations: [
            NavDestination(icon: Icons.home_outlined, label: profile1n),
            NavDestination(icon: Icons.bar_chart_rounded, label: profile2n),
            const NavDestination(
              icon: Icons.compare_arrows_rounded,
              label: 'Compare',
            ),
            const NavDestination(
              icon: Icons.workspace_premium_outlined,
              label: 'Offshoot',
            ),
          ],
          body: LayoutBuilder(
            builder: (context, c) {
              // The legacy screens below size and centre themselves off
              // MediaQuery's width, assuming they fill the window. Beside the
              // rail they do not, so they are shown the body's width instead.
              // Height is left alone until the MediaQuery × n sizing goes.
              final mq = MediaQuery.of(context);
              var wid = c.maxWidth;
              final hei = mq.size.height;
              if (kIsWeb && hei < wid) {
                wid = hei * 17.9 / 18;
              }
              return MediaQuery(
                data: mq.copyWith(size: Size(c.maxWidth, hei)),
                child: Stack(
                  children: [
                    _semesterView(sitems, wid, hei),
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
                                    child: buildAddCourseDialog(
                                      wid,
                                      hei,
                                      sitems,
                                    ),
                                  ),
                                ],
                              )
                              : SizedBox.shrink(),
                    ),
                  ],
                ),
              );
            },
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
                          (selected_theme == "Black" ||
                                  selected_theme == "Blue")
                              ? thm.sepcolor
                              : thm.backcolor,
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder:
                              (ctx) => AlertDialog(
                                backgroundColor: thm.backcolor,
                                title: Text(
                                  'Import from $profile1n?',
                                  style: TextStyle(
                                    color: thm.textcolor,
                                    fontFamily: 'Montserrat',
                                  ),
                                ),
                                content: Text(
                                  'Every $profile1n grade, in all semesters, will '
                                  'be copied over your $profile2n grades. '
                                  'This cannot be undone.',
                                  style: TextStyle(
                                    color: thm.textcolor,
                                    fontSize: 14,
                                    fontFamily: 'Montserrat',
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.of(ctx).pop(false),
                                    child: Text(
                                      'Cancel',
                                      style: TextStyle(color: thm.textcolor),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed:
                                        () => Navigator.of(ctx).pop(true),
                                    child: Text(
                                      'Import',
                                      style: TextStyle(color: thm.highcolor),
                                    ),
                                  ),
                                ],
                              ),
                        );
                        if (ok != true) return;
                        await copyGrades();
                        setState(() {});
                      },
                      child: Icon(Icons.copy, color: thm.textcolor),
                    )
                    : SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  Widget _semesterView(List<Course> sitems, double wid, double hei) {
    final parts = greeting().split(', ');
    return SemesterView(
      data: SemesterData.from(
        allCourses: Hive.box<Course>('coursesBox').values,
        visible: sitems,
        sem: currentsem,
        semesters: semestersFor(selecteddiscipline),
        discipline: selecteddiscipline,
        mode: SemesterMode.fromProfileId(selectedprofile),
        sort: CourseSort.fromKey(currentsort),
        profileNames: (profile1n, profile2n),
      ),
      greeting: parts.first,
      name: parts.skip(1).join(', '),
      slideFromRight: _isrightswipe,
      onSemesterSelected:
          (s) => setState(() {
            currentsem = s;
            sgpa = sgcalc(s);
            cgpa = cgcalc();
          }),
      onSortSelected: (s) => setState(() => currentsort = s.key),
      onExport: () => _exportSemester(sitems),
      onAddCourse:
          () => setState(() {
            _isSearched = false;
            _isCardOpen = true;
          }),
      onCourseTap:
          (c, i) => setState(() {
            tapid = i;
            addcourse = c.id.split(" ")[0];
            addcourseid = c.id.split(" ")[1];
            _isCourseCardOpen = true;
          }),
      onGradePicked: (c, g) async {
        await saveCourse(withGrade(c, selectedprofile, g));
        setState(() {});
      },
      onClearRequested: _confirmClearSemester,
      onSwipe:
          (delta) => setState(() {
            final next = selectedprofile + delta;
            if (next < 1 || next > 4) return;
            _isrightswipe = delta > 0;
            selectedprofile = next;
          }),
      onOpenAnalytics:
          () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (context) => Analytics())),
      onOpenSettings: _openSettings,
      onToggleTheme:
          () => setState(() {
            selected_theme = thm.isDark ? 'White' : 'Black';
            thm = themes.firstWhere((t) => t.theme == selected_theme);
          }),
      onInstall: kIsWeb ? () => PwaHelper.promptInstall(context, thm) : null,
      offshoot: selectedprofile == 4 ? buildOffshootUI(wid, hei) : null,
    );
  }

  Future<void> _openSettings() async {
    erase = 0;
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => Settings()))
        .then((value) async {
          selected_theme = selected_theme;
          thm = themes.firstWhere((theme) => theme.theme == selected_theme);
          profile1n = profile1n;
          profile2n = profile2n;
          currentsem = currentsem;
          batch = batch;
          selecteddiscipline = selecteddiscipline;
          await setdis();
          await initializeCourses();
          setnavcolor();
          setState(() {
            thm = themes.firstWhere((theme) => theme.theme == selected_theme);
          });
        });
  }

  Future<void> _exportSemester(List<Course> sitems) async {
    final sitemsAsMaps =
        sitems
            .map(
              (course) => {
                'credits': course.credits,
                'name': course.title,
                'grade': (selectedprofile == 1) ? course.grade1 : course.grade2,
              },
            )
            .toList();
    var imgpath = await saveDataAsImage(
      isOffshoot: false,
      sitemsAsMaps,
      semester: currentsem,
      thisSemCredits: (selectedprofile == 1) ? scred1 : scred2,
      totalCredits: (selectedprofile == 1) ? ccred1 : ccred2,
      gpa: sgcalc(currentsem),
      cgpa: cgcalc(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          imgpath,
          style: TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.normal,
            fontSize: 16,
          ),
        ),
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<void> _confirmClearSemester() async {
    final clear = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: thm.backcolor,
            title: Text(
              "Clear Grades",
              style: TextStyle(fontFamily: "Montserrat", color: thm.textcolor),
            ),
            content: Text(
              "Are you sure you want to clear all grades for this semester?",
              style: TextStyle(fontFamily: "Montserrat", color: thm.textcolor),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  "Cancel",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: thm.textcolor,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  "Clear",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: thm.highcolor,
                  ),
                ),
              ),
            ],
          ),
    );
    if (clear != true) return;
    await clearSemesterGrades(currentsem, selectedprofile);
    setState(() {
      sgpa = sgcalc(currentsem);
      cgpa = cgcalc();
    });
  }
}
