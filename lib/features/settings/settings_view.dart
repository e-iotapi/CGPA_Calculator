import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/features/settings/settings_controller.dart';
import 'package:cgpa_calculator/shared/widgets/circle_icon_button.dart';
import 'package:cgpa_calculator/shared/short_email.dart';
import 'package:flutter/material.dart';

/// Settings, board `Settings`. Stateless: the page owns every action.
class SettingsView extends StatelessWidget {
  const SettingsView({
    super.key,
    required this.name,
    required this.email,
    required this.discipline,
    required this.batch,
    required this.isDark,
    required this.profiles,
    required this.onClose,
    required this.onPickDiscipline,
    this.campus,
    required this.onTheme,
    required this.onRenameProfile,
    required this.onExport,
    required this.onImportOld,
    this.onImportErp,
    required this.onReport,
    required this.onReset,
    required this.onSignOut,
    this.onEmail,
    this.onInstall,
    this.installed = false,
    this.onGithub,
    this.workingAs,
    this.onWorkingAs,
    this.contactSummary,
    this.onContact,
    this.onControls,
    this.showOffshoot = true,
    this.onShowOffshoot,
  });

  final String name;
  final String email;

  /// Four characters, e.g. "B3A7" or "--A7".
  final String discipline;

  /// Two digits.
  final int batch;
  final bool isDark;

  /// Every grade profile's name, profile 1 first.
  final List<String> profiles;
  final VoidCallback onClose;

  /// `dual` picks the first half (the MSc), otherwise the second.
  final ValueChanged<bool> onPickDiscipline;

  /// "Goa"; null until known. Read from the sign-in address and final, like
  /// the batch, so neither row can be tapped (ARCHITECTURE.md §11).
  final String? campus;
  final ValueChanged<bool> onTheme;

  /// 1 or 2.
  final ValueChanged<int> onRenameProfile;
  final VoidCallback onExport;
  final VoidCallback onImportOld;

  /// Imports grades from the ERP performance sheet PDF; web only.
  final VoidCallback? onImportErp;
  final VoidCallback onReport;
  final VoidCallback onReset;
  final VoidCallback onSignOut;
  final VoidCallback? onEmail;

  /// Null hides the row: not on the web.
  final VoidCallback? onInstall;

  /// Running from the home screen; the row still shows, for another device.
  final bool installed;
  final VoidCallback? onGithub;

  /// Your roles (§16.4): shown only for an owner or a live grant. What the
  /// app opens as — "Student", "President · ELEC" — or, for an owner, "Open
  /// as".
  final String? workingAs;
  final VoidCallback? onWorkingAs;

  /// "Email, WhatsApp": what RepProfile holds.
  final String? contactSummary;
  final VoidCallback? onContact;

  /// Owners and admins: the /admin controls.
  final VoidCallback? onControls;

  /// The "Show Offshoot tab" switch (B1 pref); null hides the row.
  final bool showOffshoot;
  final ValueChanged<bool>? onShowOffshoot;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final second = discipline.substring(2, 4);
    final first = discipline.substring(0, 2);

    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, Space.lg, 18, Space.xxl),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          'Settings',
                          style: TypeScale.title.copyWith(color: p.text),
                        ),
                      ),
                    ),
                    CircleIconButton(
                      icon: Icons.close_rounded,
                      tooltip: 'Close',
                      onPressed: onClose,
                    ),
                  ],
                ),
                const SizedBox(height: Space.md),
                _account(p),
                if (onWorkingAs != null) ...[
                  _SectionLabel('YOUR ROLES'),
                  _Group([
                    _Item(
                      label: 'Working as',
                      value: workingAs,
                      strong: true,
                      icon: Icons.swap_horiz_rounded,
                      onTap: onWorkingAs,
                    ),
                    if (onContact != null)
                      _Item(
                        label: 'Contact details',
                        value: contactSummary,
                        icon: Icons.contact_phone_outlined,
                        onTap: onContact,
                      ),
                    if (onControls != null)
                      _Item(
                        label: 'Controls',
                        value: 'Admin',
                        icon: Icons.admin_panel_settings_outlined,
                        onTap: onControls,
                      ),
                  ]),
                ],
                _SectionLabel('ACADEMICS'),
                _Group([
                  _Item(
                    label: 'Discipline',
                    value: shortProgrammeLabel(second),
                    valueTooltip: disciplineLabel(second, dual: false),
                    strong: true,
                    onTap: () => onPickDiscipline(false),
                  ),
                  _Item(
                    label: 'Dual degree',
                    value: shortProgrammeLabel(first),
                    valueTooltip: disciplineLabel(first, dual: true),
                    strong: true,
                    onTap: () => onPickDiscipline(true),
                  ),
                  _Item(label: 'Campus', value: campus ?? 'Not set'),
                  _Item(
                    label: 'Batch',
                    value: '20${batch.toString().padLeft(2, '0')}',
                  ),
                ]),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, Space.xs, 4, 0),
                  child: Text(
                    'Changing the first discipline clears your grades.',
                    style: TypeScale.caption.copyWith(
                      fontSize: 10.5,
                      color: p.behind,
                    ),
                  ),
                ),
                _SectionLabel('APPEARANCE'),
                Row(
                  children: [
                    Expanded(
                      child: _Choice(
                        icon: Icons.light_mode_outlined,
                        label: 'Light',
                        on: !isDark,
                        onTap: () => onTheme(false),
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: _Choice(
                        icon: Icons.dark_mode_outlined,
                        label: 'Dark',
                        on: isDark,
                        onTap: () => onTheme(true),
                      ),
                    ),
                  ],
                ),
                if (onShowOffshoot != null) ...[
                  const SizedBox(height: Space.sm),
                  _Group([
                    _SwitchItem(
                      label: 'Show Offshoot tab',
                      value: showOffshoot,
                      onChanged: onShowOffshoot!,
                    ),
                  ]),
                ],
                _SectionLabel('GRADE PROFILES'),
                _Group([
                  for (final (i, name) in profiles.indexed)
                    _Item(
                      swatch: switch (i) {
                        0 => p.hero,
                        1 => p.gradeTone('B-').fill,
                        _ => p.outline,
                      },
                      label: i < 2 ? 'Profile ${i + 1}' : 'Compare only',
                      value: name,
                      strong: true,
                      onTap: () => onRenameProfile(i + 1),
                    ),
                ]),
                if (onInstall != null) ...[
                  _SectionLabel('APP'),
                  _Group([
                    _Item(
                      icon: Icons.install_mobile_rounded,
                      label: 'Install app',
                      value: installed ? 'Installed' : 'Home screen',
                      onTap: onInstall!,
                    ),
                  ]),
                ],
                _SectionLabel('YOUR DATA'),
                _Group([
                  _Item(
                    icon: Icons.download_rounded,
                    label: 'Export grades',
                    value: '.csv',
                    chevron: false,
                    onTap: onExport,
                  ),
                  if (onImportErp != null)
                    _Item(
                      icon: Icons.school_outlined,
                      label: 'Import grades from ERP',
                      value: '.pdf',
                      chevron: false,
                      onTap: onImportErp!,
                    ),
                  _Item(
                    icon: Icons.content_paste_rounded,
                    label: 'Import from old site',
                    onTap: onImportOld,
                  ),
                ]),
                const SizedBox(height: Space.md),
                Row(
                  children: [
                    Expanded(
                      child: _Choice(label: 'Report a bug', onTap: onReport),
                    ),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: _Choice(
                        label: 'Reset courses',
                        danger: true,
                        onTap: onReset,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final (text, tap) in [
                      ('Email me', onEmail),
                      ('GitHub', onGithub),
                    ])
                      if (tap != null)
                        TextButton(
                          onPressed: tap,
                          child: Text(
                            text,
                            style: TypeScale.caption.copyWith(
                              color: p.accent,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.sm),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Built By Siddharth Mishra',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: p.text,
                          ),
                        ),
                        const TextSpan(
                          text: ' · your grades stay private to your account',
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    style: TypeScale.caption.copyWith(
                      fontSize: 10,
                      height: 1.5,
                      color: p.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _account(AppPalette p) {
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: p.hero,
        borderRadius: BorderRadius.circular(Radii.row),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.onHero,
              borderRadius: BorderRadius.circular(15),
            ),
            child: FittedBox(
              child: Text(
                initial,
                style: TypeScale.title.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: p.hero,
                ),
              ),
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TypeScale.body.copyWith(
                    color: p.onHero,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  shortEmail(email),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TypeScale.caption.copyWith(color: p.onHeroMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: Space.sm),
          Material(
            color: p.onHero,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onSignOut,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: Sizes.minTouch),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      'Sign out',
                      style: TypeScale.caption.copyWith(
                        color: p.hero,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, Space.lg, 4, Space.sm),
    child: Semantics(
      header: true,
      child: Text(
        text,
        style: TypeScale.label.copyWith(
          letterSpacing: 0.9,
          color: AppPalette.of(context).textMuted,
        ),
      ),
    ),
  );
}

/// White card of rows split by hairlines.
class _Group extends StatelessWidget {
  const _Group(this.items);
  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (i, item) in items.indexed) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                indent: 14,
                endIndent: 14,
                color: p.divider,
              ),
            item,
          ],
        ],
      ),
    );
  }
}

/// A row with a switch; the whole row toggles it.
class _SwitchItem extends StatelessWidget {
  const _SwitchItem({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return MergeSemantics(
      child: InkWell(
        onTap: () => onChanged(!value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Sizes.minTouch),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TypeScale.body.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: p.text,
                    ),
                  ),
                ),
                Switch(value: value, onChanged: onChanged),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.label,
    this.onTap,
    this.value,
    this.valueTooltip,
    this.strong = false,
    this.icon,
    this.swatch,
    this.chevron = true,
  });

  final String label;
  final String? value;

  /// The full text, when [value] is shortened (e.g. the discipline code).
  final String? valueTooltip;

  /// Accent the value, for the settings that define the degree.
  final bool strong;
  final IconData? icon;
  final Color? swatch;
  final bool chevron;

  /// Null for a read-only row: not tappable, and no chevron.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: Sizes.minTouch),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: p.text),
              const SizedBox(width: 11),
            ],
            if (swatch != null) ...[
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: swatch,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: _LabelValue(
                label: label,
                value: value,
                valueTooltip: valueTooltip,
                strong: strong,
              ),
            ),
            if (chevron && onTap != null) ...[
              const SizedBox(width: Space.xs),
              Icon(Icons.chevron_right_rounded, size: 18, color: p.textMuted),
            ],
          ],
        ),
      ),
    );
    return onTap == null
        ? MergeSemantics(child: row)
        : InkWell(onTap: onTap, child: row);
  }
}

/// Outlined or filled 44px button, two to a row.
class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.onTap,
    this.icon,
    this.on = false,
    this.danger = false,
  });

  final String label;
  final IconData? icon;
  final bool on;
  final bool danger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final fg = on ? p.onInverse : (danger ? p.behind : p.text);
    return Semantics(
      button: true,
      selected: icon != null ? on : null,
      child: Material(
        color: on ? p.inverse : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side:
              on
                  ? BorderSide.none
                  : BorderSide(
                    color: danger ? p.behind.withValues(alpha: 0.5) : p.outline,
                  ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Sizes.minTouch),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.sm,
                vertical: 6,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: fg),
                    const SizedBox(width: 7),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TypeScale.caption.copyWith(
                        fontSize: 12.5,
                        fontWeight:
                            on || danger ? FontWeight.w700 : FontWeight.w600,
                        color: fg,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A settings label and its value on one line. The label keeps its natural
/// width (up to 60% of the row) so a word like "Discipline" never breaks
/// mid-word; the value takes the rest, right-aligned, and ellipsizes.
class _LabelValue extends StatelessWidget {
  const _LabelValue({
    required this.label,
    this.value,
    this.valueTooltip,
    this.strong = false,
  });

  final String label;
  final String? value;

  /// The full text, when [value] is shortened (e.g. the discipline code).
  final String? valueTooltip;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final labelStyle = TypeScale.body.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: p.text,
    );
    final v = value;
    if (v == null) return Text(label, style: labelStyle);
    return LayoutBuilder(
      builder: (context, c) {
        final painter = TextPainter(
          // Merged as Text merges it, or the measure misses the theme's
          // letter spacing.
          text: TextSpan(
            text: label,
            style: DefaultTextStyle.of(context).style.merge(labelStyle),
          ),
          maxLines: 1,
          textScaler: MediaQuery.textScalerOf(context),
          textDirection: Directionality.of(context),
        )..layout();
        final natural = painter.width + 1;
        painter.dispose();
        return Row(
          children: [
            SizedBox(
              width: natural.clamp(0, c.maxWidth * 0.6).toDouble(),
              child: Text(label, style: labelStyle),
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Builder(
                builder: (context) {
                  final text = Text(
                    v,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    semanticsLabel: valueTooltip ?? v,
                    style: TypeScale.caption.copyWith(
                      fontSize: 12.5,
                      fontWeight: strong ? FontWeight.w700 : FontWeight.w600,
                      color: strong ? p.accent : p.textMuted,
                    ),
                  );
                  return valueTooltip == null
                      ? text
                      : Tooltip(message: valueTooltip, child: text);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
