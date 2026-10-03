/// The marker path names on a head's `v` map (no '.' allowed: the path is a
/// map key). Offerings keep their own `offerings` map (`bumpOfferings`).
library;

abstract final class Paths {
  static const resources = 'resources';
  static const reps = 'reps';

  /// The review index.
  static const reviews = 'reviews';
  static String reviewsOf(String courseId) => 'reviews/$courseId';
  static String professors(String dept) => 'professors/$dept';
  static const grants = 'grants';

  /// On every head.
  static const owners = 'owners';

  /// On every head.
  static const terms = 'terms';
  static String volunteers(String dept) => 'volunteers/$dept';
  static const staff = 'staff';

  /// The review gate switch (B6).
  static const reviewGate = 'reviewGate';

  /// The broadcast timetable's publish counter (B8b).
  static const timetable = 'timetable';
}
