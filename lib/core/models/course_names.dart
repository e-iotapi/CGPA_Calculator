/// Display rules for the course map's duplicates (PLAN §2.10). Rows are
/// never rewritten or deleted — a stored grade is keyed on the id as
/// written — so these apply only when matching and showing.
library;

/// [id] with a lowercase `l` in the number read as `1`: "BITS F10l" →
/// "BITS F101".
String normalizeCourseId(String id) {
  final i = id.lastIndexOf(' ');
  return id.substring(0, i + 1) + id.substring(i + 1).replaceAll('l', '1');
}

bool sameCourseId(String a, String b) =>
    normalizeCourseId(a) == normalizeCourseId(b);

/// Codes titled differently across disciplines, shown under one name.
/// Spelling variants ("PS 1", "Practice School-1") collapse to the chart's
/// name; a slash joins two names only where the course was renamed.
/// `MF F221` is deliberately absent: its two titles are different courses.
const courseTitleAliases = {
  'BITS F101': 'Navigating Campus Life and Living Well / Social Conduct',
  'BITS F113': 'General Mathematics I',
  'BITS F221': 'Practice School I',
  'BITS F225': 'Environmental Science / Environmental Studies',
  'BITS K101':
      'Physical Fitness, Health Wellbeing and Creativity / '
      'Physical Well-being and Creativity',
  'PHA F214': 'Anatomy, Physiology and Hygiene',
  'PHA F216': 'Pharmaceutical Formulations I',
  'PHY F111': 'Mechanics, Oscillations and Waves',
};

/// The title to show for a course stored as [id] / [title].
String displayTitle(String id, String title) =>
    courseTitleAliases[normalizeCourseId(id)] ?? title;
