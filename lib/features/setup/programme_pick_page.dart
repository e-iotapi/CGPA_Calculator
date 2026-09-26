import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/models/programmes.dart';
import 'package:cgpa_calculator/shared/widgets/circle_icon_button.dart';
import 'package:flutter/material.dart';

/// A pushed, searchable list of programmes: code badge and full name. Pops
/// with the chosen code.
class ProgrammePickPage extends StatefulWidget {
  const ProgrammePickPage({
    super.key,
    required this.heading,
    required this.options,
    this.selected,
    this.trailing,
    this.note,
  });

  /// "SECOND DEGREE · GOA".
  final String heading;
  final List<Programme> options;
  final String? selected;

  /// Beside each row, e.g. "10 sem".
  final String Function(Programme)? trailing;

  /// Under the list: what runs on another campus.
  final String? note;

  @override
  State<ProgrammePickPage> createState() => _ProgrammePickPageState();
}

class _ProgrammePickPageState extends State<ProgrammePickPage> {
  var _query = '';

  List<Programme> get _shown {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.options;
    return [
      for (final p in widget.options)
        if (p.code.toLowerCase().startsWith(q) ||
            p.name.toLowerCase().contains(q))
          p,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final shown = _shown;
    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                Space.xxl,
                Space.gutter,
                Space.xxl,
              ),
              children: [
                Row(
                  children: [
                    CircleIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Back',
                      size: 44,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.heading,
                            style: TypeScale.label.copyWith(color: p.textMuted),
                          ),
                          Semantics(
                            header: true,
                            child: Text(
                              'Pick a programme',
                              style: TypeScale.title.copyWith(
                                fontSize: 19,
                                color: p.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.md),
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  style: TypeScale.body.copyWith(fontSize: 13, color: p.text),
                  decoration: InputDecoration(
                    hintText: 'Code or name — A7, mechanical…',
                    hintStyle: TypeScale.body.copyWith(
                      fontSize: 13,
                      color: p.textMuted,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: p.textMuted,
                    ),
                    filled: true,
                    fillColor: p.surface,
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(23),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: Space.md),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Material(
                    color: p.surface,
                    child: Column(
                      children: [
                        for (final (i, prog) in shown.indexed) ...[
                          if (i > 0)
                            Divider(
                              height: 1,
                              indent: 13,
                              endIndent: 13,
                              color: p.divider,
                            ),
                          _Row(
                            programme: prog,
                            selected: prog.code == widget.selected,
                            trailing: widget.trailing?.call(prog),
                            onTap: () => Navigator.pop(context, prog.code),
                          ),
                        ],
                        if (shown.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(Space.lg),
                            child: Text(
                              'No programme matches "$_query".',
                              style: TypeScale.caption.copyWith(
                                color: p.textMuted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (widget.note != null) ...[
                  const SizedBox(height: Space.md),
                  Text(
                    widget.note!,
                    style: TypeScale.caption.copyWith(
                      fontSize: 10.5,
                      height: 1.45,
                      color: p.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.programme,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  final Programme programme;
  final bool selected;
  final String? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final gap = programme.gap;
    return Semantics(
      button: true,
      selected: selected,
      label:
          '${programme.code}, ${programme.name}${gap == null ? '' : ', $gap'}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          color: selected ? p.hero : null,
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          child: Row(
            children: [
              CodeBadge(programme.code, strong: selected),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      programme.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TypeScale.body.copyWith(
                        fontSize: 12.5,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w600,
                        color: selected ? p.onHero : p.text,
                      ),
                    ),
                    if (gap != null)
                      Text(
                        gap,
                        style: TypeScale.caption.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: p.behind,
                        ),
                      ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_rounded, size: 16, color: p.onHero)
              else if (trailing != null)
                Text(
                  trailing!,
                  style: TypeScale.caption.copyWith(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: p.textMuted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A programme code in a small rounded badge.
class CodeBadge extends StatelessWidget {
  const CodeBadge(this.code, {super.key, this.strong = false, this.tint});

  final String code;

  /// Ink with mint text, for the chosen one.
  final bool strong;

  /// Mint, for a first degree on the setup card.
  final bool? tint;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      width: 38,
      height: 28,
      decoration: BoxDecoration(
        color:
            strong
                ? p.inverse
                : tint == true
                ? p.hero
                : p.divider,
        borderRadius: BorderRadius.circular(9),
      ),
      alignment: Alignment.center,
      child: Text(
        code,
        style: TypeScale.caption.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color:
              strong
                  ? p.hero
                  : tint == true
                  ? p.onHero
                  : p.text,
        ),
      ),
    );
  }
}
