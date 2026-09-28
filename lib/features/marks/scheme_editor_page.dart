import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/grading/official_scheme.dart';
import 'package:cgpa_calculator/core/models/marks.dart';
import 'package:cgpa_calculator/core/models/offering.dart';
import 'package:cgpa_calculator/core/storage/marks.dart';
import 'package:cgpa_calculator/features/marks/official.dart';
import 'package:cgpa_calculator/core/storage/overrides.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/marks/marks_format.dart';
import 'package:cgpa_calculator/features/marks/widgets/divergence.dart';
import 'package:cgpa_calculator/shared/widgets/card_row.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Board `Divergence` (§5.4): the course's components, weights and class
/// averages typeable in place. The first change to an official value asks
/// once per component before it becomes the student's.
class SchemeEditorPage extends StatefulWidget {
  const SchemeEditorPage({super.key, required this.course, this.onEditCourse});

  final Course course;

  /// The old course card (credits, grades, delete). Null hides the row.
  final VoidCallback? onEditCourse;

  @override
  State<SchemeEditorPage> createState() => _SchemeEditorPageState();
}

class _Row {
  _Row(this.key, this.e)
    : weight = TextEditingController(text: marks2(e.weight)),
      average = TextEditingController(
        text: e.average == null ? '' : marks2(e.average!),
      );

  final String key;
  final Evaluative e;
  final TextEditingController weight, average;
}

class _SchemeEditorPageState extends State<SchemeEditorPage> {
  String get _id => widget.course.id;
  late final Offering? _off = offeringFor(widget.course);
  late final List<_Row> _rows = [
    for (final (k, e) in evaluativesFor(_id)) _Row(k, e),
  ];

  /// Components already asked about this visit.
  final _asked = <String>{};
  String? _editing;

  @override
  void dispose() {
    for (final r in _rows) {
      r.weight.dispose();
      r.average.dispose();
    }
    super.dispose();
  }

  /// Official and not yet the student's.
  bool _official(Evaluative e) {
    final id = e.sourceId, off = _off;
    if (off == null || id == null || off.component(id) == null) return false;
    return !detachedFor(_id).keys.any((g) => ofComponent(g, id));
  }

  String _tag(_Row r) {
    final id = r.e.sourceId, off = _off;
    if (_official(r.e)) {
      return _editing == r.key ? 'OFFICIAL · EDITING' : 'OFFICIAL';
    }
    if (off != null && id != null && off.component(id) == null) {
      return 'NOT OFFICIAL';
    }
    return 'YOURS';
  }

  Future<void> _changed(_Row r, {required bool average}) async {
    final e = r.e;
    final c = average ? r.average : r.weight;
    final v = double.tryParse(c.text.trim());
    if (!average && (v == null || v <= 0)) return;
    final before = average ? e.average : e.weight;
    if (v == before) return;
    if (_official(e)) {
      final id = e.sourceId!;
      if (_asked.contains(id)) return;
      _asked.add(id);
      final change =
          average
              ? 'Class average ${before == null ? 'blank' : marks2(before)} → '
                  '${v == null ? 'blank' : marks2(v)}'
              : 'Weight ${marks2(before!)}% → ${marks2(v!)}%';
      final mine = await confirmDivergence(
        context,
        name: e.name,
        change: change,
      );
      if (!mounted) return;
      if (!mine) {
        _asked.remove(id);
        setState(() => c.text = before == null ? '' : marks2(before));
        return;
      }
      await detach(_id, {
        average ? componentAverageGranule(id) : componentGranule(id):
            _off!.updatedAt,
      });
    }
    if (average) {
      e.average = v;
    } else {
      e.weight = v!;
    }
    await saveEvaluative(e, key: r.key);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final lbl = TypeScale.label.copyWith(
      fontSize: 9.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
      color: p.textMuted,
    );
    return PageFrame(
      header: PageHeader(eyebrow: '$_id · SCHEME', title: 'Evaluation scheme'),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(child: Text('COMPONENT', style: lbl)),
              SizedBox(width: 62, child: Text('WEIGHT', style: lbl)),
              const SizedBox(width: 8),
              SizedBox(width: 56, child: Text('CLASS AVG', style: lbl)),
            ],
          ),
        ),
        const SizedBox(height: 7),
        if (_rows.isEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'No components yet. Add them from Marks.',
              style: TypeScale.body.copyWith(color: p.textMuted),
            ),
          ),
        for (final r in _rows) ...[
          Focus(
            onFocusChange:
                (f) => setState(() {
                  if (f) {
                    _editing = r.key;
                  } else if (_editing == r.key) {
                    _editing = null;
                  }
                }),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.e.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TypeScale.body.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: p.text,
                          ),
                        ),
                        Text(_tag(r), style: lbl.copyWith(letterSpacing: 0.3)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _Input(
                    c: r.weight,
                    width: 46,
                    label: '${r.e.name} weight',
                    onDone: () => _changed(r, average: false),
                  ),
                  const SizedBox(width: 3),
                  SizedBox(
                    width: 13,
                    child: Text(
                      '%',
                      style: TypeScale.caption.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: p.icon,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _Input(
                    c: r.average,
                    width: 56,
                    hint: '—',
                    label: '${r.e.name} class average',
                    onDone: () => _changed(r, average: true),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 7),
        ],
        if (widget.onEditCourse != null) ...[
          const SizedBox(height: Space.md),
          Container(
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: CardRow(
              title: 'Credits, grades and delete',
              subtitle: 'The course card',
              onTap: () {
                Navigator.of(context).pop();
                widget.onEditCourse!();
              },
            ),
          ),
        ],
      ],
    );
  }
}

/// A compact number box; commits on submit or when focus leaves.
class _Input extends StatelessWidget {
  const _Input({
    required this.c,
    required this.width,
    required this.label,
    required this.onDone,
    this.hint,
  });

  final TextEditingController c;
  final double width;
  final String label;
  final String? hint;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(11),
      borderSide: BorderSide(color: p.outline),
    );
    return SizedBox(
      width: width,
      height: 36,
      child: Semantics(
        label: label,
        child: Focus(
          onFocusChange: (f) {
            if (!f) onDone();
          },
          child: TextField(
            controller: c,
            onSubmitted: (_) => onDone(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            textAlign: TextAlign.center,
            style: TypeScale.body.copyWith(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: p.text,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              contentPadding: const EdgeInsets.symmetric(vertical: 9),
              border: border,
              enabledBorder: border,
              focusedBorder: border.copyWith(
                borderSide: BorderSide(color: p.text, width: 2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
