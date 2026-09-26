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

/// The semesters offered for [discipline]. Dual-degree codes (B first) run
/// a fifth year.
List<String> semestersFor(String discipline) => [
  ...baseSemesters,
  if (discipline.startsWith('B')) ...['ST 2', '5 - 1', '5 - 2'],
];
