// Contains code from CGPA_Calculator by Srijen Raja (Apache License 2.0),
// modified by Siddharth Mishra. See NOTICE.
import 'dart:async';
import 'package:cgpa_calculator/app/router.dart';
import 'package:cgpa_calculator/core/grading/minor_progress.dart';
import 'package:cgpa_calculator/core/storage/minor.dart';
import 'package:cgpa_calculator/core/storage/offshoot.dart';
import 'package:cgpa_calculator/core/storage/course_order.dart';
import 'package:cgpa_calculator/core/storage/marks.dart';
import 'package:cgpa_calculator/features/calendar/calendar_page.dart';
import 'package:cgpa_calculator/features/marks/marks_page.dart';
import 'package:cgpa_calculator/features/more/more_page.dart';
import 'package:cgpa_calculator/features/offshoot/minor_panel.dart';
import 'package:cgpa_calculator/features/offshoot/offshoot_panel.dart';
import 'package:cgpa_calculator/features/stats/stats_page.dart';
import 'package:cgpa_calculator/features/setup/degree_setup_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cgpa_calculator/auth_util.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:cgpa_calculator/features/settings/settings_page.dart';
import 'package:cgpa_calculator/script.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/core/models/semesters.dart';
import 'package:cgpa_calculator/core/storage/courses.dart';
import 'package:cgpa_calculator/features/semester/semester_controller.dart';
import 'package:cgpa_calculator/features/semester/semester_page.dart';
import 'package:cgpa_calculator/features/semester/home_persist.dart';
import 'package:cgpa_calculator/features/semester/widgets/copy_profile_button.dart';
import 'package:cgpa_calculator/features/semester/add_course_sheet.dart';
import 'package:cgpa_calculator/features/semester/edit_course_sheet.dart';
import 'package:cgpa_calculator/core/grading/cgpa.dart';
import 'package:cgpa_calculator/shared/widgets/confirm_dialog.dart';
import 'package:cgpa_calculator/shared/layout/responsive.dart';
import 'package:cgpa_calculator/shared/widgets/app_nav.dart';
import 'package:cgpa_calculator/core/prefs/prefs_store.dart';
import 'package:cgpa_calculator/features/tour/tour.dart';
import 'package:cgpa_calculator/shared/tour_key.dart';

/// Nav ids in display order: 1..4 are the profiles (Actual, Expected,
/// Compare, Offshoot), 0 is More. Hiding Offshoot drops id 4 only, so
/// [selectedprofile] and More keep their meaning (U3).
@visibleForTesting
List<int> homeNavIds(bool offshoot) => [1, 2, 3, if (offshoot) 4, 0];

/// The profile a swipe by [delta] lands on, or null at either end. A hidden
/// Offshoot is not the end of the line: the line is one shorter.
@visibleForTesting
int? homeNextProfile(int current, int delta, bool offshoot) {
  final next = current + delta;
  return next < 1 || next > (offshoot ? 4 : 3) ? null : next;
}

/// The home screen: the course list, SGPA and CGPA.
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title, this.profile});
  final String title;

  /// The tab its path names (`/expected` is 2); null under other pages.
  final int? profile;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // Same discipline filter the GPA tallies use (core/grading/cgpa.dart), so
  // the visible list and SGPA/CGPA never disagree on which courses count
  // (BUG-40: a catalogue open elective with discipline "--" used to match
  // this getter's own hand-rolled check only when "--" was the *second*
  // half of selecteddiscipline, while cgpa.dart's inDiscipline checked both
  // halves unconditionally — so a "--" course was hidden from the list but
  // still counted in SGPA/CGPA whenever "--" was the first half).
  List<Course> get items =>
      Hive.box<Course>('coursesBox').values
          .where(
            (course) =>
                course.sem == currentsem &&
                inDiscipline(course, selecteddiscipline),
          )
          .toList();

  bool _isrightswipe = true;

  /// The copy button's height and the gap above it, kept clear under the
  /// course list on Expected.
  static const double _copyButtonRoom = 72;

  @override
  void initState() {
    super.initState();
    setnavcolor();
    offshootHiddenNow.addListener(_offshootChanged);
    // A saved Offshoot profile from before it was hidden (or from another
    // device): land on Actual instead of an unhighlighted nav.
    _follow(widget.profile);
    if (selectedprofile == 4 && offshootHiddenNow.value) selectedprofile = 1;
    // The guided tour: first sign-in after setup, and its profile switches.
    tourSelectProfile = _tourSelectProfile;
    maybeStartFirstTour();
  }

  @override
  void didUpdateWidget(MyHomePage old) {
    super.didUpdateWidget(old);
    _follow(widget.profile);
  }

  /// A tab's path was opened (a bookmark, Back, Forward): show that tab.
  void _follow(int? id) {
    if (id == null || id == selectedprofile) return;
    if (id == 4 && offshootHiddenNow.value) return;
    _isrightswipe = id > selectedprofile;
    selectedprofile = id;
    _persist(HomeChange.profile);
  }

  /// The address bar follows the tab, so each tab can be bookmarked.
  void _showPath() {
    final path = Routes.tab(selectedprofile);
    final router = GoRouter.maybeOf(context);
    if (router != null && router.state.uri.path != path) router.go(path);
  }

  /// The tour looks at a profile without saving the choice.
  void _tourSelectProfile(int id) {
    if (!mounted) return;
    setState(() {
      _isrightswipe = id > selectedprofile;
      selectedprofile = id;
    });
  }

  @override
  void dispose() {
    offshootHiddenNow.removeListener(_offshootChanged);
    if (tourSelectProfile == _tourSelectProfile) tourSelectProfile = null;
    super.dispose();
  }

  /// The Show Offshoot tab switch (Settings) or a pull changed. Only Home
  /// rebuilds, and only for this.
  void _offshootChanged() {
    if (!mounted) return;
    setState(() {
      if (selectedprofile == 4 && offshootHiddenNow.value) {
        selectedprofile = 1;
        _persist(HomeChange.profile);
        _showPath();
      }
    });
  }

  List<int> get _navIds => homeNavIds(!offshootHiddenNow.value);

  NavDestination _navDestination(int id) => switch (id) {
    1 => NavDestination(
      icon: Icons.home_outlined,
      label: profile1n,
      tourId: 'nav.1',
    ),
    2 => NavDestination(
      icon: Icons.bar_chart_rounded,
      label: profile2n,
      tourId: 'nav.2',
    ),
    3 => const NavDestination(
      icon: Icons.open_in_full_rounded,
      label: 'Compare',
      tourId: 'nav.3',
    ),
    4 => const NavDestination(
      icon: Icons.workspace_premium_outlined,
      label: 'Offshoot',
      tourId: 'nav.4',
    ),
    _ => const NavDestination(
      icon: Icons.more_horiz_rounded,
      label: 'More',
      tourId: 'nav.0',
    ),
  };

  /// Saves what [c] changed. Build saves nothing (UI_OPT O3.1).
  void _persist(HomeChange c) {
    for (final w in writesFor(c)) {
      switch (w) {
        case HomeWrite.sem:
          setsem();
        case HomeWrite.sort:
          setsort();
        case HomeWrite.profile:
          setprof();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // First run: the setup screens, before anything is saved.
    if (!degree_selected) {
      return DegreeSetupPage(
        email: FirebaseAuth.instance.currentUser?.email,
        onDone: () {
          setState(() => degree_selected = true);
          maybeStartFirstTour();
        },
      );
    }
    List<Course> sitems = items.toList();
    sort(sitems, currentsort);
    sgpa = sgcalc(currentsem);
    cgpa = cgcalc();
    creditTotals();
    // No Theme of its own: the app theme already carries the palette and is
    // rebuilt on every switch. A copy cached here stopped listening once the
    // Working-as strip moved the page, and the theme stopped switching.
    return PopScope(
      canPop: false,
      child: ResponsiveScaffold(
        selectedIndex: _navIds.indexOf(selectedprofile),
        onSelected: (index) {
          final id = _navIds[index];
          // More is a hub above the profiles, not a fifth profile.
          if (id == 0) {
            openRoute(context, Routes.more, () => const MorePage());
            return;
          }
          setState(() {
            _isrightswipe = id > selectedprofile;
            selectedprofile = id;
          });
          _persist(HomeChange.profile);
          _showPath();
        },
        destinations: [for (final id in _navIds) _navDestination(id)],
        body: LayoutBuilder(
          builder: (context, c) {
            // The legacy screens below size and centre themselves off
            // MediaQuery's width, assuming they fill the window. Beside the
            // rail they do not, so they are shown the body's width instead.
            // Height is left alone until the MediaQuery × n sizing goes.
            // Size only: a keyboard opening in a sheet re-runs _Resized
            // below, not this builder (UI_OPT O3.2).
            var wid = c.maxWidth;
            final hei = MediaQuery.sizeOf(context).height;
            if (kIsWeb && hei < wid) {
              // Landscape browser: keep the phone layout readable.
              wid = wid.clamp(0, 600).toDouble();
            }
            return _Resized(
              size: Size(c.maxWidth, hei),
              // Expected keeps the copy button up; the list scrolls clear
              // of it.
              extraBottom: selectedprofile == 2 ? _copyButtonRoom : 0,
              child: _semesterView(sitems, wid, hei),
            );
          },
        ),
        floatingActionButton: KeyedSubtree(
          key: tourKey('copy'),
          child: AnimatedSwitcher(
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
              selectedprofile == 2
                  ? CopyProfileButton(
                    key: const ValueKey("Button"),
                    from: profile1n,
                    to: profile2n,
                    onCopy: () async {
                      await copyGrades();
                      if (mounted) setState(() {});
                    },
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
          (c) => AppDialog(
            title: 'Start ${names[profile - 1]} from…',
            body:
                'It has no grades yet. Copy another profile\'s grades, in every '
                'semester, as a starting point?',
            actions: [
              DialogAction('Start empty', onTap: () => Navigator.pop(c)),
              for (var id = 1; id <= profileCount; id++)
                if (id != profile && !profileIsEmpty(id))
                  DialogAction(
                    names[id - 1],
                    onTap: () => Navigator.pop(c, id),
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
      onSemesterSelected: (s) {
        setState(() {
          currentsem = s;
          sgpa = sgcalc(s);
          cgpa = cgcalc();
        });
        _persist(HomeChange.semester);
      },
      onSortSelected: (s) {
        setState(() => currentsort = s.key);
        _persist(HomeChange.sort);
      },
      onReorder: (order) async {
        await setCourseOrder(currentsem, [for (final c in order) c.id]);
        if (!mounted) return;
        setState(() => currentsort = CourseSort.custom.key);
        _persist(HomeChange.sort);
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

        await openRoute(
          context,
          Routes.course(c.id),
          () => MarksPage(course: c, onEditCourse: edit),
          extra: edit,
        );
        if (mounted) {
          setState(() {
            sgpa = sgcalc(currentsem);
            cgpa = cgcalc();
          });
        }
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
      onSwipe: (delta) {
        final next = homeNextProfile(
          selectedprofile,
          delta,
          !offshootHiddenNow.value,
        );
        if (next == null) return;
        setState(() {
          _isrightswipe = delta > 0;
          selectedprofile = next;
        });
        _persist(HomeChange.profile);
        _showPath();
      },
      onOpenAnalytics:
          () => openRoute(
            context,
            Routes.stats,
            () => StatsPage(discipline: selecteddiscipline),
          ),
      onOpenCalendar: () async {
        await openRoute(context, Routes.calendar, () => const CalendarPage());
        if (mounted) setState(() {});
      },
      onOpenSettings: _openSettings,
      // UI_OPT O1.7: no Home rebuild here until O3.1 makes that build cheap;
      // the theme still flips because MyApp rebuilds this subtree already.
      onToggleTheme: () => switchTheme(!thm.isDark),
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
    await openRoute(context, Routes.settings, () => const SettingsPage()).then((
      value,
    ) async {
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
    final clear = await confirmDialog(
      context,
      title: 'Clear grades?',
      body: 'Every grade in this semester is cleared. The courses stay.',
      action: 'Clear',
      danger: true,
    );
    if (!clear) return;
    await clearSemesterGrades(currentsem, selectedprofile);
    setState(() {
      sgpa = sgcalc(currentsem);
      cgpa = cgcalc();
    });
  }
}

/// Shows [child] the body's [size] and [extraBottom] more bottom padding.
/// It reads the whole MediaQuery to copy it, so it rebuilds on any change
/// (a keyboard opening); [child] is built above and is not rebuilt with it.
class _Resized extends StatelessWidget {
  const _Resized({
    required this.size,
    required this.extraBottom,
    required this.child,
  });

  final Size size;
  final double extraBottom;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(
        size: size,
        padding:
            extraBottom == 0
                ? mq.padding
                : mq.padding.copyWith(bottom: mq.padding.bottom + extraBottom),
      ),
      child: child,
    );
  }
}
