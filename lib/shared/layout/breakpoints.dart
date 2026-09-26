import 'package:flutter/widgets.dart';

enum WindowSize {
  /// One column, bottom pill nav.
  compact,

  /// Stat cards move into a right rail.
  medium,

  /// Bottom pill becomes a left rail.
  expanded,
}

abstract final class Breakpoints {
  static const double medium = 720;
  static const double expanded = 1100;

  /// Body width cap on wide windows.
  static const double maxContentWidth = 1180;

  static WindowSize of(double width) =>
      width >= expanded
          ? WindowSize.expanded
          : width >= medium
          ? WindowSize.medium
          : WindowSize.compact;
}

extension WindowSizeContext on BuildContext {
  WindowSize get windowSize => Breakpoints.of(MediaQuery.sizeOf(this).width);
}
