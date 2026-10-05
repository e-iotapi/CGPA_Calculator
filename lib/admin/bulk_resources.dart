import 'package:cgpa_calculator/admin/maintain.dart';
import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/platform/browser.dart';
import 'package:cgpa_calculator/core/resources/resource.dart';
import 'package:cgpa_calculator/core/resources/resource_import.dart';
import 'package:cgpa_calculator/core/roles/claim_store.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/features/resources/resources_page.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/confirm_dialog.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:flutter/material.dart';

typedef _Plan =
    ({List<BulkLink> fresh, List<BulkLink> already, List<Resource> existing});

/// Many links at once for one department: upload, preview, confirm, write.
/// Nothing is written until the preview is confirmed; links go one at a time
/// through the same path as Add a link, and the page says which landed if it
/// stops.
class BulkResourcesPage extends StatefulWidget {
  const BulkResourcesPage({
    super.key,
    required this.campus,
    required this.dept,
  });
  final String campus, dept;

  @override
  State<BulkResourcesPage> createState() => _BulkResourcesPageState();
}

class _BulkResourcesPageState extends State<BulkResourcesPage> {
  Future<_Plan>? _prepared;
  final _landed = <int>{};
  bool _writing = false;
  bool _done = false;
  String? _stopped;

  void _read(String? source) {
    if (source == null || source.trim().isEmpty || !mounted) return;
    // A bad file can fail before the next frame subscribes; the builder
    // still shows the error.
    setState(() {
      _prepared = _prepare(source)..ignore();
    });
  }

  Future<_Plan> _prepare(String source) async {
    final claims = await ClaimStore(roleStore!).claims(widget.campus);
    final links = parseResourceFile(
      source,
      campus: widget.campus,
      dept: widget.dept,
      courses: {for (final c in managedCourses(widget.dept, claims)) c.id},
    );
    final existing = await resourceStore!.department(
      widget.campus,
      widget.dept,
    );
    final p = planLinks(links, existing);
    return (fresh: p.fresh, already: p.already, existing: existing);
  }

  Future<void> _write(_Plan plan) async {
    final todo = [
      for (final (i, l) in plan.fresh.indexed)
        if (!_landed.contains(i)) (i, l),
    ];
    final ok = await confirmDialog(
      context,
      title: 'Add ${todo.length} links?',
      body:
          'Students see them at once. Each link is logged under your name '
          'and earns you +4.',
      action: 'Add',
    );
    if (!ok) return;
    setState(() {
      _writing = true;
      _stopped = null;
    });
    // A course link shows on the department list too, unless the department
    // already has that address (Add a link does the same).
    final onDept = {
      for (final l in plan.fresh)
        if (l.course == null) normaliseUrl(l.url),
    };
    Object? error;
    for (final (i, l) in todo) {
      final c = l.course;
      try {
        await resourceStore!.add(
          Resource(
            id: '',
            title: l.title,
            url: l.url,
            campus: widget.campus,
            department: widget.dept,
            scope: c == null ? 'department' : 'course',
            courseIds: c == null ? const [] : [c],
            pinnedToDepartment:
                c != null &&
                !onDept.contains(normaliseUrl(l.url)) &&
                shouldRollUp(plan.existing, l.url),
          ),
        );
      } on Object catch (e) {
        error = e;
        break;
      }
      if (!mounted) return;
      setState(() => _landed.add(i));
    }
    if (!mounted) return;
    setState(() {
      _writing = false;
      _done = error == null;
      _stopped = error == null ? null : problem(error);
    });
  }

  @override
  Widget build(BuildContext context) {
    final header = PageHeader(
      eyebrow: '${campusName(widget.campus).toUpperCase()} · ${widget.dept}',
      title: 'Bulk add links',
    );
    final prepared = _prepared;
    if (prepared == null) {
      return PageFrame(
        header: header,
        children: [
          DropZone(
            title: 'Upload links as JSON',
            body:
                'Many links at once. Titles are optional; you see every '
                'link before anything is added.',
            onFile:
                () async => _read(await pickTextFile('.json,application/json')),
            onPaste:
                () async => _read(
                  await pasteJson(context, '{"schema":"$resourcesSchema", …}'),
                ),
          ),
          const SizedBox(height: Space.sm),
          const UploadCard(
            prompt: resourcesPrompt,
            quote: '“Turn the links I give you into one JSON object…”',
            use:
                'Paste this into any AI tool along with your links, a chat '
                'export or a doc. It states the exact shape this page '
                'accepts.',
            after:
                'A link with no title gets one from its address. Rename the '
                'vague ones afterwards from the list.',
          ),
        ],
      );
    }
    return FutureBuilder<_Plan>(
      future: prepared,
      builder: (context, s) {
        if (s.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (s.error case final e?) return _rejected(e);
        return _preview(s.data!, header);
      },
    );
  }

  Widget _rejected(Object e) {
    final p = AppPalette.of(context);
    return PageFrame(
      header: const PageHeader(
        eyebrow: 'NOTHING WAS ADDED',
        title: 'This file cannot be used',
      ),
      children: [
        AppCard(
          child: Text(
            e is ResourceImportError ? e.message : problem(e),
            style: TypeScale.body.copyWith(color: p.behind),
          ),
        ),
        const Note(
          'One bad row rejects the whole file. Fix the row named above and '
          'upload again.',
        ),
        const SizedBox(height: Space.md),
        PrimaryButton(
          label: 'Try another file',
          onPressed: () => setState(() => _prepared = null),
        ),
      ],
    );
  }

  Widget _preview(_Plan plan, PageHeader header) {
    final p = AppPalette.of(context);
    final muted = TypeScale.caption.copyWith(color: p.textMuted);
    final n = plan.fresh.length;
    final byCourse = <String, List<(int, BulkLink)>>{};
    for (final (i, l) in plan.fresh.indexed) {
      (byCourse[l.course ?? widget.dept] ??= []).add((i, l));
    }
    return PageFrame(
      header: header,
      children: [
        Text(
          '$n new · ${plan.already.length} already there',
          style: TypeScale.body.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: Space.sm),
        for (final MapEntry(key: where, value: rows) in byCourse.entries) ...[
          SectionLabel('$where · ${rows.length}'),
          for (final (i, l) in rows) ...[
            AppCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.title,
                          style: TypeScale.body.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          l.url,
                          style: muted,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (_landed.contains(i))
                    const TierTag('ADDED', strong: true)
                  else if (l.guessed)
                    const TierTag('GUESSED'),
                ],
              ),
            ),
            const SizedBox(height: Space.xs),
          ],
        ],
        if (plan.already.isNotEmpty) ...[
          SectionLabel('Already there · ${plan.already.length}'),
          Text(plan.already.map((l) => l.url).join('\n'), style: muted),
        ],
        const SizedBox(height: Space.md),
        if (_stopped != null)
          AppCard(
            child: Text(
              'Stopped after ${_landed.length} of $n: $_stopped The links '
              'marked Added are saved; add again to retry the rest.',
              style: TypeScale.caption.copyWith(color: p.behind),
            ),
          ),
        if (_done)
          const Note('Done. Every link is added and logged.')
        else
          PrimaryButton(
            label:
                _writing
                    ? 'Adding ${_landed.length} of $n…'
                    : n == 0
                    ? 'Nothing to add'
                    : _stopped != null
                    ? 'Retry the rest'
                    : 'Add $n links',
            onPressed: _writing || n == 0 ? null : () => _write(plan),
          ),
      ],
    );
  }
}
