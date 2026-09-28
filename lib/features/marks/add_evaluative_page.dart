import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/grading/marks.dart';
import 'package:cgpa_calculator/core/models/marks.dart';
import 'package:cgpa_calculator/core/storage/marks.dart';
import 'package:cgpa_calculator/features/marks/marks_format.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/bottom_action.dart';
import 'package:cgpa_calculator/shared/widgets/circle_icon_button.dart';
import 'package:cgpa_calculator/shared/widgets/count_pill.dart';
import 'package:cgpa_calculator/shared/widgets/dashed_outline.dart';
import 'package:cgpa_calculator/shared/widgets/notice.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:cgpa_calculator/shared/widgets/segmented.dart';
import 'package:cgpa_calculator/core/grading/official_scheme.dart';
import 'package:cgpa_calculator/core/models/offering.dart';
import 'package:cgpa_calculator/core/storage/offerings.dart';
import 'package:cgpa_calculator/core/storage/overrides.dart';
import 'package:cgpa_calculator/core/grading/average_sources.dart';
import 'package:cgpa_calculator/features/marks/widgets/divergence.dart';
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
    this.official,
    this.averagesFrom,
  });

  final String courseId;
  final bool weighted;

  /// Weight not yet given to any other evaluative.
  final double unassigned;
  final Evaluative? existing;
  final String? existingKey;

  /// Set when [existing] follows this offering and is still official: a
  /// change to what it publishes asks first (ARCHITECTURE.md §5).
  final Offering? official;

  /// The course's offering, for where each class average comes from and
  /// the way back to a published one (§8).
  final Offering? averagesFrom;

  @override
  State<AddEvaluativePage> createState() => _AddEvaluativePageState();
}

class _PartFields {
  _PartFields([EvalPart? p])
    : name = TextEditingController(text: p?.name ?? ''),
      marks = TextEditingController(
        text: p?.marks == null ? '' : marks2(p!.marks!),
      ),
      // A seeded component has no out-of yet: blank, not "0".
      outOf = TextEditingController(
        text: p == null || p.outOf <= 0 ? '' : marks2(p.outOf),
      ),
      average = TextEditingController(
        text: p?.average == null ? '' : marks2(p!.average!),
      ),
      date = p?.date;

  /// A copy of [f] to fill in: the next name, the same out-of, no marks.
  _PartFields.after(_PartFields f)
    : name = TextEditingController(text: nextName(f.name.text)),
      marks = TextEditingController(),
      outOf = TextEditingController(text: f.outOf.text),
      average = TextEditingController(),
      date = null;

  final TextEditingController name, marks, outOf, average;
  String? date;

  EvalPart? toPart(bool single) {
    final o = double.tryParse(outOf.text);
    if (o == null || o <= 0) return null;
    return EvalPart(
      name: single ? '' : name.text.trim(),
      marks: double.tryParse(marks.text),
      outOf: o,
      date: date,
      average: double.tryParse(average.text),
    );
  }

  void dispose() {
    name.dispose();
    marks.dispose();
    outOf.dispose();
    average.dispose();
  }
}

class _AddEvaluativePageState extends State<AddEvaluativePage> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _weight = TextEditingController(
    text: widget.existing == null ? '' : marks2(widget.existing!.weight),
  );
  late final _average = TextEditingController(
    text:
        widget.existing?.average == null
            ? ''
            : marks2(widget.existing!.average!),
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
    _average.dispose();
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
      average: double.tryParse(_average.text.trim()),
      sourceId: widget.existing?.sourceId,
    );
  }

  /// Whether a change to the official component may go ahead: true when it is
  /// not official, or the student made it theirs just now.
  Future<bool> _makeMine(String change) async {
    final off = widget.official, old = widget.existing;
    if (off == null || old == null) return true;
    final mine = await confirmDivergence(
      context,
      name: old.name,
      change: change,
    );
    if (mine) {
      await detach(widget.courseId, {
        componentGranule(old.sourceId!): off.updatedAt,
      });
    }
    return mine;
  }

  Future<void> _save() async {
    var e = _draft;
    final old = widget.existing;
    if (e == null) return;
    final change =
        old == null ? null : structuralChange(old, e, widget.weighted);
    if (change != null && !await _makeMine(change)) {
      // Keep official: only the marks are saved, on the official structure.
      e = Evaluative.fromJson(old!.toJson());
      for (final (i, p) in e.parts.indexed) {
        if (i < _draft!.parts.length) p.marks = _draft!.parts[i].marks;
      }
    }
    final back = old == null ? false : await _averages(old, e);
    await saveEvaluative(e, key: widget.existingKey);
    if (back && widget.averagesFrom != null) {
      await applyOfficial(widget.courseId, widget.averagesFrom!);
    }
    if (mounted) Navigator.of(context).pop();
  }

  /// Typing over a published average detaches that one average, with the
  /// same warning; clearing one you typed brings the official back (§8).
  /// Keep official puts the averages back as they were. True when an
  /// official average should be restored after saving.
  Future<bool> _averages(Evaluative old, Evaluative e) async {
    final off = widget.averagesFrom;
    final changes = averageChanges(old, e);
    if (off == null || changes.isEmpty) return false;
    final detached = detachedFor(widget.courseId);
    final cleared = <String>{
      for (final g in changes.keys)
        if (detached.containsKey(g) &&
            (g == componentAverageGranule(old.sourceId!)
                ? e.average == null
                : e.parts[int.parse(g.split('.').last)].average == null))
          g,
    };
    if (cleared.isNotEmpty) await reattach(widget.courseId, cleared.contains);
    final typed = {
      for (final g in changes.keys)
        if (!cleared.contains(g) && !detached.containsKey(g)) g,
    };
    if (typed.isEmpty) return cleared.isNotEmpty;
    if (!mounted) return false;
    final mine = await confirmDivergence(
      context,
      name: '${old.name}\'s average',
      change: changes[typed.first]!,
    );
    if (mine) {
      await detach(widget.courseId, {for (final g in typed) g: off.updatedAt});
    } else {
      e.average = old.average;
      for (final (i, p) in e.parts.indexed) {
        if (i < old.parts.length) p.average = old.parts[i].average;
      }
    }
    return cleared.isNotEmpty;
  }

  Future<void> _delete() async {
    if (!await _makeMine('Removing it')) return;
    await deleteEvaluative(widget.existingKey!);
    if (mounted) Navigator.of(context).pop();
  }

  /// Whether part [i]'s average is still the published one.
  bool _partOfficial(int i) {
    final e = widget.existing;
    if (e == null || widget.averagesFrom == null || i >= e.parts.length) {
      return false;
    }
    return partAverageOf(
          e,
          i,
          widget.averagesFrom,
          detachedFor(widget.courseId),
        )?.source ==
        AverageSource.official;
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
    final n = _active.length;
    final draft = _draft;
    final name = _name.text.trim();
    final head = TypeScale.label.copyWith(
      fontSize: 9.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
      color: p.textMuted,
    );
    Widget card(List<Widget> children) => Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 9,
        children: children,
      ),
    );

    return PageFrame(
      header: PageHeader(
        close: true,
        eyebrow:
            '${widget.courseId} · '
            '${widget.existing == null ? 'NEW' : 'EDIT'} COMPONENT',
        title: name.isEmpty ? 'New component' : name,
        actions: [
          if (widget.existingKey != null)
            CircleIconButton(
              icon: Icons.delete_outline_rounded,
              tooltip: 'Delete component',
              onPressed: _delete,
              size: 44,
            ),
        ],
      ),
      bottom: BottomAction(
        child: PrimaryButton(
          label: 'Save',
          onPressed: draft == null ? null : _save,
        ),
      ),
      children: [
        if (widget.official != null) ...[
          const Notice(
            warning: true,
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Official component. ',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(
                  text:
                      'Your marks are always yours. Changing the weight, an '
                      'out of, a date or an average makes this component '
                      'yours, and it stops updating.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        card([
          AppTextField(
            controller: _name,
            label: 'COMPONENT NAME',
            labelAbove: true,
            onChanged: (_) => setState(() {}),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.weighted ? 'WEIGHT' : 'OUT OF', style: head),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      SizedBox(
                        width: 60,
                        child: CompactField(
                          c: _weight,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      if (widget.weighted) ...[
                        const SizedBox(width: 5),
                        Text(
                          '%',
                          style: TypeScale.body.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: p.icon,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(child: _averageField(draft, head)),
            ],
          ),
          if (widget.weighted)
            Text(_unassignedLine(), style: head.copyWith(letterSpacing: 0)),
        ]),
        const SizedBox(height: 10),
        card([
          SegmentedPair<bool>(
            a: (false, 'One mark'),
            b: (true, 'Several parts'),
            value: _several,
            onChanged:
                (several) => setState(() {
                  _several = several;
                  if (several && _parts.length < 2) _parts.add(_PartFields());
                }),
          ),
          if (_several && n >= 2) ...[
            Text('HOW MANY COUNT', style: head),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var k = n; k >= 1; k--)
                  CountPill(
                    label: k == n ? 'All $n' : 'Best $k of $n',
                    selected: (_best == 0 || _best >= n) ? k == n : _best == k,
                    onTap: () => setState(() => _best = k == n ? 0 : k),
                  ),
              ],
            ),
          ] else if (!_several)
            _singleRow(head),
        ]),
        if (_several) ...[
          const SizedBox(height: 10),
          _partsCard(draft, head, card),
        ],
        const SizedBox(height: 10),
        _preview(draft, p),
      ],
    );
  }

  String _unassignedLine() {
    final left = widget.unassigned - (double.tryParse(_weight.text) ?? 0);
    return left >= 0
        ? '${marks2(left)}% still unassigned'
        : '${marks2(-left)}% over 100';
  }

  Widget _averageField(Evaluative? draft, TextStyle head) {
    final p = AppPalette.of(context);
    final a =
        draft == null
            ? null
            : componentAverageOf(
              draft,
              widget.averagesFrom,
              detachedFor(widget.courseId),
            );
    final outOf = draft?.parts.fold<double>(0, (s, x) => s + x.outOf) ?? 0;
    final shown =
        _average.text.trim().isEmpty &&
        a != null &&
        a.source != AverageSource.yours;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CLASS AVERAGE', style: head),
        const SizedBox(height: 5),
        if (shown)
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Color.lerp(p.surface, p.hero, 0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  marks2(a.value),
                  style: TypeScale.body.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: p.isDark ? p.hero : const Color(0xFF1F5240),
                  ),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    [
                      if (outOf > 0) 'of ${marks2(outOf)}',
                      a.source == AverageSource.official
                          ? 'official'
                          : 'from parts',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TypeScale.caption.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: p.isDark ? p.hero : const Color(0xFF2C7A62),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 40,
            child: CompactField(
              c: _average,
              hint: outOf > 0 ? 'of ${marks2(outOf)}' : 'Optional',
              onChanged: (_) => setState(() {}),
            ),
          ),
      ],
    );
  }

  Widget _singleRow(TextStyle head) {
    final f = _parts.first;
    void changed(String _) => setState(() {});
    Widget col(String label, Widget child, {double? width}) => SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Text(label, style: head), const SizedBox(height: 5), child],
      ),
    );
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        col('YOU', CompactField(c: f.marks, onChanged: changed), width: 64),
        col('OUT OF', CompactField(c: f.outOf, onChanged: changed), width: 64),
        col(
          'DATE',
          _DateChip(
            date: f.date,
            label: 'Date',
            onPick: () => _pickDate(f),
            onClear: () => setState(() => f.date = null),
          ),
        ),
      ],
    );
  }

  Widget _partsCard(
    Evaluative? draft,
    TextStyle head,
    Widget Function(List<Widget>) card,
  ) {
    final p = AppPalette.of(context);
    final colHead = head.copyWith(fontSize: 8.5, letterSpacing: 0.2);
    final dropped =
        draft == null ? const <EvalPart>{} : droppedParts(draft).toSet();
    return LayoutBuilder(
      builder: (context, c) {
        final narrow =
            c.maxWidth < 340 || MediaQuery.textScalerOf(context).scale(1) > 1.3;
        Widget headCell(String t, double w) => SizedBox(
          width: w,
          child: Text(t, textAlign: TextAlign.center, style: colHead),
        );
        return card([
          Row(
            children: [
              Expanded(child: Text('PARTS', style: head)),
              if (!narrow) ...[
                headCell('DATE', 52),
                const SizedBox(width: 5),
                headCell('YOU', 36),
                const SizedBox(width: 5),
                headCell('OUT OF', 36),
                const SizedBox(width: 5),
                headCell('AVG', 46),
              ],
            ],
          ),
          for (final (i, f) in _parts.indexed)
            _partRow(
              f,
              i,
              narrow: narrow,
              dropped:
                  draft != null &&
                  i < draft.parts.length &&
                  dropped.contains(draft.parts[i]),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'Averages fill in by themselves when the CR publishes '
                  'them. The copy button adds the next part below.',
                  style: TypeScale.caption.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: p.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Semantics(
                button: true,
                label: 'Add a part',
                excludeSemantics: true,
                child: InkWell(
                  onTap: () => setState(() => _parts.add(_PartFields())),
                  customBorder: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: DashedOutline(
                    color: p.outline,
                    radius: 18,
                    child: SizedBox(
                      height: 36,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Center(
                          child: Text(
                            '+ Part',
                            style: TypeScale.caption.copyWith(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: p.text,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ]);
      },
    );
  }

  Widget _partRow(
    _PartFields f,
    int i, {
    required bool narrow,
    required bool dropped,
  }) {
    final p = AppPalette.of(context);
    void changed(String _) => setState(() {});
    Widget field(Widget child, double w) {
      final box = SizedBox(width: w, child: child);
      return dropped
          ? DashedOutline(color: p.outline, radius: 11, child: box)
          : box;
    }

    final official = _partOfficial(i) && f.average.text.isNotEmpty;
    final fields = [
      field(
        _DateChip(
          date: f.date,
          label: 'Part ${i + 1} date',
          onPick: () => _pickDate(f),
          onClear: () => setState(() => f.date = null),
        ),
        52,
      ),
      field(CompactField(c: f.marks, hint: 'You', onChanged: changed), 36),
      field(CompactField(c: f.outOf, hint: 'Of', onChanged: changed), 36),
      field(
        official
            ? Tooltip(
              message: 'Published by the CR',
              child: CompactField(c: f.average, official: true),
            )
            : CompactField(c: f.average, hint: 'Avg', onChanged: changed),
        46,
      ),
    ];
    final partLabel = Text(
      dropped ? 'PART ${i + 1} · DROPPED' : 'PART ${i + 1}',
      style: TypeScale.label.copyWith(
        fontSize: 9.5,
        fontWeight: FontWeight.w700,
        color: p.textMuted.withValues(alpha: 0.8),
      ),
    );
    return Opacity(
      opacity: dropped ? 0.6 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: f.name,
                    onChanged: changed,
                    style: TypeScale.body.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: p.text,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Part ${i + 1} name',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(11),
                        borderSide: BorderSide(color: p.outline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(11),
                        borderSide: BorderSide(color: p.outline),
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Duplicate part ${i + 1}',
                onPressed:
                    () => setState(
                      () => _parts.insert(i + 1, _PartFields.after(f)),
                    ),
                icon: Icon(Icons.copy_rounded, color: p.textMuted, size: 16),
              ),
              if (_parts.length > 2)
                IconButton(
                  tooltip: 'Remove part ${i + 1}',
                  onPressed:
                      () => setState(() {
                        _parts.removeAt(i).dispose();
                        if (_best >= _parts.length) _best = 0;
                      }),
                  icon: Icon(Icons.close_rounded, color: p.textMuted, size: 15),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (narrow) ...[
            partLabel,
            const SizedBox(height: 4),
            Wrap(spacing: 5, runSpacing: 5, children: fields),
          ] else
            Row(
              children: [
                Expanded(child: partLabel),
                for (final (j, w) in fields.indexed) ...[
                  if (j > 0) const SizedBox(width: 5),
                  w,
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _preview(Evaluative? d, AppPalette p) {
    final value = d == null ? null : contribution(d);
    final avg = d == null ? null : componentAverage(d);
    final how = [
      if (d == null)
        'Fill in a name, a weight and each out of'
      else if (d.countBest > 0)
        'best ${d.countBest} of ${d.parts.length}'
      else if (d.parts.length > 1)
        'all ${d.parts.length} count'
      else
        'one mark',
      if (avg != null) 'class ${marks2(avg.value)}',
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 11, 15, 11),
      decoration: BoxDecoration(
        color: p.hero,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'THIS COMPONENT GIVES YOU',
                  style: TypeScale.label.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: p.onHero,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  how,
                  style: TypeScale.caption.copyWith(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: p.onHeroMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value == null ? '—' : value.toStringAsFixed(1),
                  style: TypeScale.display.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    color: p.onHero,
                  ),
                ),
                if (d != null)
                  TextSpan(
                    text: ' / ${marks2(d.weight)}',
                    style: TypeScale.body.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: p.onHeroMuted,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A compact date field: "8 Sep", or "Date"; set, a × clears it.
class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.date,
    required this.label,
    required this.onPick,
    required this.onClear,
  });

  /// ISO date, or null.
  final String? date;
  final String label;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final set = date != null;
    return Material(
      color: const Color(0xFFF8F8F5),
      borderRadius: BorderRadius.circular(11),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 36,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: InkWell(
                onTap: onPick,
                child: Semantics(
                  button: true,
                  label: set ? '$label, ${shortDate(date!)}' : label,
                  excludeSemantics: true,
                  child: Container(
                    height: 36,
                    constraints: const BoxConstraints(minWidth: 36),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center,
                    child: Text(
                      set ? shortDate(date!) : 'Date',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TypeScale.caption.copyWith(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: set ? const Color(0xFF17170F) : p.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (set)
              Tooltip(
                message: 'Clear date',
                child: InkWell(
                  onTap: onClear,
                  child: const SizedBox(
                    width: 20,
                    height: 36,
                    child: Icon(Icons.close_rounded, size: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
