/// The layout class of a window width.
enum WindowSize {
  /// One column, bottom pill nav.
  compact,

  /// Stat cards move into a right rail.
  medium,

  /// Bottom pill becomes a left rail.
  expanded,
}

/// The window widths where the layout changes.
abstract final class Breakpoints {
  /// The width from which the layout is [WindowSize.medium].
  static const double medium = 720;

  /// The width from which the layout is [WindowSize.expanded].
  static const double expanded = 1100;

  /// Body width cap on wide windows.
  static const double maxContentWidth = 1180;

  /// The [WindowSize] for a window [width].
  static WindowSize of(double width) =>
      width >= expanded
          ? WindowSize.expanded
          : width >= medium
          ? WindowSize.medium
          : WindowSize.compact;
}
