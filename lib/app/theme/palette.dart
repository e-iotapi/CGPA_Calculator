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
/// [AppPalette.of]. Old code still reads the global `thm` through the legacy
/// getters at the bottom (`backcolor`, `textcolor`…), which map onto the roles
/// one-to-one; they go once the globals are migrated.
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

  /// Builds a palette from one of the original nine-colour themes, deriving
  /// the roles those themes never had.
  factory AppPalette.legacy({
    required String theme,
    required Color backcolor,
    required Color textcolor,
    required Color sepcolor,
    required Color highcolor,
    required Color cardcolor,
    required Color bordcolor,
    required Color unscolor,
    required Color butcolor,
    required Color iconcolor,
  }) {
    final dark =
        ThemeData.estimateBrightnessForColor(backcolor) == Brightness.dark;
    final base = dark ? AppPalette.dark : AppPalette.light;
    return AppPalette(
      name: theme,
      background: backcolor,
      surface: cardcolor,
      surfaceRaised: butcolor,
      surfaceSunken: backcolor,
      text: textcolor,
      textMuted: unscolor,
      divider: sepcolor,
      border: bordcolor,
      outline: bordcolor.withValues(alpha: 0.2),
      accent: highcolor,
      icon: iconcolor,
      inverse: textcolor,
      onInverse: backcolor,
      hero: Color.alphaBlend(highcolor.withValues(alpha: 0.22), cardcolor),
      onHero: textcolor,
      onHeroMuted: unscolor,
      navBackground: butcolor,
      navIcon: unscolor,
      ahead: base.ahead,
      behind: base.behind,
    );
  }

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

  /// Tone for a course that exists but does not count (e.g. a dropped
  /// offshoot course).
  GradeTone get mutedTone => (isDark ? _darkTones : _lightTones)['']!;

  ThemeData get materialTheme => ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: accent),
    extensions: [this],
  );

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

  // Legacy names, one per original `Constants` field.
  String get theme => name;
  Color get backcolor => background;
  Color get textcolor => text;
  Color get sepcolor => divider;
  Color get highcolor => accent;
  Color get cardcolor => surface;
  Color get bordcolor => border;
  Color get unscolor => textMuted;
  Color get butcolor => surfaceRaised;
  Color get iconcolor => icon;

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

  /// The user-selectable themes. White and Black are the redesign; the rest
  /// are unchanged from the original `constants.dart`.
  static final List<AppPalette> named = [
    // White and Black were the original light and dark themes; they now
    // carry the redesign's palettes under their old names, so a saved
    // selection keeps working.
    light.renamed('White'),
    dark.renamed('Black'),
    AppPalette.legacy(
      theme: "Blue",
      backcolor: Color(0xFF01011C),
      butcolor: Color(0xFF0A0A44),
      bordcolor: Color(0xFF9D9C9C),
      cardcolor: Color(0xFF010125),
      textcolor: Color(0xFF4090B2),
      sepcolor: Color(0xFF0F2628),
      highcolor: Color(0xFFBF3E0B),
      unscolor: Colors.white38,
      iconcolor: Color(0xFF645E69),
    ),
    AppPalette.legacy(
      theme: "Lilac",
      backcolor: Color(0xFFE5C2EF),
      butcolor: Color(0xFFE1B1EF),
      bordcolor: Color(0xFF0C0C0C),
      cardcolor: Color(0xFFE1BEEC),
      textcolor: Color(0xFF1F1717),
      sepcolor: Color(0xFF757575),
      highcolor: Color(0xFF0D57E1),
      unscolor: Color(0xFF766B80),
      iconcolor: Color(0xE21E1D21),
    ),
    AppPalette.legacy(
      theme: "Coffee",
      backcolor: Color(0xF7492E18),
      butcolor: Color(0xFF593C22),
      bordcolor: Color(0xFFD2B478),
      cardcolor: Color(0xFF56371D),
      highcolor: Color(0xFFEAC578),
      sepcolor: Color(0xFFC4A875),
      textcolor: Color(0xFFFCE2BD),
      unscolor: Color(0xFF917752),
      iconcolor: Color(0xFFF6D6A7),
    ),
    AppPalette.legacy(
      theme: "Emerald",
      backcolor: Color(0xFF0E4D43),
      butcolor: Color(0xFF136753),
      bordcolor: Color(0xFFCECBCB),
      cardcolor: Color(0xFF0E574C),
      textcolor: Color(0xFFC4D2CB),
      sepcolor: Color(0xFF38936E),
      highcolor: Color(0xFF1EE67B),
      unscolor: Color(0x996D9C8C),
      iconcolor: Color(0xFF9FE1D6),
    ),
    AppPalette.legacy(
      theme: "Cyberpunk",
      backcolor: Color(0xFF2E1A44),
      butcolor: Color(0xFF421F58),
      bordcolor: Color(0xFF6C597E),
      cardcolor: Color(0xFF361F4F),
      textcolor: Color(0xFFD381BB),
      sepcolor: Color(0xFF7F3E75),
      highcolor: Color(0xFFD4A5E1),
      unscolor: Color(0x99765C85),
      iconcolor: Color(0xFF9A5B95),
    ),
    AppPalette.legacy(
      theme: "Mint",
      backcolor: Color(0xFFB3D7D1),
      butcolor: Color(0xFFA2C8C3),
      bordcolor: Color(0xFF5D7D7B),
      cardcolor: Color(0xFFABD2CE),
      textcolor: Color(0xFF294F4B),
      sepcolor: Color(0xFF3A4F4D),
      highcolor: Color(0xFF053F3C),
      unscolor: Color(0xFF6F7E7B),
      iconcolor: Color(0xFF486B68),
    ),
  ];
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
  '': GradeTone(Color(0xFF232320), Color(0xFFADADA2)),
};
