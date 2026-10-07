import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/core/search/hints.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/catalog/catalog.dart';
import 'package:cgpa_calculator/core/resources/resource.dart';
import 'package:cgpa_calculator/core/roles/capabilities.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/features/contribute/contribute_data.dart';
import 'package:cgpa_calculator/features/resources/link_sheet.dart';
import 'package:cgpa_calculator/features/resources/resources_page.dart';
import 'package:cgpa_calculator/features/setup/campus_pick_page.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/bottom_action.dart';
import 'package:cgpa_calculator/shared/widgets/notice.dart';
import 'package:cgpa_calculator/shared/widgets/offline_strip.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:cgpa_calculator/shared/widgets/search_box.dart';
import 'package:cgpa_calculator/shared/widgets/segmented.dart';
import 'package:flutter/material.dart';

class _Row {
  final name = TextEditingController(), url = TextEditingController();
  String? nameError, urlError;
  void dispose() {
    name.dispose();
    url.dispose();
  }
}

/// Board `ContributeAdd`: one batch of links for a department or a course.
/// A student's batch waits for approval as one entry; staff publish at once.
class AddPage extends StatefulWidget {
  const AddPage({super.key, this.course = false});

  /// Opens on A course (from Course resources).
  final bool course;

  @override
  State<AddPage> createState() => _AddPageState();
}

class _AddPageState extends State<AddPage> {
  final _rows = [_Row()];
  final _search = TextEditingController();
  late bool _course = widget.course;
  bool _busy = false;
  String? _dept, _courseId, _error;

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    _search.dispose();
    super.dispose();
  }

  Future<void> _pickDept(List<String> depts) async {
    final v = await showModalBottomSheet<String>(
      context: context,
      builder:
          (context) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final d in depts)
                  ListTile(
                    title: Text('$d · ${departmentName(d)}'),
                    onTap: () => Navigator.of(context).pop(d),
                  ),
              ],
            ),
          ),
    );
    if (v != null && mounted) {
      setState(() {
        _dept = v;
        // The picked course belongs to the old department.
        if (_course && _courseId != null && deptOf(_courseId!) != v) {
          _courseId = null;
        }
      });
    }
  }

  Future<void> _publish(String campus, bool direct) async {
    var ok = true;
    final filled = <_Row>[];
    for (final r in _rows) {
      final n = r.name.text.trim(), u = r.url.text.trim();
      if (n.isEmpty && u.isEmpty && _rows.length > 1) continue;
      r.nameError = n.isEmpty ? 'Give the link a name.' : null;
      r.urlError = isWebLink(u) ? null : 'Paste a full web address.';
      ok &= r.nameError == null && r.urlError == null;
      filled.add(r);
    }
    final dept =
        _course ? (_courseId == null ? null : deptOf(_courseId!)) : _dept;
    setState(
      () => _error = dept == null ? 'Choose where these links belong.' : null,
    );
    if (!ok || dept == null || filled.isEmpty) {
      setState(() {});
      return;
    }
    final links = [
      for (final r in filled)
        Resource(
          id: '',
          title: r.name.text.trim(),
          url: r.url.text.trim(),
          campus: campus,
          department: dept,
          scope: _course ? 'course' : 'department',
          courseIds: _course ? [_courseId!] : const [],
        ),
    ];
    setState(() {
      _busy = true;
      _error = null;
    });
    final store = resourceStore!;
    try {
      if (direct) {
        for (final l in links) {
          await store.add(l, actingFor: _course ? _courseId : null);
        }
      } else {
        await store.addBatchAsContributor(links);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            direct
                ? (links.length == 1 ? 'Link published' : 'Links published')
                : 'Sent for approval. Your links are live now.',
          ),
        ),
      );
      Navigator.of(context).maybePop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = problem(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final campus = viewCampus(), direct = contributesDirectly;
    const header = PageHeader(eyebrow: 'CONTRIBUTE', title: 'Add links');
    if (resourceStore == null || campus == null) {
      return PageFrame(
        header: header,
        children: [
          if (resourceStore == null)
            const Note('Sign in with your BITS account to add links.')
          else
            campusPrompt(context),
        ],
      );
    }
    // Staff publish at once, so only where they may; and they pick it, the
    // first one is no default (owner, 2026-10-06).
    final depts = direct ? linkDepts(campus) : departmentsAt(campus);
    final n = _rows
        .where(
          (r) => r.name.text.trim().isNotEmpty || r.url.text.trim().isNotEmpty,
        )
        .length
        .clamp(1, 999);
    if (!direct) {
      _dept ??=
          depts.contains(myContribDept()) ? myContribDept() : depts.firstOrNull;
    }
    return PageFrame(
      header: header,
      bottom: BottomAction(
        child: PrimaryButton(
          label:
              _busy
                  ? 'Publishing…'
                  : _error != null && !_error!.startsWith('Choose')
                  ? 'Try again'
                  : 'Publish $n ${n == 1 ? 'link' : 'links'}',
          onPressed: _busy ? null : () => _publish(campus, direct),
        ),
      ),
      children: [
        const OfflineStrip(),
        SegmentedTrack<bool>(
          height: 42,
          tabs: const [(false, 'Department'), (true, 'A course')],
          value: _course,
          onChanged: (v) => setState(() => _course = v),
        ),
        const SizedBox(height: Space.xs),
        _Labelled(
          'DEPARTMENT · ANY ON CAMPUS',
          SelectRow(
            text:
                _dept == null ? 'Choose' : '$_dept · ${departmentName(_dept!)}',
            onTap: () => _pickDept(depts),
            fill: p.surface,
          ),
        ),
        if (_course)
          _Labelled(
            'COURSE · ANY ON CAMPUS',
            _CoursePicker(
              search: _search,
              dept: _dept,
              picked: _courseId,
              onPick:
                  (c) => setState(() {
                    _courseId = c;
                    if (c != null) _dept = deptOf(c);
                  }),
            ),
          ),
        const Note(
          'Pick any department or course on campus. You are not limited to '
          'your own.',
        ),
        const SizedBox(height: Space.xs),
        AppCard(
          padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
          radius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, r) in _rows.indexed) ...[
                if (i > 0) ...[
                  const SizedBox(height: 10),
                  Divider(height: 1, color: p.divider),
                  const SizedBox(height: 10),
                ],
                _Cap('LINK ${i + 1}'),
                const SizedBox(height: 10),
                AppTextField(
                  controller: r.name,
                  label: 'Title',
                  hint: 'Lecture notes',
                  labelAbove: true,
                  fill: p.surface,
                  error: r.nameError,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                AppTextField(
                  controller: r.url,
                  label: 'URL',
                  hint: 'https://',
                  labelAbove: true,
                  fill: p.surface,
                  error: r.urlError,
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ],
          ),
        ),
        TextButton.icon(
          onPressed: () => setState(() => _rows.add(_Row())),
          style: TextButton.styleFrom(
            alignment: Alignment.centerLeft,
            minimumSize: const Size(0, Sizes.minTouch),
            padding: EdgeInsets.zero,
            foregroundColor: p.accent,
          ),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(
            'Another link',
            style: TypeScale.body.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: Space.sm),
          Notice(warning: true, text: TextSpan(text: _error)),
        ],
        Note(
          direct
              ? 'Your links go live at once.'
              : 'Your links go live now. A president approves them within 15 '
                  'days, and points are counted after approval.',
        ),
      ],
    );
  }
}

/// The departments on [campus] where I publish links at once.
List<String> linkDepts(String campus) => [
  for (final d in departmentsAt(campus))
    if (myRoles.value.may(
      Capability.departmentResources,
      campus: campus,
      scope: d,
    ))
      d,
];

/// The small upper-case caption above a field or a card (board `.lbl`).
class _Cap extends StatelessWidget {
  const _Cap(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TypeScale.label.copyWith(
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
      color: AppPalette.of(context).textMuted,
    ),
  );
}

class _Labelled extends StatelessWidget {
  const _Labelled(this.label, this.child);
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_Cap(label), const SizedBox(height: 5), child],
    ),
  );
}

class _CoursePicker extends StatefulWidget {
  const _CoursePicker({
    required this.search,
    required this.dept,
    required this.picked,
    required this.onPick,
  });
  final TextEditingController search;
  final String? dept;
  final String? picked;
  final ValueChanged<String?> onPick;

  @override
  State<_CoursePicker> createState() => _CoursePickerState();
}

class _CoursePickerState extends State<_CoursePicker> {
  final _learner = QueryLearner();

  @override
  void dispose() {
    _learner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final picked = widget.picked;
    if (picked != null) {
      return SelectRow(
        text: '$picked · ${courseTitle(picked)}',
        onTap: () => widget.onPick(null),
        fill: p.surface,
      );
    }
    final q = widget.search.text.trim();
    final hits =
        q.isEmpty
            ? const <String>[]
            : widen(
              q,
              (ph) => [
                for (final m in catalog.master)
                  if ((widget.dept == null || deptOf(m.id) == widget.dept) &&
                      textMatches(ph, '${m.id} ${m.title}'))
                    m.id,
              ],
              (id) => id,
            ).take(8).toList();
    if (q.isNotEmpty) _learner.typed(q, found: hits.isNotEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SearchBox(
          controller: widget.search,
          hint: 'Search a course',
          onChanged: (_) => setState(() {}),
        ),
        for (final id in hits)
          InkWell(
            onTap: () {
              _learner.picked(q);
              widget.onPick(id);
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: Sizes.minTouch),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '$id · ${courseTitle(id)}',
                  style: TypeScale.body.copyWith(fontSize: 12.5, color: p.text),
                ),
              ),
            ),
          ),
        if (q.isNotEmpty && hits.isEmpty) const Note('No course matches.'),
      ],
    );
  }
}
