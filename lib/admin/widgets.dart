/// Pieces every maintainer screen shares, drawn from the admin boards.
library;

import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/card_row.dart';
import 'package:cgpa_calculator/shared/widgets/dashed_outline.dart';
import 'package:cgpa_calculator/shared/widgets/notice.dart';
import 'package:cgpa_calculator/shared/widgets/pill_button.dart';
import 'package:flutter/material.dart';
import 'package:cgpa_calculator/shared/short_email.dart';

import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';

export 'package:cgpa_calculator/shared/short_email.dart';

/// "PEOPLE", "OWNER ONLY": the small caps above a group.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, Space.md, 4, Space.xs),
    child: Text(
      text.toUpperCase(),
      style: TypeScale.label.copyWith(color: AppPalette.of(context).textMuted),
    ),
  );
}

/// A card of rows with hairlines between them.
class RowGroup extends StatelessWidget {
  const RowGroup({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (i, c) in children.indexed) ...[
            if (i > 0)
              Divider(height: 1, indent: 15, endIndent: 15, color: p.divider),
            c,
          ],
        ],
      ),
    );
  }
}

/// Icon, title, a muted line under it, and a chevron; the whole row taps.
class NavRow extends StatelessWidget {
  const NavRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.accent = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  /// The mint square, for the primary action in a group.
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return CardRow(
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: accent ? p.hero : p.surfaceSunken,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, size: 17, color: accent ? p.onHero : p.icon),
      ),
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      onTap: onTap,
    );
  }
}

/// OWNER, ADMIN, PRESIDENT, CR.
class TierTag extends StatelessWidget {
  const TierTag(this.text, {super.key, this.strong = false});
  final String text;

  /// Dark ground: owners and admins, and CRs on the boards.
  final bool strong;

  static TierTag of(GrantRole r) => TierTag(r.tag, strong: r != GrantRole.dept);

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: strong ? p.navBackground : p.hero,
        borderRadius: BorderRadius.circular(11),
        border: strong && p.isDark ? Border.all(color: p.divider) : null,
      ),
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: Text(
          text,
          style: TypeScale.caption.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
            color: strong ? p.hero : p.onHero,
          ),
        ),
      ),
    );
  }
}

/// A campus or scope pill; [muted] for the second, grey one.
class ScopeChip extends StatelessWidget {
  const ScopeChip(
    this.text, {
    super.key,
    this.muted = false,
    this.icon,
    this.height = 26,
  });
  final String text;
  final bool muted;
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: muted ? p.surfaceSunken : p.hero,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: muted ? p.text : p.onHero),
            const SizedBox(width: 5),
          ],
          Text(
            text,
            style: TypeScale.caption.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: muted ? p.text : p.onHero,
            ),
          ),
        ],
      ),
    );
  }
}

/// Every maintainer screen wears its scope in the header (§13): a campus
/// pill and a department or course pill.
class ScopePills extends StatelessWidget {
  const ScopePills({super.key, required this.campus, this.scope});
  final String campus;
  final String? scope;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      ScopeChip(campusName(campus), icon: Icons.place_outlined),
      if (scope != null) ScopeChip(scope!, muted: true),
    ],
  );
}

/// A small muted paragraph under a group.
class Note extends StatelessWidget {
  const Note(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, Space.sm, 4, 0),
    child: Text(
      text,
      style: TypeScale.caption.copyWith(
        fontSize: 11,
        height: 1.45,
        color: AppPalette.of(context).textMuted,
      ),
    ),
  );
}

/// A row of choices, one selected, flexing to the width.
class ChoicePills<T> extends StatelessWidget {
  const ChoicePills({
    super.key,
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
    this.equal = false,
    this.count,
  });

  final List<T> values;
  final T? selected;
  final String Function(T) label;
  final ValueChanged<T> onSelected;

  /// Equal-width children in a `Row`, for tab rows. A hugging `Wrap`
  /// otherwise.
  final bool equal;

  /// An optional trailing count, shown after the label as " 214".
  final String Function(T)? count;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    Widget pill(T v) {
      final on = v == selected;
      final n = count?.call(v);
      final text = Text(
        n == null ? label(v) : '${label(v)} $n',
        maxLines: equal ? 1 : null,
        style: TypeScale.body.copyWith(
          fontSize: 12.5,
          fontWeight: on ? FontWeight.w700 : FontWeight.w600,
          color: on ? p.onInverse : p.text,
        ),
      );
      return Semantics(
        selected: on,
        button: true,
        label: n == null ? label(v) : '${label(v)} $n',
        child: Material(
          color: on ? p.inverse : Colors.transparent,
          shape: StadiumBorder(
            side: on ? BorderSide.none : BorderSide(color: p.border),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => onSelected(v),
            child: Container(
              height: Sizes.pill,
              constraints: const BoxConstraints(minWidth: 44),
              // Equal tabs share the width, so they keep only a little
              // padding of their own (§10.1 item 2).
              padding: EdgeInsets.symmetric(horizontal: equal ? 4 : 14),
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                // An equal tab shrinks its label rather than break a word.
                child:
                    equal
                        ? FittedBox(fit: BoxFit.scaleDown, child: text)
                        : text,
              ),
            ),
          ),
        ),
      );
    }

    if (equal) {
      return Row(
        children: [
          for (final (i, v) in values.indexed) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(child: pill(v)),
          ],
        ],
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [for (final v in values) pill(v)],
    );
  }
}

/// "12 minutes ago", "Yesterday, 18:40", "3 days ago", "27 Sep".
String ago(DateTime? at, {DateTime? now}) {
  if (at == null) return 'just now';
  final n = now ?? DateTime.now();
  final d = n.difference(at);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) {
    return '${d.inMinutes} minute${d.inMinutes == 1 ? '' : 's'} ago';
  }
  if (d.inHours < 24 && n.day == at.day) {
    return '${d.inHours} hour${d.inHours == 1 ? '' : 's'} ago';
  }
  if (d.inDays < 2) {
    return 'Yesterday, ${at.hour.toString().padLeft(2, '0')}:'
        '${at.minute.toString().padLeft(2, '0')}';
  }
  if (d.inDays < 14) return '${d.inDays} days ago';
  return shortDay(at);
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "27 Sep 2027", or "27 Sep" when [year] is false.
String shortDay(DateTime d, {bool year = false}) =>
    '${d.day} ${_months[d.month - 1]}${year ? ' ${d.year}' : ''}';

/// A failed load or save, said plainly. Never includes the raw exception.
String problem(Object e) {
  final s = '$e';
  if (s.contains('permission-denied')) {
    return 'Not allowed. Your access may have ended; sign in again or ask an '
        'owner.';
  }
  if (s.contains('unavailable') || s.contains('network')) {
    return 'No connection. Nothing was changed.';
  }
  if (s.contains('failed-precondition')) {
    return 'This list needs a database update an owner has to deploy. Try '
        'again later.';
  }
  debugPrint('$e');
  return "Couldn't load this. Try again.";
}

/// Loads [load] and shows a spinner, the error, or [builder]'s result.
class Loaded<T> extends StatefulWidget {
  const Loaded({super.key, required this.load, required this.builder});
  final Future<T> Function() load;
  final Widget Function(BuildContext, T, VoidCallback reload) builder;

  @override
  State<Loaded<T>> createState() => _LoadedState<T>();
}

class _LoadedState<T> extends State<Loaded<T>> {
  late Future<T> _f = widget.load();

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: _f,
    builder: (context, s) {
      if (s.hasError) {
        // A rebuild (and FutureBuilder's own re-subscription) only happens
        // on the next frame, so ignore() keeps a synchronously-rejected
        // reload from being flagged as an unhandled Future error first.
        void reload() => setState(() {
          _f = widget.load()..ignore();
        });
        return Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Notice(text: TextSpan(text: problem(s.error!)), warning: true),
              const SizedBox(height: Space.sm),
              SizedBox(
                height: Sizes.minTouch,
                child: OutlinedButton(
                  onPressed: reload,
                  child: const Text('Try again'),
                ),
              ),
            ],
          ),
        );
      }
      if (s.connectionState != ConnectionState.done) {
        return const Padding(
          padding: EdgeInsets.all(Space.xxl),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      return widget.builder(context, s.data as T, () {
        setState(() {
          _f = widget.load()..ignore();
        });
      });
    },
  );
}

/// Reports [child]'s laid-out size after every layout, without affecting
/// it.
class _MeasureSize extends SingleChildRenderObjectWidget {
  const _MeasureSize({required this.onChange, required Widget super.child});
  final ValueChanged<Size> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasureSize(onChange);
}

class _RenderMeasureSize extends RenderProxyBox {
  _RenderMeasureSize(this.onChange);
  final ValueChanged<Size> onChange;
  Size? _last;

  @override
  void performLayout() {
    super.performLayout();
    final newSize = child?.size ?? Size.zero;
    if (_last == newSize) return;
    _last = newSize;
    WidgetsBinding.instance.addPostFrameCallback((_) => onChange(newSize));
  }
}

/// A label beside a trailing action, that stacks under it instead of
/// squeezing when there isn't 96 px to spare (N4).
class LabelRow extends StatefulWidget {
  const LabelRow({super.key, required this.label, required this.trailing});
  final Widget label;
  final Widget trailing;

  @override
  State<LabelRow> createState() => _LabelRowState();
}

class _LabelRowState extends State<LabelRow> {
  double? _trailingWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final measured = _MeasureSize(
        onChange: (size) {
          if (mounted && _trailingWidth != size.width) {
            setState(() => _trailingWidth = size.width);
          }
        },
        child: widget.trailing,
      );
      final stack = _trailingWidth != null && c.maxWidth - _trailingWidth! < 96;
      if (stack) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            widget.label,
            const SizedBox(height: 6),
            Align(alignment: Alignment.centerRight, child: measured),
          ],
        );
      }
      return Row(
        children: [
          Expanded(child: widget.label),
          const SizedBox(width: 8),
          measured,
        ],
      );
    },
  );
}

/// "f20230456@goa" — the part before the domain, for the Audit log.
/// A name, then its email in the short campus form (`f20190001@goa`); the
/// name keeps up to 60% of the row (N5).
class NameEmail extends StatelessWidget {
  const NameEmail(this.name, this.email, {super.key});
  final String name;
  final String email;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return LayoutBuilder(
      builder:
          (context, c) => Row(
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: c.maxWidth * 0.6),
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TypeScale.body.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  shortEmail(email),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: TypeScale.caption.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: p.textMuted,
                  ),
                ),
              ),
            ],
          ),
    );
  }
}

/// The header of a manager home (Controls, Your department; §10.1 item 3):
/// eyebrow and a 27/800 title, with Back to Pointer on the right.
class ManagerHomeHeader extends StatelessWidget {
  const ManagerHomeHeader({
    super.key,
    required this.eyebrow,
    required this.title,
  });
  final String eyebrow, title;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final eyebrowText = Text(
      eyebrow,
      style: TypeScale.label.copyWith(color: p.textMuted),
    );
    final titleText = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TypeScale.title.copyWith(
        fontSize: 27,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
      ),
    );
    final back = PillButton(
      label: 'Back to Pointer',
      icon: Icons.arrow_back_rounded,
      padding: 12,
      onPressed: () {
        final nav = Navigator.of(context);
        if (nav.canPop()) {
          nav.pop();
        } else {
          GoRouter.maybeOf(context)?.go('/');
        }
      },
    );
    // Large text: the button gets a line of its own, so the eyebrow and the
    // title keep the full width.
    if (MediaQuery.textScalerOf(context).scale(10) > 12) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(alignment: Alignment.centerRight, child: back),
          const SizedBox(height: 6),
          eyebrowText,
          const SizedBox(height: 2),
          titleText,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [eyebrowText, const SizedBox(height: 2), titleText],
          ),
        ),
        const SizedBox(width: Space.sm),
        back,
      ],
    );
  }
}

/// A 44-tall select: the choice and a chevron, opening a sheet (not a
/// Material dropdown).
class SelectRow extends StatelessWidget {
  const SelectRow({
    super.key,
    required this.text,
    required this.onTap,
    this.placeholder = false,
  });
  final String text;
  final VoidCallback onTap;
  final bool placeholder;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Material(
      color: p.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: p.outline),
      ),
      child: InkWell(
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    text,
                    style: TypeScale.body.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: placeholder ? p.textMuted : p.text,
                    ),
                  ),
                ),
                Icon(Icons.expand_more_rounded, color: p.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// An underlined text action with a 44 px target.
class TextLink extends StatelessWidget {
  const TextLink(this.text, {super.key, required this.onTap});
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      child: Center(
        child: Text(
          text,
          style: TypeScale.caption.copyWith(
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.underline,
            color: AppPalette.of(context).text,
          ),
        ),
      ),
    ),
  );
}

/// An outlined amber pill, 34 tall: the quiet answer to a report.
class AmberPill extends StatelessWidget {
  const AmberPill(this.label, {super.key, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppPalette.of(context).noticeTone;
    return Material(
      color: Colors.transparent,
      shape: StadiumBorder(side: BorderSide(color: t.text, width: 1.2)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TypeScale.body.copyWith(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: t.text,
            ),
          ),
        ),
      ),
    );
  }
}

/// The ink card in both modes: a mint eyebrow, then a line of [text] or
/// any [children].
class InkCard extends StatelessWidget {
  const InkCard({
    super.key,
    required this.eyebrow,
    this.text,
    this.children = const [],
  });
  final String eyebrow;
  final String? text;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return AppCard(
      color: p.navBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: TypeScale.label.copyWith(color: p.hero, letterSpacing: 1.2),
          ),
          const SizedBox(height: 6),
          if (text != null)
            Text(
              text!,
              style: TypeScale.caption.copyWith(height: 1.45, color: p.navIcon),
            ),
          ...children,
        ],
      ),
    );
  }
}

/// A row's leading icon on a 34 px rounded tile; amber for an action that
/// needs care (Hand over).
class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, this.amber = false, this.mint = false});
  final IconData icon;
  final bool amber, mint;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final t = p.noticeTone;
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color:
            amber
                ? t.fill
                : mint
                ? p.hero
                : p.surfaceSunken,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(
        icon,
        size: 17,
        color:
            amber
                ? t.text
                : mint
                ? p.onHero
                : p.icon,
      ),
    );
  }
}

/// A 20 tall chip for a fact about a row: filled, or dashed for something
/// not there yet ("No scheme yet", "no avg").
class MiniChip extends StatelessWidget {
  const MiniChip(
    this.text, {
    super.key,
    this.fill,
    this.ink,
    this.dashed = false,
  });
  final String text;
  final Color? fill, ink;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final box = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 20),
      child: Center(
        widthFactor: 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            text,
            maxLines: 1,
            style: TypeScale.caption.copyWith(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: ink ?? p.textMuted,
            ),
          ),
        ),
      ),
    );
    return dashed
        ? DashedOutline(color: p.textMuted, radius: 10, child: box)
        : DecoratedBox(
          decoration: BoxDecoration(
            color: fill ?? p.surfaceSunken,
            borderRadius: BorderRadius.circular(10),
          ),
          child: box,
        );
  }
}
