/// A store refusing a write for a reason the screen words itself (the
/// contract's typed errors). Firestore failures stay `FirebaseException`.
class StoreError implements Exception {
  const StoreError(this.code);

  /// A short machine code ("exists", "badName", "taken").
  final String code;

  @override
  String toString() => '$runtimeType($code)';
}
