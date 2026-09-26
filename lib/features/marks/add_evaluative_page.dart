import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/grading/marks.dart';
import 'package:cgpa_calculator/core/models/marks.dart';
import 'package:cgpa_calculator/core/storage/marks.dart';
import 'package:cgpa_calculator/features/marks/marks_format.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/circle_icon_button.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:cgpa_calculator/shared/widgets/pill_button.dart';
import 'package:flutter/material.dart';

/// Add or edit one evaluative: a single mark, or several parts of which all
/// or the best N count.
class AddEvaluativePage extends StatefulWidget {
  const AddEvaluativePage({
    super.key,
    required this.courseId,
    required this.weighted,
    required this.unassigned,
    this.existing,
    this.existingKey,
  });

  final String courseId;
  final bool weighted;

  /// Weight not yet given to any other evaluative.
  final double unassigned;
  final Evaluative? existing;
  final String? existingKey;

  @override
  State<AddEvaluativePage> createState() => _AddEvaluativePageState();
}

class _PartFields {
  _PartFields([EvalPart? p])
    : name = TextEditingController(text: p?.name ?? ''),
      marks = TextEditingController(
        text: p?.marks == null ? '' : marks2(p!.marks!),
      ),
      outOf = TextEditingController(text: p == null ? '' : marks2(p.outOf)),
      date = p?.date;

  final TextEditingController name, marks, outOf;
  String? date;

  EvalPart? toPart(bool single) {
    final o = double.tryParse(outOf.text);
    if (o == null || o <= 0) return null;
    return EvalPart(
      name: single ? '' : name.text.trim(),
      marks: double.tryParse(marks.text),
      outOf: o,
      date: date,
    );
  }

  void dispose() {
    name.dispose();
    marks.dispose();
    outOf.dispose();
  }
}

class _AddEvaluativePageState extends State<AddEvaluativePage> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _weight = TextEditingController(
    text: widget.existing == null ? '' : marks2(widget.existing!.weight),
  );
  late final List<_PartFields> _parts = [
    for (final p in widget.existing?.parts ?? const <EvalPart>[])
      _PartFields(p),
  ];
  late bool _several = (widget.existing?.parts.length ?? 1) > 1;
  late int _best = widget.existing?.countBest ?? 0;

  @override
  void initState() {
    super.initState();
    if (_parts.isEmpty) _parts.add(_PartFields());
    if (_several && _parts.length < 2) _parts.add(_PartFields());
  }

  @override
  void dispose() {
    _name.dispose();
    _weight.dispose();
    for (final p in _parts) {
      p.dispose();
    }
    super.dispose();
  }

  List<_PartFields> get _active => _several ? _parts : _parts.take(1).toList();

  /// The evaluative as currently entered, or null if it cannot be saved.
  Evaluative? get _draft {
    final w = double.tryParse(_weight.text);
    final parts = [for (final f in _active) f.toPart(!_several)];
    if (_name.text.trim().isEmpty || w == null || w <= 0) return null;
    if (parts.any((p) => p == null)) return null;
    return Evaluative(
      courseId: widget.courseId,
      name: _name.text.trim(),
      weight: w,
      parts: parts.cast<EvalPart>(),
      countBest: _several && _best < parts.length ? _best : 0,
    );
  }

  Future<void> _save() async {
    final e = _draft;
    if (e == null) return;
    await saveEvaluative(e, key: widget.existingKey);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    await deleteEvaluative(widget.existingKey!);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickDate(_PartFields f) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(f.date ?? '') ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (d != null) setState(() => f.date = isoDate(d));
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final muted = TypeScale.caption.copyWith(color: p.textMuted, height: 1.4);
    final n = _active.length;
    final draft = _draft;
    final unassigned = widget.unassigned - (double.tryParse(_weight.text) ?? 0);

    return PageFrame(
      header: PageHeader(
        eyebrow: widget.courseId,
        title: widget.existing == null ? 'Add evaluative' : 'Edit evaluative',
        actions: [
          if (widget.existingKey != null)
            CircleIconButton(
              icon: Icons.delete_outline_rounded,
              tooltip: 'Delete evaluative',
              onPressed: _delete,
              size: 42,
            ),
        ],
      ),
      children: [
        AppTextField(
          controller: _name,
          label: 'Component name',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: Space.md),
        AppTextField(
          controller: _weight,
          label: widget.weighted ? 'Weight of the course' : 'Marks it is worth',
          suffix: widget.weighted ? '%' : 'marks',
          number: true,
          onChanged: (_) => setState(() {}),
        ),
        if (widget.weighted) ...[
          const SizedBox(height: 6),
          Text(
            unassigned >= 0
                ? '${marks2(unassigned)}% still unassigned'
                : '${marks2(-unassigned)}% over 100',
            style: muted,
          ),
        ],
        const FieldLabel('Structure'),
        Row(
          children: [
            for (final several in [false, true]) ...[
              if (several) const SizedBox(width: Space.sm),
              Expanded(
                child: PillButton(
                  label: several ? 'Several parts' : 'One mark',
                  selected: _several == several,
                  expand: true,
                  height: 42,
                  onPressed:
                      () => setState(() {
                        _several = several;
                        if (several && _parts.length < 2) {
                          _parts.add(_PartFields());
                        }
                      }),
                ),
              ),
            ],
          ],
        ),
        if (_several && n >= 2) ...[
          const FieldLabel('How many count'),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (var k = n; k >= 1; k--)
                PillButton(
                  label: k == n ? 'All $n' : 'Best $k of $n',
                  selected: (_best == 0 || _best >= n) ? k == n : _best == k,
                  onPressed: () => setState(() => _best = k == n ? 0 : k),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (_best > 0 && _best < n)
            Text(
              'The lowest scoring part is dropped automatically, and keeps '
              'updating as you enter marks.',
              style: muted,
            ),
        ],
        FieldLabel(_several ? 'Parts' : 'Marks'),
        if (_several)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: Text('name · date · marks · out of', style: muted),
          ),
        for (final (i, f) in _active.indexed) ...[
          _partRow(f, i),
          const SizedBox(height: Space.sm),
        ],
        if (!_several) ...[
          _DateField(
            date: _parts.first.date,
            label: 'Date',
            onPick: () => _pickDate(_parts.first),
            onClear: () => setState(() => _parts.first.date = null),
          ),
          const SizedBox(height: 6),
        ],
        Text('Give it a date to see it on the calendar.', style: muted),
        const SizedBox(height: Space.sm),
        if (draft != null && droppedParts(draft).isNotEmpty)
          Text(
            '${droppedParts(draft).map((d) => d.name.isEmpty ? 'A part' : d.name).join(', ')} '
            '${droppedParts(draft).length == 1 ? 'is' : 'are'} currently dropped.',
            style: muted,
          ),
        if (_several)
          TextButton.icon(
            onPressed: () => setState(() => _parts.add(_PartFields())),
            icon: Icon(Icons.add_rounded, color: p.text, size: 18),
            label: Text(
              'Add another part',
              style: TypeScale.button.copyWith(
                fontWeight: FontWeight.w700,
                color: p.text,
              ),
            ),
          ),
        const SizedBox(height: Space.md),
        _preview(draft, p),
        const SizedBox(height: Space.lg),
        PrimaryButton(
          label: 'Save evaluative',
          onPressed: draft == null ? null : _save,
        ),
      ],
    );
  }

  Widget _partRow(_PartFields f, int i) {
    final p = AppPalette.of(context);
    void changed(String _) => setState(() {});
    final numbers = Row(
      children: [
        Expanded(
          child: AppTextField(
            controller: f.marks,
            label: 'Marks',
            number: true,
            dense: true,
            onChanged: changed,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text('/', style: TextStyle(color: p.textMuted)),
        ),
        Expanded(
          child: AppTextField(
            controller: f.outOf,
            label: 'Out of',
            number: true,
            dense: true,
            onChanged: changed,
          ),
        ),
      ],
    );
    if (!_several) return numbers;
    return AppCard(
      padding: const EdgeInsets.all(10),
      radius: 16,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: f.name,
                  label: 'Part ${i + 1} name',
                  dense: true,
                  onChanged: changed,
                ),
              ),
              const SizedBox(width: 6),
              _DateField(
                date: f.date,
                label: 'Part ${i + 1} date',
                compact: true,
                onPick: () => _pickDate(f),
                onClear: () => setState(() => f.date = null),
              ),
              if (_parts.length > 2)
                IconButton(
                  tooltip: 'Remove part ${i + 1}',
                  onPressed:
                      () => setState(() {
                        _parts.removeAt(i).dispose();
                        if (_best >= _parts.length) _best = 0;
                      }),
                  icon: Icon(Icons.close_rounded, color: p.textMuted, size: 18),
                ),
            ],
          ),
          const SizedBox(height: 6),
          numbers,
        ],
      ),
    );
  }

  Widget _preview(Evaluative? d, AppPalette p) {
    final value = d == null ? null : contribution(d);
    final counted = d == null ? const <EvalPart>[] : countedParts(d);
    final got = counted.fold(0.0, (s, x) => s + x.marks!);
    final max = counted.fold(0.0, (s, x) => s + x.outOf);
    final how =
        d == null
            ? 'Fill in a name, a weight and each part\'s maximum.'
            : counted.isEmpty
            ? 'Nothing graded yet — it counts once a mark is in.'
            : '${d.countBest > 0 ? 'best ${d.countBest} of ${d.parts.length}' : 'all counted'}'
                ' → ${marks2(got)} of ${marks2(max)}, the counted parts\' '
                'own maximums';
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: p.hero,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'THIS COMPONENT GIVES YOU',
            style: TypeScale.label.copyWith(color: p.onHeroMuted),
          ),
          const SizedBox(height: 4),
          Text(how, style: TypeScale.caption.copyWith(color: p.onHeroMuted)),
          const SizedBox(height: 4),
          Text(
            value == null
                ? '—'
                : '${value.toStringAsFixed(2)} / ${marks2(d!.weight)}',
            style: TypeScale.display.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: p.onHero,
            ),
          ),
        ],
      ),
    );
  }
}

/// Looks like the inputs around it; opens the date picker. Set, it shows the
/// date and a button to clear it.
class _DateField extends StatelessWidget {
  const _DateField({
    required this.date,
    required this.label,
    required this.onPick,
    required this.onClear,
    this.compact = false,
  });

  /// ISO date, or null.
  final String? date;
  final String label;
  final VoidCallback onPick;
  final VoidCallback onClear;

  /// Beside a part's name: just the date.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final set = date != null;
    final text =
        set
            ? shortDate(date!)
            : compact
            ? 'Date'
            : 'Add a date';
    final pick = InkWell(
      onTap: onPick,
      child: Semantics(
        button: true,
        label: set ? '$label, ${shortDate(date!)}' : label,
        excludeSemantics: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Sizes.minTouch),
          child: Padding(
            padding: EdgeInsets.only(left: 10, right: set ? 2 : 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.event_outlined,
                  size: 17,
                  color: set ? p.text : p.textMuted,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TypeScale.caption.copyWith(
                      fontSize: 12.5,
                      fontWeight: set ? FontWeight.w600 : FontWeight.w500,
                      color: set ? p.text : p.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final field = Material(
      color: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: p.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        children: [
          if (compact) Flexible(child: pick) else Expanded(child: pick),
          if (set)
            IconButton(
              tooltip: 'Clear date',
              visualDensity: VisualDensity.compact,
              onPressed: onClear,
              icon: Icon(Icons.close_rounded, size: 16, color: p.textMuted),
            ),
        ],
      ),
    );
    // Beside a name the row gives no width limit of its own.
    return compact
        ? ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 128),
          child: field,
        )
        : field;
  }
}
