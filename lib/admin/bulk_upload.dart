import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/catalog/catalog.dart';
import 'package:cgpa_calculator/core/grading/eval_import.dart';
import 'package:cgpa_calculator/core/models/offering.dart';
import 'package:cgpa_calculator/core/roles/capabilities.dart';
import 'package:cgpa_calculator/core/roles/maintain_store.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:flutter/material.dart';
import 'package:cgpa_calculator/shared/widgets/confirm_dialog.dart';

typedef _Row =
    ({
      ImportedScheme scheme,
      Offering next,
      Offering? existing,
      ImportEffect effect,
    });

/// Preview, confirm, write (§13.2, §16.3 fix 11). Nothing is written until
/// the preview is confirmed; the write goes five courses a batch and says
/// which landed if it stops.
class BulkUploadPage extends StatefulWidget {
  const BulkUploadPage({super.key, required this.campus, required this.source});
  final String campus, source;

  @override
  State<BulkUploadPage> createState() => _BulkUploadPageState();
}

class _BulkUploadPageState extends State<BulkUploadPage> {
  late final _store = MaintainStore(roleStore!);
  final _landed = <String>{};
  bool _writing = false;
  bool _done = false;
  String? _stopped;

  Future<(EvalFile, List<_Row>)> _prepare() async {
    final ids = {for (final m in catalog.master) m.id};
    final f = parseEvalFile(
      widget.source,
      campus: widget.campus,
      known: ids.contains,
      inScope:
          (id) => myRoles.value.may(
            Capability.courseStructures,
            campus: widget.campus,
            scope: id,
          ),
    );
    final existing = await _store.offerings(
      f.courses.map((c) => c.courseId),
      f.campus,
      f.term,
    );
    return (
      f,
      [
        for (final s in f.courses)
          () {
            final old = existing[s.courseId];
            final next = schemeFor(
              s,
              campus: f.campus,
              term: f.term,
              existing: old,
            );
            return (
              scheme: s,
              next: next,
              existing: old,
              effect: effectOf(next, old),
            );
          }(),
      ],
    );
  }

  Future<void> _write(List<_Row> rows) async {
    final todo = [
      for (final r in rows)
        if (r.effect != ImportEffect.same && !_landed.contains(r.next.courseId))
          r.next,
    ];
    final ok = await confirmDialog(
      context,
      title: 'Write ${todo.length} schemes?',
      body:
          'Every student taking these courses sees the new schemes. Each '
          'write is logged under your name.',
      action: 'Write',
    );
    if (!ok) return;
    setState(() {
      _writing = true;
      _stopped = null;
    });
    final r = await _store.upload(
      todo,
      onLanded: (ids) => setState(() => _landed.addAll(ids)),
    );
    if (!mounted) return;
    setState(() {
      _writing = false;
      _done = r.error == null;
      _stopped = r.error == null ? null : problem(r.error!);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return FutureBuilder<(EvalFile, List<_Row>)>(
      future: _prepared ??= _prepare(),
      builder: (context, s) {
        if (s.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (s.error case final e?) {
          return PageFrame(
            header: const PageHeader(
              eyebrow: 'NOTHING WAS IMPORTED',
              title: 'This file cannot be used',
            ),
            children: [
              AppCard(
                child: Text(
                  e is EvalImportError ? e.message : problem(e),
                  style: TypeScale.body.copyWith(color: p.behind),
                ),
              ),
              const Note(
                'One bad row rejects the whole file, so a department never '
                'ends up half imported. Fix the row named above and upload '
                'again.',
              ),
            ],
          );
        }
        final (f, rows) = s.data!;
        List<_Row> of(ImportEffect e) =>
            rows.where((r) => r.effect == e).toList();
        final create = of(ImportEffect.create);
        final change = of(ImportEffect.change);
        final same = of(ImportEffect.same);
        final writes = create.length + change.length;

        Widget row(_Row r) {
          final landed = _landed.contains(r.next.courseId);
          final s = r.scheme;
          final warn = [
            if (s.weighted && s.assigned != 100)
              'Weights sum to ${s.assigned.toStringAsFixed(0)}%',
            if (s.notes != null) s.notes!,
          ];
          return AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.courseId,
                        style: TypeScale.body.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (landed) const TierTag('WRITTEN', strong: true),
                  ],
                ),
                Text(
                  [
                    for (final c in r.next.components)
                      '${c.name} ${c.weight.toStringAsFixed(0)}'
                          '${r.next.weighted ? '%' : ''}',
                  ].join(' · '),
                  style: TypeScale.caption.copyWith(color: p.textMuted),
                ),
                if (r.effect == ImportEffect.change)
                  Text(
                    'Was: ${[for (final c in r.existing!.components) '${c.name} ${c.weight.toStringAsFixed(0)}'].join(' · ')}',
                    style: TypeScale.caption.copyWith(color: p.textMuted),
                  ),
                for (final w in warn)
                  Text(
                    w,
                    style: TypeScale.caption.copyWith(color: p.noticeTone.text),
                  ),
                if (s.professorNames.isNotEmpty)
                  Text(
                    'Handout names ${s.professorNames.join(', ')} — '
                    'professors are picked from the department list, not '
                    'imported.',
                    style: TypeScale.caption.copyWith(color: p.textMuted),
                  ),
              ],
            ),
          );
        }

        List<Widget> section(String label, List<_Row> rs) => [
          if (rs.isNotEmpty) ...[
            SectionLabel('$label · ${rs.length}'),
            for (final r in rs) ...[row(r), const SizedBox(height: Space.xs)],
          ],
        ];

        return PageFrame(
          header: PageHeader(
            eyebrow:
                '${f.campus.toUpperCase()} · ${termLabel(f.term).toUpperCase()}',
            title: 'Check before writing',
          ),
          children: [
            ...section('Creates', create),
            ...section('Changes', change),
            if (same.isNotEmpty) ...[
              SectionLabel('Left alone · ${same.length}'),
              Text(
                same.map((r) => r.scheme.courseId).join(', '),
                style: TypeScale.caption.copyWith(color: p.textMuted),
              ),
            ],
            const SizedBox(height: Space.md),
            if (_stopped != null)
              AppCard(
                child: Text(
                  'Stopped after ${_landed.length} of $writes: $_stopped '
                  'The courses marked Written are saved; write again to retry '
                  'the rest.',
                  style: TypeScale.caption.copyWith(color: p.behind),
                ),
              ),
            if (_done)
              const Note('Done. Every change is written and logged.')
            else
              PrimaryButton(
                label:
                    _writing
                        ? 'Writing ${_landed.length} of $writes…'
                        : writes == 0
                        ? 'Nothing to write'
                        : _stopped != null
                        ? 'Retry the rest'
                        : 'Write $writes schemes',
                onPressed: _writing || writes == 0 ? null : () => _write(rows),
              ),
            const Note(
              'Writes go five courses at a time. If one stops, the ones '
              'already written stay written and are marked above.',
            ),
          ],
        );
      },
    );
  }

  Future<(EvalFile, List<_Row>)>? _prepared;
}
