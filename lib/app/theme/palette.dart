import 'package:cgpa_calculator/app/theme/circle_reveal.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Fill and text colour for one grade chip.
@immutable
class GradeTone {
  const GradeTone(this.fill, this.text);
  final Color fill;
  final Color text;
}

/// Every colour the app paints with, by role.
///
/// Reaches widgets as a [ThemeExtension], so new code reads it with
/// [AppPalette.of]. Code above the app's Theme (the sign-in snackbar, the
/// system bars) reads the global `thm` by the same role names.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.name,
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.text,
    required this.textMuted,
    required this.divider,
    required this.border,
    required this.outline,
    required this.accent,
    required this.icon,
    required this.inverse,
    required this.onInverse,
    required this.hero,
    required this.onHero,
    required this.onHeroMuted,
    required this.navBackground,
    required this.navIcon,
    required this.ahead,
    required this.behind,
  });

  final String name;

  /// Page ground.
  final Color background;

  /// Cards and course rows.
  final Color surface;

  /// Buttons and inputs lifted off the ground.
  final Color surfaceRaised;

  /// Wells set into a surface, e.g. the credits badge on a course row.
  final Color surfaceSunken;

  final Color text;
  final Color textMuted;
  final Color divider;

  /// Strong border, usually drawn at low alpha.
  final Color border;

  /// Hairline outline of unselected pills and buttons.
  final Color outline;

  /// Highlight for text and icons that need to stand out.
  final Color accent;
  final Color icon;

  /// The high-contrast fill of a selected pill, and its label.
  final Color inverse;
  final Color onInverse;

  /// The one accent-filled card per screen (SGPA, offshoot total).
  final Color hero;
  final Color onHero;
  final Color onHeroMuted;

  final Color navBackground;
  final Color navIcon;

  /// Class-average delta. Green/orange rather than green/red so colour-blind
  /// readers can separate them — and the arrow and word carry it regardless.
  final Color ahead;
  final Color behind;

  bool get isDark =>
      ThemeData.estimateBrightnessForColor(background) == Brightness.dark;

  GradeTone gradeTone(String grade) {
    final tones = isDark ? _darkTones : _lightTones;
    return tones[grade] ?? tones['']!;
  }

  /// Amber: something the student should look at — a value they made theirs,
  /// an official change waiting, a reported link.
  GradeTone get noticeTone =>
      isDark
          ? const GradeTone(Color(0xFF3B2F16), Color(0xFFF1C77A))
          : const GradeTone(Color(0xFFFAEFD8), Color(0xFF7A5410));

  /// Tone for a course that exists but does not count (e.g. a dropped
  /// offshoot course).
  GradeTone get mutedTone => (isDark ? _darkTones : _lightTones)['']!;

  static final _themes = <String, ThemeData>{};

  /// Cached per palette [name] (the palettes are `const` singletons):
  /// UI_OPT O1.2, so a theme switch never rebuilds `ColorScheme.fromSeed`.
  ThemeData get materialTheme => _themes[name] ??= _buildTheme();

  ThemeData _buildTheme() {
    final b = isDark ? Brightness.dark : Brightness.light;
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: b,
    ).copyWith(
      primary: inverse,
      onPrimary: onInverse,
      secondary: accent,
      surface: surface,
      onSurface: text,
      onSurfaceVariant: textMuted,
      outline: outline,
      outlineVariant: divider,
      error: behind,
    );
    final base = ThemeData(
      brightness: b,
      colorScheme: scheme,
      fontFamily: TypeScale.family,
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          for (final p in TargetPlatform.values)
            p: const CircleRevealTransitionsBuilder(),
        },
      ),
    );
    TextStyle btn(Color c) =>
        TypeScale.button.copyWith(fontWeight: FontWeight.w700, color: c);
    return base.copyWith(
      scaffoldBackgroundColor: background,
      textTheme: base.textTheme.apply(
        fontFamily: TypeScale.family,
        bodyColor: text,
        displayColor: text,
      ),
      primaryTextTheme: base.primaryTextTheme.apply(
        fontFamily: TypeScale.family,
      ),
      iconTheme: IconThemeData(color: icon),
      dividerColor: divider,
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          textStyle: btn(accent),
          minimumSize: const Size(Sizes.minTouch, Sizes.minTouch),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: inverse,
          foregroundColor: onInverse,
          textStyle: btn(onInverse),
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          side: BorderSide(color: text, width: 1.5),
          textStyle: btn(text),
          shape: const StadiumBorder(),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? hero : surface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? inverse : divider,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? inverse : null,
        ),
        checkColor: WidgetStatePropertyAll(onInverse),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.row),
        ),
        titleTextStyle: TypeScale.section.copyWith(color: text),
        contentTextStyle: TypeScale.body.copyWith(
          color: textMuted,
          fontWeight: FontWeight.w500,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: background,
        dragHandleColor: outline,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: inverse,
        behavior: SnackBarBehavior.floating,
        contentTextStyle: TypeScale.body.copyWith(color: onInverse),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: surface,
        headerForegroundColor: text,
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TypeScale.body.copyWith(
          color: textMuted,
          fontWeight: FontWeight.w500,
        ),
        labelStyle: TypeScale.body.copyWith(color: textMuted),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: text),
      extensions: [this],
      pageTransitionsTheme: base.pageTransitionsTheme,
    );
  }

  static AppPalette of(BuildContext context) =>
      Theme.of(context).extension<AppPalette>() ?? light;

  /// This palette under another name.
  AppPalette renamed(String newName) => AppPalette(
    name: newName,
    background: background,
    surface: surface,
    surfaceRaised: surfaceRaised,
    surfaceSunken: surfaceSunken,
    text: text,
    textMuted: textMuted,
    divider: divider,
    border: border,
    outline: outline,
    accent: accent,
    icon: icon,
    inverse: inverse,
    onInverse: onInverse,
    hero: hero,
    onHero: onHero,
    onHeroMuted: onHeroMuted,
    navBackground: navBackground,
    navIcon: navIcon,
    ahead: ahead,
    behind: behind,
  );

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(AppPalette? other, double t) =>
      other == null || t < 0.5 ? this : other;

  // Legacy name still read by the remaining legacy screens.
  String get theme => name;

  /// The redesign's light mode.
  static const light = AppPalette(
    name: 'Light',
    background: Color(0xFFF2F2EF),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFF2F2EF),
    text: Color(0xFF17170F),
    textMuted: Color(0xFF5E5E54),
    divider: Color(0xFFEBEBE4),
    border: Color(0xFF17170F),
    outline: Color(0xFFD6D6CD),
    accent: Color(0xFF1F5C4D),
    icon: Color(0xFF45453C),
    inverse: Color(0xFF17170F),
    onInverse: Color(0xFFF6F6F2),
    hero: Color(0xFFB4DED0),
    onHero: Color(0xFF17170F),
    onHeroMuted: Color(0xFF24564A),
    navBackground: Color(0xFF17170F),
    navIcon: Color(0xFFB0B0A4),
    ahead: Color(0xFF1F5240),
    behind: Color(0xFF8A4B2A),
  );

  /// The redesign's dark mode.
  static const dark = AppPalette(
    name: 'Dark',
    background: Color(0xFF0D0D0C),
    surface: Color(0xFF1C1C1A),
    surfaceRaised: Color(0xFF1C1C1A),
    surfaceSunken: Color(0xFF262622),
    text: Color(0xFFF4F4EF),
    textMuted: Color(0xFFBDBDB2),
    divider: Color(0xFF2A2A26),
    border: Color(0xFFF4F4EF),
    outline: Color(0xFF3A3A34),
    accent: Color(0xFFCDE8C8),
    icon: Color(0xFFD8D8CD),
    inverse: Color(0xFFF4F4EF),
    onInverse: Color(0xFF0D0D0C),
    hero: Color(0xFFCDE8C8),
    onHero: Color(0xFF14210F),
    onHeroMuted: Color(0xFF14210F),
    navBackground: Color(0xFF1C1C1A),
    navIcon: Color(0xFFADADA2),
    ahead: Color(0xFF7FC9A8),
    behind: Color(0xFFE0A272),
  );

  /// The two user-selectable themes. The names are what `selected_theme`
  /// has always stored for light and dark.
  static final List<AppPalette> named = [
    light.renamed('White'),
    dark.renamed('Black'),
  ];

  /// The palette saved as [saved], after [resolveName].
  static AppPalette byName(String saved) =>
      named.firstWhere((p) => p.name == resolveName(saved));

  /// Maps a saved theme name onto one that still exists. The six colour
  /// themes were removed; each falls back to the mode it resembled.
  static String resolveName(String saved) => switch (saved) {
    'White' || 'Black' => saved,
    'Blue' || 'Coffee' || 'Emerald' || 'Cyberpunk' => 'Black',
    _ => 'White',
  };
}

// A, A-, B, B- and the muted tone are taken from the design boards. C and
// below extend the same scheme: amber for C, the "behind" orange for D and
// under, and neutral for anything that is not a letter grade.
const _lightTones = {
  'A': GradeTone(Color(0xFFCDE8D8), Color(0xFF1F5240)),
  'A-': GradeTone(Color(0xFFDBEBDF), Color(0xFF29614C)),
  'B': GradeTone(Color(0xFFE4E9F2), Color(0xFF33445E)),
  'B-': GradeTone(Color(0xFFEDE7F5), Color(0xFF4A3372)),
  'C': GradeTone(Color(0xFFF4EBD3), Color(0xFF6B5217)),
  'C-': GradeTone(Color(0xFFF4EBD3), Color(0xFF6B5217)),
  'D': GradeTone(Color(0xFFF6E2D6), Color(0xFF8A4B2A)),
  'E': GradeTone(Color(0xFFF6E2D6), Color(0xFF8A4B2A)),
  'NC': GradeTone(Color(0xFFF6E2D6), Color(0xFF8A4B2A)),
  '': GradeTone(Color(0xFFECECE6), Color(0xFF6E6E63)),
};

const _darkTones = {
  'A': GradeTone(Color(0xFF2C4433), Color(0xFFC6E8C0)),
  'A-': GradeTone(Color(0xFF33503B), Color(0xFFCFEBCA)),
  'B': GradeTone(Color(0xFF2B3A4A), Color(0xFFBCD7EC)),
  'B-': GradeTone(Color(0xFF3A3550), Color(0xFFD7CBF5)),
  'C': GradeTone(Color(0xFF463C22), Color(0xFFEED9A0)),
  'C-': GradeTone(Color(0xFF463C22), Color(0xFFEED9A0)),
  'D': GradeTone(Color(0xFF4A3122), Color(0xFFE0A272)),
  'E': GradeTone(Color(0xFF4A3122), Color(0xFFE0A272)),
  'NC': GradeTone(Color(0xFF4A3122), Color(0xFFE0A272)),
  // Matches AppPalette.dark.surfaceSunken/textMuted (BUG-27): the old fill
  // was a hair off surface (0xFF1C1C1A), so GD/W/"–" badges were invisible.
  '': GradeTone(Color(0xFF262622), Color(0xFFBDBDB2)),
};
