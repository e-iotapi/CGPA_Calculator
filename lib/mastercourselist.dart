/// One entry of the master course list, searched by Add course.
class Mastercourselist {
  /// The course title.
  final String title;

  /// The course code.
  final String id;

  /// The course credits.
  final double credits;

  Mastercourselist({
    required this.title,
    required this.id,
    required this.credits,
  });
}

