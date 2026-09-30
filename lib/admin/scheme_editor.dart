import 'package:cgpa_calculator/admin/offering_scale.dart';
import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/catalog/catalog.dart';
import 'package:cgpa_calculator/core/grading/marks.dart';
import 'package:cgpa_calculator/core/models/offering.dart';
import 'package:cgpa_calculator/core/roles/maintain_store.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:flutter/material.dart';

class _Part {
  _Part(String name, double? outOf, this.date, [double? average])
    : name = TextEditingController(text: name),
      outOf = TextEditingController(text: outOf == null ? '' : _n(outOf)),
      average = TextEditingController(text: average == null ? '' : _n(average));
  final TextEditingController name, outOf, average;
  String? date;

  void dispose() {
    name.dispose();
    outOf.dispose();
    average.dispose();
  }
}

class _Component {
  _Component(
    this.id,
    String name,
    double? weight,
    this.parts,
    this.countBest,
    double? average,
  ) : name = TextEditingController(text: name),
      weight = TextEditingController(text: weight == null ? '' : _n(weight)),
      average = TextEditingController(text: average == null ? '' : _n(average));
  final String id;
  final TextEditingController name, weight, average;
  final List<_Part> parts;
  int countBest;

  void dispose() {
    name.dispose();
    weight.dispose();
    average.dispose();
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

  /// "Graded out of" for a weighted course (offering_scale.dart).
  late final _outOf = TextEditingController(
    text: _n(
      switch (widget.existing) {
            final e? => e.outOf,
            null => null,
          } ??
          100,
    ),
  );

  /// The saved average, shown on the saved scale.
  late final _courseAverage = TextEditingController(
    text: switch (widget.existing) {
      Offering(courseAverage: final a?) && final e => _n(
        toShown(
          a,
          scale: scaleOf(e),
          units: courseUnits(weighted: e.weighted, totalMarks: e.totalMarks),
        ),
      ),
      _ => '',
    },
  );

  /// Course units as typed: percent when weighted, else the total.
  double get _units =>
      courseUnits(weighted: _weighted, totalMarks: _num(_total) ?? 100);

  /// What the course average is typed out of.
  double get _scale => _weighted ? (_num(_outOf) ?? 100) : _units;
  late final List<_Component> _components = [
    for (final c in widget.existing?.components ?? const <OfferedComponent>[])
      _Component(
        c.id,
        c.name,
        c.weight,
        [for (final p in c.parts) _Part(p.name, p.outOf, p.date, p.average)],
        c.countBest,
        c.average,
      ),
  ];
  bool _saving = false;

  /// Set only by a failed save (network/permission); field problems are
  /// live, via [_liveError].
  String? _saveError;

  @override
  void dispose() {
    _total.dispose();
    _outOf.dispose();
    _courseAverage.dispose();
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

  /// A component's parts' out-ofs, summed — the maximum its average (and
  /// each part's) can't exceed.
  double _partsOutOf(_Component c) =>
      c.parts.fold(0.0, (s, p) => s + (_num(p.outOf) ?? 0));

  /// The offering as typed, or the first problem with it — the same range
  /// checks as the student marks editor (BUG-04, BUG-05), so a CR can't
  /// publish an impossible value to everyone.
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
      if (w == null) return (null, '$name: the weight is missing.');
      final wErr = _weighted ? percentError(w) : positiveError(w);
      if (wErr != null) return (null, '$name: $wErr');
      if (c.parts.isEmpty) return (null, '$name: add what it is out of.');
      final parts = <OfferedPart>[];
      for (final p in c.parts) {
        final outOf = _num(p.outOf);
        if (outOf == null) {
          return (null, '$name: every part needs “out of”.');
        }
        if (positiveError(outOf) case final err?) {
          return (null, '$name: its out of — $err');
        }
        final avg = _num(p.average);
        if (boundedError(avg, outOf) case final err?) {
          return (null, '$name: its average — $err');
        }
        parts.add(
          OfferedPart(
            name: c.parts.length == 1 ? '' : p.name.text.trim(),
            outOf: outOf,
            date: p.date,
            average: c.parts.length == 1 ? null : avg,
          ),
        );
      }
      final compAvg = _num(c.average);
      if (boundedError(compAvg, _partsOutOf(c)) case final err?) {
        return (null, '$name: its class average — $err');
      }
      comps.add(
        OfferedComponent(
          id: c.id,
          name: name,
          weight: w,
          parts: parts,
          countBest: c.countBest > parts.length ? 0 : c.countBest,
          average: compAvg,
        ),
      );
    }
    final total = _num(_total);
    if (!_weighted && (total == null || total <= 0)) {
      return (null, 'Say what the course is out of.');
    }
    if (totalError(_assigned, _weighted ? 100 : total!) case final err?) {
      return (null, err);
    }
    final outOf = _num(_outOf);
    if (_weighted && (outOf == null || outOf <= 0)) {
      return (null, 'Say what the course is graded out of.');
    }
    final avg = _num(_courseAverage);
    if (avg != null && (avg < 0 || avg > _scale)) {
      return (null, 'The course average is out of ${_n(_scale)}.');
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
        courseAverage:
            avg == null ? null : toStored(avg, scale: _scale, units: _units),
        professors: e?.professors ?? const [],
        updatedAt: e?.updatedAt ?? 0,
        outOf: _weighted ? outOf : null,
      ),
      null,
    );
  }

  /// The first problem with the form as currently typed, live — drives the
  /// error text and keeps Save disabled until it's gone (BUG-04, BUG-05).
  String? get _liveError => _build().$2;

  Future<void> _save() async {
    final (o, error) = _build();
    if (o == null) {
      setState(() => _saveError = error);
      return;
    }
    setState(() => _saving = true);
    try {
      await MaintainStore(roleStore!).save(
        o,
        '${widget.existing?.hasScheme ?? false ? 'Edited' : 'Added'} the '
        '${termLabel(widget.term)} scheme for ${widget.courseId}',
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _saveError = problem(e));
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
                  onChanged: (_) => setState(() {}),
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
                  error:
                      _weighted
                          ? percentError(_num(c.weight))
                          : positiveError(_num(c.weight)),
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
                      error: positiveError(_num(part.outOf)),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  if (c.parts.length > 1) ...[
                    const SizedBox(width: Space.sm),
                    Expanded(
                      flex: 2,
                      child: AppTextField(
                        controller: part.average,
                        label: 'Avg',
                        number: true,
                        dense: true,
                        error: boundedError(
                          _num(part.average),
                          _num(part.outOf),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
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
          Padding(
            padding: const EdgeInsets.only(bottom: Space.xs),
            child: AppTextField(
              controller: c.average,
              label: 'Class average for the component',
              hint: 'Blank until it is out',
              number: true,
              dense: true,
              error: boundedError(_num(c.average), _partsOutOf(c)),
              onChanged: (_) => setState(() {}),
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
            labelAbove: true,
            error: positiveError(_num(_total)),
            onChanged: (_) => setState(() {}),
          ),
        ] else ...[
          const SizedBox(height: Space.sm),
          AppTextField(
            controller: _outOf,
            label: 'Graded out of',
            number: true,
            labelAbove: true,
            error: positiveError(_num(_outOf)),
            onChanged: (_) => setState(() {}),
          ),
          Text(
            'Students see the course out of this; they no longer set it '
            'themselves.',
            style: TypeScale.caption.copyWith(color: p.textMuted),
          ),
        ],
        const SizedBox(height: Space.sm),
        AppTextField(
          controller: _courseAverage,
          label: 'Course average (out of ${_n(_scale)})',
          hint: 'Blank until it is out',
          number: true,
          labelAbove: true,
          error: boundedError(_num(_courseAverage), _scale),
          onChanged: (_) => setState(() {}),
        ),
        Text(
          'Averages are stored against this term and this component set. An '
          'average without them compares nothing.',
          style: TypeScale.caption.copyWith(color: p.textMuted),
        ),
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
                assigned > (_weighted ? 100 : (_num(_total) ?? assigned))
                    ? p.behind
                    : _weighted && assigned != 100
                    ? p.noticeTone.text
                    : p.textMuted,
          ),
        ),
        if (_liveError case final err?) ...[
          const SizedBox(height: Space.sm),
          Text(err, style: TypeScale.caption.copyWith(color: p.behind)),
        ] else if (_saveError != null) ...[
          const SizedBox(height: Space.sm),
          Text(_saveError!, style: TypeScale.caption.copyWith(color: p.behind)),
        ],
        const SizedBox(height: Space.lg),
        PrimaryButton(
          label: _saving ? 'Saving…' : 'Save for everyone',
          onPressed: _saving || _liveError != null ? null : _save,
        ),
        const Note(
          'Students taking this course see this scheme. Anyone who changed a '
          'value keeps theirs and is told the official one moved.',
        ),
      ],
    );
  }
}
