// The guided tour's 40 steps in 7 chapters (UI_MAP.md section 8). Each step
// points at one control by its tour key id (lib/shared/tour_key.dart); a
// step whose control is not in this build or on this account is skipped.

/// The screen a step is shown on.
enum TourPage { home, course, calendar, stats, more, settings }

class TourStep {
  const TourStep(
    this.id,
    this.chapter,
    this.page,
    this.target,
    this.title,
    this.line, {
    this.profile = 1,
  });

  final String id;

  /// 0-based, into [tourChapters].
  final int chapter;
  final TourPage page;

  /// The tour key id of the highlighted control.
  final String target;
  final String title;
  final String line;

  /// Home's grade profile (1 Actual, 2 Expected, 3 Compare, 4 Offshoot) this
  /// step needs; only read on [TourPage.home].
  final int profile;
}

const tourChapters = [
  'Home basics',
  'Grade profiles',
  'Marks tracker',
  'Offshoot and Minor',
  'Calendar and Stats',
  'More',
  'Settings',
];

const tourSteps = <TourStep>[
  // 1 Home basics
  TourStep(
    'actual',
    0,
    TourPage.home,
    'nav.1',
    'Actual tab',
    'Your real grades. SGPA and CGPA update as you set them.',
  ),
  TourStep(
    'swipe',
    0,
    TourPage.home,
    'summary',
    'Swipe sideways',
    'Move between Actual, Expected and Compare.',
  ),
  TourStep(
    'semesters',
    0,
    TourPage.home,
    'pills',
    'Semester pills',
    'Pick a semester; the arrows scroll on a computer.',
  ),
  TourStep(
    'grade-tap',
    0,
    TourPage.home,
    'chip',
    'Grade chip, tap',
    'Tap a grade to change it.',
  ),
  TourStep(
    'grade-drag',
    0,
    TourPage.home,
    'chip',
    'Grade chip, hold and drag',
    'Hold and drag up or down to scrub through grades.',
  ),
  TourStep(
    'add',
    0,
    TourPage.home,
    'add',
    'Add',
    'Add a course from the catalogue, with its star ratings, or enter one by '
        'hand.',
  ),
  TourStep(
    'sort',
    0,
    TourPage.home,
    'sort',
    'Sort menu and drag handle',
    'Sort your courses, or drag the handle into your own order.',
  ),
  TourStep(
    'pull',
    0,
    TourPage.home,
    'section',
    'Pull down and hold',
    'Pull down and hold to clear this semester\'s grades.',
  ),
  TourStep(
    'export',
    0,
    TourPage.home,
    'export',
    'Export gradesheet',
    'Save this semester\'s grades as an image.',
  ),
  // 2 Grade profiles
  TourStep(
    'expected',
    1,
    TourPage.home,
    'nav.2',
    'Expected tab',
    'The grades you expect, to plan the semester.',
    profile: 2,
  ),
  TourStep(
    'copy',
    1,
    TourPage.home,
    'copy',
    'Copy grades button',
    'Start Expected from your Actual grades in one tap.',
    profile: 2,
  ),
  TourStep(
    'compare',
    1,
    TourPage.home,
    'nav.3',
    'Compare tab',
    'Two profiles side by side; tap a card to pick which.',
    profile: 3,
  ),
  // 3 Marks tracker (opens the first course; skipped if there is none)
  TourStep(
    'course-row',
    2,
    TourPage.home,
    'row',
    'Course row',
    'Tap a course to track its marks.',
  ),
  TourStep(
    'setup',
    2,
    TourPage.course,
    'marks.total',
    'Course setup chip',
    'Weighted, each part has a %, or total marks, and what it is out of.',
  ),
  TourStep(
    'add-eval',
    2,
    TourPage.course,
    'marks.add',
    'Add evaluative',
    'Add each quiz, midsem, lab or compre: weight, your marks, out of, date.',
  ),
  TourStep(
    'parts',
    2,
    TourPage.course,
    'marks.eval',
    'Several parts, best k of n',
    'Split a component into parts and count only the best k.',
  ),
  TourStep(
    'class-avg',
    2,
    TourPage.course,
    'marks.avg',
    'Class average and Averages row',
    'Add the class average to see where you stand; tap to see where each '
        'average came from.',
  ),
  TourStep(
    'official',
    2,
    TourPage.course,
    'marks.official',
    'Official scheme',
    'When your CR publishes the scheme, weights and averages fill in by '
        'themselves.',
  ),
  TourStep(
    'diverged',
    2,
    TourPage.course,
    'marks.diverged',
    'Divergence card',
    'Change an official value and we keep yours, and show what changed.',
  ),
  TourStep(
    'edit-bin',
    2,
    TourPage.course,
    'marks.actions',
    'Edit and bin icons',
    'Edit the scheme, credits and grade, or delete the course.',
  ),
  TourStep(
    'taken-by',
    2,
    TourPage.course,
    'marks.takenby',
    'Taken by, Reviews',
    'See who teaches it this term and what past batches said.',
  ),
  // 4 Offshoot and Minor
  TourStep(
    'offshoot',
    3,
    TourPage.home,
    'nav.4',
    'Offshoot tab',
    'Your offshoot score: best 5 or all 6, tick the courses that count.',
    profile: 4,
  ),
  TourStep(
    'minor',
    3,
    TourPage.home,
    'offshoot.minor',
    'Minor toggle',
    'Choose a minor and see what it still needs.',
    profile: 4,
  ),
  // 5 Calendar and Stats
  TourStep(
    'calendar',
    4,
    TourPage.home,
    'calendar',
    'Calendar icon',
    'Your evaluatives and the academic calendar, by month.',
  ),
  TourStep(
    'week',
    4,
    TourPage.calendar,
    'cal.views',
    'Week tab',
    'Your classes by time; tap one to change its time just for you.',
  ),
  TourStep(
    'stats',
    4,
    TourPage.home,
    'statsbtn',
    'Stats icon',
    'Your CGPA, semester by semester.',
  ),
  TourStep(
    'target',
    4,
    TourPage.stats,
    'stats.target',
    'Target CGPA',
    'Set a target and see the SGPA you need.',
  ),
  TourStep(
    'plan',
    4,
    TourPage.stats,
    'stats.plan',
    'Plan the rest',
    'Slide each future semester to plan your way there.',
  ),
  TourStep(
    'degree',
    4,
    TourPage.stats,
    'stats.degree',
    'Degree tab',
    'Credits earned for each requirement; change what a course counts as.',
  ),
  // 6 More
  TourStep(
    'more',
    5,
    TourPage.home,
    'nav.0',
    'More tab',
    'Everything beyond your grades.',
  ),
  TourStep(
    'reps',
    5,
    TourPage.more,
    'more.reps',
    'Representatives',
    'Your president and each course\'s CR, with contacts; volunteer to be a '
        'CR.',
  ),
  TourStep(
    'reviews',
    5,
    TourPage.more,
    'more.reviews',
    'Course reviews',
    'Search a course or professor; filter by professor, year and semester.',
  ),
  TourStep(
    'resources',
    5,
    TourPage.more,
    'more.resources',
    'Resources',
    'Department and course links: notes, papers, handouts.',
  ),
  TourStep(
    'leaderboard',
    5,
    TourPage.more,
    'more.leaderboard',
    'Contributor Leaderboard',
    'The top contributors on campus; apply to join from Resources or '
        'Settings.',
  ),
  // 7 Settings
  TourStep(
    'settings',
    6,
    TourPage.home,
    'settingsbtn',
    'Settings icon',
    'Your degree, grade profiles, data and the app.',
  ),
  TourStep(
    'profiles',
    6,
    TourPage.settings,
    'set.profiles',
    'Grade profiles rows',
    'Rename Actual, Expected and Compare.',
  ),
  TourStep(
    'erp',
    6,
    TourPage.settings,
    'set.erp',
    'Import grades from ERP',
    'Fill past semesters from your ERP performance sheet.',
  ),
  TourStep(
    'appearance',
    6,
    TourPage.settings,
    'set.appearance',
    'Appearance and Show Offshoot tab',
    'Light or dark, and hide the Offshoot tab if you do not need it.',
  ),
  TourStep(
    'install',
    6,
    TourPage.settings,
    'set.install',
    'Install app',
    'Add Pointer to your home screen.',
  ),
  TourStep(
    'replay',
    6,
    TourPage.settings,
    'set.replay',
    'Replay the tour',
    'Run this again, or one chapter, any time.',
  ),
];
