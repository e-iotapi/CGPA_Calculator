/// Every student's semesters, in chronological order.
const baseSemesters = [
  '1 - 1',
  '1 - 2',
  '2 - 1',
  '2 - 2',
  'PS 1',
  '3 - 1',
  '3 - 2',
  'ST 1',
  '4 - 1',
  '4 - 2',
];

/// A dual degree: both halves of the code are programmes ("B3A7"), where a
/// single degree leaves one as "--" ("B3--", "--A7").
bool isDualDiscipline(String d) =>
    d.length == 4 && d.substring(0, 2) != '--' && d.substring(2) != '--';

/// The semesters offered for [discipline]. Only a dual degree runs a fifth
/// year; a single M.Sc. ends at 4 - 2 like a B.E.
List<String> semestersFor(String discipline) => [
  ...baseSemesters,
  if (isDualDiscipline(discipline)) ...['ST 2', '5 - 1', '5 - 2'],
];
