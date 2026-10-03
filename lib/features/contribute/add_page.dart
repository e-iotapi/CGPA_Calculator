import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/catalog/catalog.dart';
import 'package:cgpa_calculator/core/resources/resource.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/features/contribute/contribute_data.dart';
import 'package:cgpa_calculator/features/resources/link_sheet.dart';
import 'package:cgpa_calculator/features/resources/resources_page.dart';
import 'package:cgpa_calculator/features/setup/campus_pick_page.dart';
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
  const AddPage({super.key});

  @override
  State<AddPage> createState() => _AddPageState();
}

class _AddPageState extends State<AddPage> {
  final _rows = [_Row()];
  final _search = TextEditingController();
  bool _course = false, _busy = false;
  String? _dept, _courseId, _error;

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    _search.dispose();
    super.dispose();
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
    final dept = _course ? (_courseId == null ? null : deptOf(_courseId!)) : _dept;
    setState(() => _error = dept == null ? 'Choose where these links belong.' : null);
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
    final depts = departmentsAt(campus);
    _dept ??= depts.contains(myContribDept()) ? myContribDept() : depts.firstOrNull;
    return PageFrame(
      header: header,
      bottom: BottomAction(
        child: PrimaryButton(
          label:
              _busy
                  ? 'Publishing…'
                  : _error != null && !_error!.startsWith('Choose')
                  ? 'Try again'
                  : 'Publish',
          onPressed: _busy ? null : () => _publish(campus, direct),
        ),
      ),
      children: [
        const OfflineStrip(),
        SegmentedPair<bool>(
          a: (false, 'Department'),
          b: (true, 'A course'),
          value: _course,
          onChanged: (v) => setState(() => _course = v),
        ),
        const SizedBox(height: Space.sm),
        if (!_course)
          DropdownButtonFormField<String>(
            initialValue: _dept,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Department'),
            items: [
              for (final d in depts)
                DropdownMenuItem(value: d, child: Text(departmentName(d))),
            ],
            onChanged: (v) => setState(() => _dept = v),
          )
        else
          _CoursePicker(
            search: _search,
            picked: _courseId,
            onPick: (c) => setState(() => _courseId = c),
          ),
        const SizedBox(height: Space.md),
        for (final (i, r) in _rows.indexed) ...[
          AppTextField(
            controller: r.name,
            label: 'Name',
            hint: 'Lecture notes',
            error: r.nameError,
          ),
          const SizedBox(height: Space.xs),
          AppTextField(
            controller: r.url,
            label: 'Link',
            hint: 'https://',
            error: r.urlError,
          ),
          if (i < _rows.length - 1)
            Divider(height: Space.lg, color: p.divider),
        ],
        const SizedBox(height: Space.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => setState(() => _rows.add(_Row())),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Another link'),
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

class _CoursePicker extends StatefulWidget {
  const _CoursePicker({
    required this.search,
    required this.picked,
    required this.onPick,
  });
  final TextEditingController search;
  final String? picked;
  final ValueChanged<String?> onPick;

  @override
  State<_CoursePicker> createState() => _CoursePickerState();
}

class _CoursePickerState extends State<_CoursePicker> {
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final picked = widget.picked;
    if (picked != null) {
      return Row(
        children: [
          Expanded(
            child: Text(
              '$picked · ${courseTitle(picked)}',
              style: TypeScale.body.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: p.text,
              ),
            ),
          ),
          TextButton(
            onPressed: () => widget.onPick(null),
            child: const Text('Change'),
          ),
        ],
      );
    }
    final q = widget.search.text.trim().toLowerCase();
    final hits = q.isEmpty
        ? const <String>[]
        : [
          for (final m in catalog.master)
            if (m.id.toLowerCase().contains(q) ||
                m.title.toLowerCase().contains(q))
              m.id,
        ].take(8).toList();
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
            onTap: () => widget.onPick(id),
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
