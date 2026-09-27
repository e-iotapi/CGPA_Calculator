import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/catalog/catalog.dart';
import 'package:cgpa_calculator/core/models/offering.dart';
import 'package:cgpa_calculator/core/roles/maintain_store.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:flutter/material.dart';

class _Part {
  _Part(String name, double? outOf, this.date)
    : name = TextEditingController(text: name),
      outOf = TextEditingController(text: outOf == null ? '' : _n(outOf));
  final TextEditingController name, outOf;
  String? date;

  void dispose() {
    name.dispose();
    outOf.dispose();
  }
}

class _Component {
  _Component(
    this.id,
    String name,
    double? weight,
    this.parts,
    this.countBest,
    this.average,
  ) : name = TextEditingController(text: name),
      weight = TextEditingController(text: weight == null ? '' : _n(weight));
  final String id;
  final TextEditingController name, weight;
  final List<_Part> parts;
  int countBest;
  final double? average;

  void dispose() {
    name.dispose();
    weight.dispose();
    for (final p in parts) {
      p.dispose();
    }
  }
}

String _n(double d) =>
    d == d.roundToDouble() ? '${d.toInt()}' : d.toStringAsFixed(1);

double? _num(TextEditingController c) => double.tryParse(c.text.trim());

/// The eval structure editor (§13.2, §13.3): components, weights, parts and
/// best-N rules for one course's offering this term. Ids stay put across
/// renames, so students' marks stay pinned (§5).
class SchemeEditorPage extends StatefulWidget {
  const SchemeEditorPage({
    super.key,
    required this.courseId,
    required this.campus,
    required this.term,
    this.existing,
  });

  final String courseId, campus, term;
  final Offering? existing;

  @override
  State<SchemeEditorPage> createState() => _SchemeEditorPageState();
}

class _SchemeEditorPageState extends State<SchemeEditorPage> {
  late bool _weighted = widget.existing?.weighted ?? true;
  late final _total = TextEditingController(
    text: _n(widget.existing?.totalMarks ?? 100),
  );
  late final List<_Component> _components = [
    for (final c in widget.existing?.components ?? const <OfferedComponent>[])
      _Component(
        c.id,
        c.name,
        c.weight,
        [for (final p in c.parts) _Part(p.name, p.outOf, p.date)],
        c.countBest,
        c.average,
      ),
  ];
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _total.dispose();
    for (final c in _components) {
      c.dispose();
    }
    super.dispose();
  }

  String _freshId() {
    final used = {
      ..._components.map((c) => c.id),
      ...?widget.existing?.components.map((c) => c.id),
    };
    var i = used.length + 1;
    while (used.contains('c$i')) {
      i++;
    }
    return 'c$i';
  }

  double get _assigned =>
      _components.fold(0.0, (s, c) => s + (_num(c.weight) ?? 0));

  /// The offering as typed, or the first problem with it.
  (Offering?, String?) _build() {
    if (_components.isEmpty) return (null, 'Add at least one component.');
    final names = <String>{};
    final comps = <OfferedComponent>[];
    for (final c in _components) {
      final name = c.name.text.trim();
      if (name.isEmpty) return (null, 'Every component needs a name.');
      if (!names.add(name.toLowerCase())) {
        return (null, 'Two components are called “$name”.');
      }
      final w = _num(c.weight);
      if (w == null || w < 0) return (null, '$name: the weight is missing.');
      if (c.parts.isEmpty) return (null, '$name: add what it is out of.');
      final parts = <OfferedPart>[];
      for (final p in c.parts) {
        final outOf = _num(p.outOf);
        if (outOf == null || outOf <= 0) {
          return (null, '$name: every part needs “out of”.');
        }
        parts.add(
          OfferedPart(
            name: c.parts.length == 1 ? '' : p.name.text.trim(),
            outOf: outOf,
            date: p.date,
          ),
        );
      }
      comps.add(
        OfferedComponent(
          id: c.id,
          name: name,
          weight: w,
          parts: parts,
          countBest: c.countBest > parts.length ? 0 : c.countBest,
          average: c.average,
        ),
      );
    }
    final total = _num(_total);
    if (!_weighted && (total == null || total <= 0)) {
      return (null, 'Say what the course is out of.');
    }
    final e = widget.existing;
    return (
      Offering(
        courseId: widget.courseId,
        campus: widget.campus,
        term: widget.term,
        weighted: _weighted,
        totalMarks: _weighted ? 100 : total!,
        components: comps,
        courseAverage: e?.courseAverage,
        professors: e?.professors ?? const [],
        updatedAt: e?.updatedAt ?? 0,
      ),
      null,
    );
  }

  Future<void> _save() async {
    final (o, error) = _build();
    setState(() => _error = error);
    if (o == null) return;
    setState(() => _saving = true);
    try {
      await MaintainStore(roleStore!).save(
        o,
        '${widget.existing?.hasScheme ?? false ? 'Edited' : 'Added'} the '
        '${termLabel(widget.term)} scheme for ${widget.courseId}',
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = problem(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate(_Part part) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDate: DateTime.tryParse(part.date ?? '') ?? now,
    );
    if (d == null) return;
    setState(
      () =>
          part.date =
              '${d.year}-${'${d.month}'.padLeft(2, '0')}-'
              '${'${d.day}'.padLeft(2, '0')}',
    );
  }

  Widget _component(_Component c, AppPalette p) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: AppTextField(
                  controller: c.name,
                  label: 'Component',
                  hint: 'Quiz 1',
                  dense: true,
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                flex: 2,
                child: AppTextField(
                  controller: c.weight,
                  label: _weighted ? 'Weight %' : 'Marks',
                  number: true,
                  dense: true,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.close_rounded),
                onPressed:
                    () => setState(() {
                      _components.remove(c);
                      c.dispose();
                    }),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          for (final part in c.parts)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.xs),
              child: Row(
                children: [
                  if (c.parts.length > 1) ...[
                    Expanded(
                      flex: 3,
                      child: AppTextField(
                        controller: part.name,
                        label: 'Part',
                        dense: true,
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                  ],
                  Expanded(
                    flex: 2,
                    child: AppTextField(
                      controller: part.outOf,
                      label: 'Out of',
                      number: true,
                      dense: true,
                    ),
                  ),
                  TextButton(
                    onPressed: () => _pickDate(part),
                    child: Text(part.date ?? 'Date'),
                  ),
                  if (c.parts.length > 1)
                    IconButton(
                      tooltip: 'Remove part',
                      icon: const Icon(Icons.remove_circle_outline, size: 18),
                      onPressed:
                          () => setState(() {
                            c.parts.remove(part);
                            part.dispose();
                          }),
                    ),
                ],
              ),
            ),
          Wrap(
            spacing: Space.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton.icon(
                onPressed:
                    () => setState(
                      () => c.parts.add(
                        _Part('Part ${c.parts.length + 1}', null, null),
                      ),
                    ),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Part'),
              ),
              if (c.parts.length > 1)
                DropdownButton<int>(
                  value: c.countBest > c.parts.length ? 0 : c.countBest,
                  underline: const SizedBox(),
                  items: [
                    const DropdownMenuItem(value: 0, child: Text('All count')),
                    for (var n = 1; n < c.parts.length; n++)
                      DropdownMenuItem(
                        value: n,
                        child: Text('Best $n of ${c.parts.length}'),
                      ),
                  ],
                  onChanged: (v) => setState(() => c.countBest = v ?? 0),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final assigned = _assigned;
    final title =
        catalog.master.where((m) => m.id == widget.courseId).firstOrNull?.title;
    return PageFrame(
      header: PageHeader(
        eyebrow: '${widget.courseId} · ${termLabel(widget.term).toUpperCase()}',
        title: 'Evaluation scheme',
      ),
      children: [
        if (title != null)
          Text(title, style: TypeScale.body.copyWith(color: p.textMuted)),
        const SizedBox(height: Space.sm),
        ChoicePills<bool>(
          values: const [true, false],
          selected: _weighted,
          label: (w) => w ? 'Percentages' : 'Marks out of a total',
          onSelected: (w) => setState(() => _weighted = w),
        ),
        if (!_weighted) ...[
          const SizedBox(height: Space.sm),
          AppTextField(
            controller: _total,
            label: 'Course out of',
            number: true,
            dense: true,
            onChanged: (_) => setState(() {}),
          ),
        ],
        const SizedBox(height: Space.md),
        for (final c in _components) ...[
          _component(c, p),
          const SizedBox(height: Space.sm),
        ],
        TextButton.icon(
          onPressed:
              () => setState(
                () => _components.add(
                  _Component(
                    _freshId(),
                    '',
                    null,
                    [_Part('', null, null)],
                    0,
                    null,
                  ),
                ),
              ),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add a component'),
        ),
        const SizedBox(height: Space.sm),
        Text(
          _weighted
              ? '${_n(assigned)}% assigned'
                  '${assigned == 100 ? '' : ' · weights usually sum to 100'}'
              : '${_n(assigned)} of ${_total.text} marks assigned',
          style: TypeScale.caption.copyWith(
            color:
                _weighted && assigned != 100 ? p.noticeTone.text : p.textMuted,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: Space.sm),
          Text(_error!, style: TypeScale.caption.copyWith(color: p.behind)),
        ],
        const SizedBox(height: Space.lg),
        PrimaryButton(
          label: _saving ? 'Saving…' : 'Save for everyone',
          onPressed: _saving ? null : _save,
        ),
        const Note(
          'Students taking this course see this scheme. Anyone who changed a '
          'value keeps theirs and is told the official one moved.',
        ),
      ],
    );
  }
}
