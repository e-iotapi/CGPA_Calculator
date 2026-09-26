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

/// Codes spelled differently across disciplines, shown as one entry.
/// `MF F221` is deliberately absent: its two titles are different courses.
const courseTitleAliases = {
  'BITS F101': 'Navigating Campus Life and Living Well / Social Conduct',
  'BITS F113': 'Gen Maths 1 / General Mathematics I',
  'BITS F221':
      'PS 1 / Practice School I / Practice School-1 / Practice SchoolI',
  'BITS F225': 'Environmental Science / Environmental Studies',
  'BITS K101':
      'Physical Fitness, Health Wellbeing and Creativity / '
      'Physical Well-being and Creativity',
  'PHA F214': 'Anatomy Physio and Hygiene / Anatomy, Physiology, & Hygiene',
  'PHA F216': 'Pharmaceutical Formulations 1 / Pharmaceutical Formulations I',
  'PHY F111':
      'Mechanical Oscillations and Waves / Mechanics, Oscillations and Waves',
};

/// The title to show for a course stored as [id] / [title].
String displayTitle(String id, String title) =>
    courseTitleAliases[normalizeCourseId(id)] ?? title;
