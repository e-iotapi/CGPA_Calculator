import 'dart:async';
import 'package:cgpa_calculator/core/grading/minor_progress.dart';
import 'package:cgpa_calculator/core/storage/minor.dart';
import 'package:cgpa_calculator/core/storage/offshoot.dart';
import 'package:cgpa_calculator/core/storage/course_order.dart';
import 'package:cgpa_calculator/core/storage/marks.dart';
import 'package:cgpa_calculator/features/calendar/calendar_page.dart';
import 'package:cgpa_calculator/features/marks/marks_page.dart';
import 'package:cgpa_calculator/features/offshoot/minor_panel.dart';
import 'package:cgpa_calculator/features/offshoot/offshoot_panel.dart';
import 'package:cgpa_calculator/features/stats/stats_page.dart';
import 'package:cgpa_calculator/features/setup/degree_setup_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cgpa_calculator/auth_util.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cgpa_calculator/features/settings/settings_page.dart';
import 'package:cgpa_calculator/script.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/core/models/semesters.dart';
import 'package:cgpa_calculator/core/storage/courses.dart';
import 'package:cgpa_calculator/features/semester/semester_controller.dart';
import 'package:cgpa_calculator/features/semester/semester_page.dart';
import 'package:cgpa_calculator/features/semester/add_course_sheet.dart';
import 'package:cgpa_calculator/features/semester/edit_course_sheet.dart';
import 'package:cgpa_calculator/core/grading/cgpa.dart';
import 'package:cgpa_calculator/shared/layout/responsive.dart';
import 'package:cgpa_calculator/shared/widgets/app_nav.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _showFab = true;

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

  bool _isrightswipe = true;
  void setfab() {
    _showFab = true;
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _showFab = false);
      } else {
        _showFab = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // First run: the setup screens, before anything is saved.
    if (!degree_selected) {
      return DegreeSetupPage(
        email: FirebaseAuth.instance.currentUser?.email,
        onDone: () => setState(() => degree_selected = true),
      );
    }
    List<Course> sitems = items.toList();
    sort(sitems, currentsort);
    setdis();
    setsort();
    setsem();
    setprof();
    settheme();
    setnavcolor();
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
                // Landscape browser: keep the phone layout readable.
                wid = wid.clamp(0, 600).toDouble();
              }
              return MediaQuery(
                data: mq.copyWith(size: Size(c.maxWidth, hei)),
                child: _semesterView(sitems, wid, hei),
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

  /// Shows profile [profile] in Compare's [slot]. A profile with no grades
  /// yet can start as a copy of one that has some.
  Future<void> _changeCompared(int slot, int profile) async {
    final (a, b) = comparePair;
    final other = slot == 0 ? b : a;
    setState(() {
      comparePair =
          profile == other
              ? (b, a)
              : slot == 0
              ? (profile, b)
              : (a, profile);
    });
    await setprof();
    if (!mounted || !profileIsEmpty(profile)) return;
    final names = profileNames;
    final from = await showDialog<int>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: Text('Start ${names[profile - 1]} from…'),
            content: const Text(
              'It has no grades yet. Copy another profile\'s grades, in every '
              'semester, as a starting point?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Start empty'),
              ),
              for (var id = 1; id <= profileCount; id++)
                if (id != profile && !profileIsEmpty(id))
                  TextButton(
                    onPressed: () => Navigator.pop(c, id),
                    child: Text(names[id - 1]),
                  ),
            ],
          ),
    );
    if (from == null) return;
    await copyProfile(from, profile);
    if (mounted) setState(() {});
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
        profileNames: profileNames,
        compared: comparePair,
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
      onReorder: (order) async {
        await setCourseOrder(currentsem, [for (final c in order) c.id]);
        if (mounted) setState(() => currentsort = CourseSort.custom.key);
      },
      onExport: () => _exportSemester(sitems),
      onAddCourse: () async {
        final c = await showAddCourseSheet(
          context,
          held: Hive.box<Course>('coursesBox').values,
          sem: currentsem,
          discipline: selecteddiscipline,
          profile:
              SemesterMode.fromProfileId(selectedprofile).profile ??
              Profile.actual,
        );
        if (c == null) return;
        await addOrUpdateCourse(c);
        await seedDefaultComponents(c.id, c.title);
        if (mounted) {
          setState(() {
            sgpa = sgcalc(currentsem);
            cgpa = cgcalc();
          });
        }
      },
      onCourseTap: (c, i) async {
        Future<void> edit() async {
          final e = await showEditCourseSheet(
            context,
            course: c,
            discipline: selecteddiscipline,
            profile: SemesterMode.fromProfileId(selectedprofile).profile,
          );
          if (e == null) return;
          await applyCourseEdit(c, e);
          if (mounted) {
            setState(() {
              sgpa = sgcalc(currentsem);
              cgpa = cgcalc();
            });
          }
        }
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MarksPage(course: c, onEditCourse: edit),
          ),
        );
        if (mounted) setState(() {});
      },
      classDeltas: classDeltas(),
      onGradePicked: (c, g) async {
        await saveCourse(c.withGrade(selectedprofile, g));
        setState(() {});
      },
      onCompareGradePicked: (c, profile, g) async {
        await saveCourse(c.withGrade(profile, g));
        setState(() {});
      },
      onCompareChanged: _changeCompared,
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
          ).push(MaterialPageRoute(builder: (context) => StatsPage(discipline: selecteddiscipline))),
      onOpenCalendar: () async {
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (context) => const CalendarPage()));
        if (mounted) setState(() {});
      },
      onOpenSettings: _openSettings,
      onToggleTheme:
          () => switchTheme(
            !thm.isDark,
            then: () {
              if (mounted) setState(() {});
            },
          ),
      offshoot:
          selectedprofile == 4
              ? OffshootTab(
                showMinor: offshootShowsMinor,
                onShowMinor: setOffshootShowsMinor,
                offshoot: OffshootPanel(
                  score: loadOffshootScore(),
                  onToggleCourse: (id) async {
                    await toggleOffshootExcluded(id);
                    setState(() {});
                  },
                  onOutOfSelected: (v) async {
                    await setOffshootOutOf(v);
                    setState(() {});
                  },
                ),
                minor: MinorPanel(
                  progress: switch (chosenMinor) {
                    final m? => minorProgress(
                      m,
                      allCourses(),
                      selecteddiscipline,
                    ),
                    null => null,
                  },
                  discipline: selecteddiscipline,
                  onChoose: (m) async {
                    await setChosenMinor(m);
                    setState(() {});
                  },
                ),
              )
              : null,
    );
  }

  Future<void> _openSettings() async {
    erase = 0;
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => const SettingsPage()))
        .then((value) async {
          selected_theme = selected_theme;
          thm = AppPalette.byName(selected_theme);
          profile1n = profile1n;
          profile2n = profile2n;
          currentsem = currentsem;
          batch = batch;
          selecteddiscipline = selecteddiscipline;
          await setdis();
          await initializeCourses();
          setnavcolor();
          setState(() {
            thm = AppPalette.byName(selected_theme);
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
