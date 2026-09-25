import 'package:flutter/widgets.dart';

/// Spacing scale. Every gap and padding in new code comes from here.
abstract final class Space {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// Side padding of a phone-width page.
  static const double gutter = 20;
}

/// Corner radii, smallest to largest.
abstract final class Radii {
  static const double check = 7;
  static const double chip = 12;
  static const double badge = 14;
  static const double row = 22;
  static const double card = 26;
  static const double hero = 30;
  static const double nav = 33;
}

/// Fixed control sizes. Heights are fixed, never a fraction of the screen.
abstract final class Sizes {
  static const double minTouch = 44;
  static const double iconButton = 46;
  static const double pill = 36;
  static const double pillSmall = 34;
  static const double gradeChipHeight = 34;
  static const double gradeChipMinWidth = 42;
  static const double creditBadge = 40;
  static const double nav = 66;
  static const double navItem = 50;
}

abstract final class Motion {
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 350);
}

/// Type scale. Colourless: callers add colour from the palette with
/// `copyWith(color: …)`.
abstract final class TypeScale {
  static const family = 'Montserrat';

  /// Large numbers on stat cards.
  static const display = TextStyle(
    fontFamily: family,
    fontSize: 38,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.6,
    height: 1.05,
  );

  /// Screen title, e.g. the user's name under the greeting.
  static const title = TextStyle(
    fontFamily: family,
    fontSize: 25,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.7,
    height: 1.1,
  );

  /// The sentence-style summary line under the title.
  static const editorial = TextStyle(
    fontFamily: family,
    fontSize: 23,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.6,
    height: 1.24,
  );

  static const section = TextStyle(
    fontFamily: family,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );

  static const body = TextStyle(
    fontFamily: family,
    fontSize: 13.5,
    fontWeight: FontWeight.w600,
    height: 1.25,
  );

  static const button = TextStyle(
    fontFamily: family,
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );

  static const gradeChip = TextStyle(
    fontFamily: family,
    fontSize: 14.5,
    fontWeight: FontWeight.w700,
  );

  /// Upper-case card labels ("SGPA").
  static const label = TextStyle(
    fontFamily: family,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.4,
  );

  static const caption = TextStyle(
    fontFamily: family,
    fontSize: 11,
    fontWeight: FontWeight.w500,
  );
}
