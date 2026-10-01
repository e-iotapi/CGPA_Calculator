import 'package:cgpa_calculator/core/professors/professor.dart';

/// Two listed professors that are probably one person.
typedef DuplicatePair = ({Professor a, Professor b});

/// Where Merge duplicates fetches its "Possible duplicates" (a UI seam,
/// UI_REBUILD_HANDOFF.md §3). The logic branch points [duplicateSource] at
/// its endpoint; until then [NameDuplicates] pairs the names on screen.
abstract interface class DuplicateSource {
  /// The likely pairs among [listed], the department's professors on
  /// [campus], most likely first.
  Future<List<DuplicatePair>> possible(
    String campus,
    String dept,
    List<Professor> listed,
  );
}

/// The default: [likelySame] (same surname, compatible first initial) over
/// every pair on the list, which is what Add a professor warns with.
List<DuplicatePair> likelyPairs(List<Professor> listed) => [
  for (var i = 0; i < listed.length; i++)
    for (var j = i + 1; j < listed.length; j++)
      if (likelySame(listed[i].name, listed[j].name))
        (a: listed[i], b: listed[j]),
];

class NameDuplicates implements DuplicateSource {
  const NameDuplicates();

  @override
  Future<List<DuplicatePair>> possible(
    String campus,
    String dept,
    List<Professor> listed,
  ) async => likelyPairs(listed);
}

/// The source Merge duplicates reads; tests swap it.
DuplicateSource duplicateSource = const NameDuplicates();
