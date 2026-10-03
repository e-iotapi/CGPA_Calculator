import 'package:cgpa_calculator/core/models/semesters.dart';

/// Where a student stands at the review gate (BUILDOUT_CONTRACTS.md B6).
/// The UI shows reviews for [open] and [exempt] as well as [unlocked].
enum GateState { open, locked, unlocked, exempt }

/// True only when [currentsem] is after '2 - 1' in [baseSemesters] order.
/// Null or unknown is false; dual-degree extras ('ST 2', '5 - x') are past.
bool pastTwoOne(String? currentsem) {
  if (currentsem == null) return false;
  final i = baseSemesters.indexOf(currentsem);
  if (i >= 0) return i > baseSemesters.indexOf('2 - 1');
  return const ['ST 2', '5 - 1', '5 - 2'].contains(currentsem);
}

/// Reviews a student must write to unlock: min(electives taken, 5).
int required(int electivesTaken) => electivesTaken.clamp(0, 5);

/// The gate state. A student's own reviews are never imported and always
/// carry stars and a would-take answer, so the caller counts all of them.
/// [myReviewCount] counts the caller's own non-imported
/// reviews that have stars and a would-take answer (text optional).
GateState gateState({
  required bool on,
  required String? currentsem,
  required int electivesTaken,
  required int myReviewCount,
}) {
  if (!on) return GateState.open;
  if (!pastTwoOne(currentsem)) return GateState.exempt;
  final need = required(electivesTaken);
  if (need == 0) return GateState.exempt;
  return myReviewCount >= need ? GateState.unlocked : GateState.locked;
}
