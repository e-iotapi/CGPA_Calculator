import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/resources/resource.dart';
import 'package:cgpa_calculator/core/resources/resource_store.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/features/resources/resources_page.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:flutter/material.dart';

ResourceStore get _store => resourceStore!;

void _say(BuildContext context, String text) =>
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(text)));

/// Adds or edits a link. [course] makes it a course link (a CR's, or a
/// president adding for a course); [existing] edits in place. [department]
/// is what the rollup is checked against.
Future<bool> editLink(
  BuildContext context, {
  required String campus,
  required String dept,
  required List<Resource> department,
  String? course,
  String? actingFor,
  Resource? existing,
  bool fixing = false,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder:
        (_) => _LinkSheet(
          campus: campus,
          dept: dept,
          department: department,
          course: course,
          actingFor: actingFor,
          existing: existing,
          fixing: fixing,
        ),
  );
  return saved == true;
}

class _LinkSheet extends StatefulWidget {
  const _LinkSheet({
    required this.campus,
    required this.dept,
    required this.department,
    this.course,
    this.actingFor,
    this.existing,
    this.fixing = false,
  });

  final String campus, dept;
  final List<Resource> department;
  final String? course, actingFor;
  final Resource? existing;
  final bool fixing;

  @override
  State<_LinkSheet> createState() => _LinkSheetState();
}

class _LinkSheetState extends State<_LinkSheet> {
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _url = TextEditingController(text: widget.existing?.url);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final url = _url.text.trim();
    if (title.isEmpty) return setState(() => _error = 'Give it a name.');
    if (allowedHostOf(url) == null) {
      return setState(
        () =>
            _error =
                'Use an https link to Drive, Docs, YouTube, GitHub, Notion, '
                'OneDrive or Dropbox.',
      );
    }
    setState(() => _busy = true);
    try {
      final e = widget.existing;
      if (e == null) {
        final c = widget.course;
        await _store.add(
          Resource(
            id: '',
            title: title,
            url: url,
            campus: widget.campus,
            department: widget.dept,
            scope: c == null ? 'department' : 'course',
            courseIds: c == null ? const [] : [c],
            pinnedToDepartment:
                c != null && shouldRollUp(widget.department, url),
          ),
          actingFor: widget.actingFor,
        );
      } else {
        await _store.update(
          e,
          e.copyWith(title: title, url: url),
          widget.fixing
              ? 'Fixed the reported link “$title”'
              : 'Edited “$title”',
          actingFor: widget.actingFor,
          closeFlag: widget.fixing,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (err) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = problem(err);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final head =
        widget.fixing
            ? 'Fix the link'
            : widget.existing != null
            ? 'Edit link'
            : 'Add a link${widget.course == null ? '' : ' to ${widget.course}'}';
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Space.gutter,
        Space.lg,
        Space.gutter,
        MediaQuery.viewInsetsOf(context).bottom + Space.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(head, style: TypeScale.title),
          const SizedBox(height: Space.sm),
          AppTextField(
            controller: _title,
            label: 'Name',
            hint: 'Past papers — all years',
          ),
          const SizedBox(height: Space.sm),
          AppTextField(
            controller: _url,
            label: 'Link',
            hint: 'https://drive.google.com/…',
          ),
          if (widget.existing?.rolledUp ?? false)
            Text(
              'One link, listed twice — editing it here changes it on '
              '${widget.existing!.fromCourse} as well.',
              style: TypeScale.caption.copyWith(color: p.textMuted),
            ),
          if (widget.fixing)
            Text(
              'Saving closes its reports. Both are logged.',
              style: TypeScale.caption.copyWith(color: p.textMuted),
            ),
          if (_error != null)
            Text(_error!, style: TypeScale.caption.copyWith(color: p.behind)),
          const SizedBox(height: Space.md),
          PrimaryButton(
            label: _busy ? 'Saving…' : 'Save',
            onPressed: _busy ? null : _save,
          ),
        ],
      ),
    );
  }
}

/// A tab label that turns amber and pulses while anything is reported
/// (§16.3 fix 17); still under reduced motion.
class PulsingTab extends StatefulWidget {
  const PulsingTab({super.key, required this.label, required this.active});
  final String label;
  final bool active;

  @override
  State<PulsingTab> createState() => _PulsingTabState();
}

class _PulsingTabState extends State<PulsingTab>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(PulsingTab old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.active && !still) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    if (!widget.active) return Text(widget.label);
    final t = p.noticeTone;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final v = _c.value;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: t.fill,
            borderRadius: BorderRadius.circular(99),
            boxShadow: [
              BoxShadow(
                color: t.text.withValues(alpha: 0.35 * (1 - v)),
                spreadRadius: 6 * v,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: t.text.withValues(alpha: 0.5 + 0.5 * (1 - v)),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(widget.label, style: TextStyle(color: t.text)),
            ],
          ),
        );
      },
    );
  }
}

typedef _Data = ({List<Resource> links, List<ResourceFlag> flags});

/// Boards `DeptResources` and `DeptResourcesReported`: the department's
/// links, its courses' links, and every open report (§16.3 fix 17). A CR
/// opens it filtered to their course.
class DeptResources extends StatefulWidget {
  const DeptResources({
    super.key,
    required this.campus,
    required this.dept,
    this.course,
    this.initialTab = 0,
  });

  final String campus, dept;

  /// A CR's view: their course's links and reports only.
  final String? course;
  final int initialTab;

  @override
  State<DeptResources> createState() => _DeptResourcesState();
}

class _DeptResourcesState extends State<DeptResources> {
  late int _tab = widget.initialTab;
  int _loads = 0;

  Future<_Data> _load() async {
    final links = await _store.department(widget.campus, widget.dept);
    final c = widget.course;
    final flags =
        c == null
            ? await _store.flags(widget.campus, widget.dept)
            : await _store.courseFlags(widget.campus, c);
    return (links: links, flags: flags);
  }

  void _reload() => setState(() => _loads++);

  @override
  Widget build(BuildContext context) {
    final course = widget.course;
    return Loaded<_Data>(
      key: ValueKey(_loads),
      load: _load,
      builder: (context, data, _) {
        final dept = departmentList(data.links);
        final reported = data.flags.length;
        final tabs = [
          if (course == null) 'Dept ${dept.length}',
          if (course == null) 'By course',
          'Reported${reported == 0 ? '' : ' $reported'}',
        ];
        final tab = _tab.clamp(0, tabs.length - 1);
        final reportedTab = tab == tabs.length - 1;
        return PageFrame(
          header: PageHeader(
            eyebrow:
                '${campusName(widget.campus).toUpperCase()} · '
                '${course ?? widget.dept}',
            title: 'Resources',
          ),
          children: [
            Wrap(
              spacing: Space.xs,
              children: [
                for (var i = 0; i < tabs.length; i++)
                  ChoiceChip(
                    selected: i == tab,
                    onSelected: (_) => setState(() => _tab = i),
                    label:
                        i == tabs.length - 1
                            ? PulsingTab(label: tabs[i], active: reported > 0)
                            : Text(tabs[i]),
                  ),
              ],
            ),
            const SizedBox(height: Space.md),
            if (reportedTab)
              ..._reported(context, data)
            else if (tab == 0)
              ..._dept(context, data, dept)
            else
              ..._byCourse(context, data),
          ],
        );
      },
    );
  }

  List<Widget> _dept(BuildContext context, _Data data, List<Resource> dept) => [
    RowGroup(
      children: [
        for (final r in dept)
          LinkRow(
            r: r,
            tag: r.rolledUp ? 'ROLLED UP' : null,
            onTap: () async {
              if (await editLink(
                context,
                campus: widget.campus,
                dept: widget.dept,
                department: data.links,
                existing: r,
              )) {
                _reload();
              }
            },
            trailing:
                r.rolledUp
                    ? TextButton(
                      onPressed: () async {
                        await _store.update(
                          r,
                          r.copyWith(pinnedToDepartment: false),
                          'Unpinned “${r.title}” from ${widget.dept}',
                        );
                        _reload();
                      },
                      child: const Text('Unpin'),
                    )
                    : IconButton(
                      tooltip: 'Remove',
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      onPressed: () async {
                        await _store.update(
                          r,
                          r.copyWith(removed: true),
                          'Removed “${r.title}” from ${widget.dept}',
                        );
                        _reload();
                      },
                    ),
          ),
      ],
    ),
    if (dept.isEmpty) const Note('No department links yet.'),
    const Note(
      'A link a CR adds to a course appears here too, unless the department '
      'already has it. Matching is on the address, not the name. Unpin '
      'removes it from this list only.',
    ),
    const SizedBox(height: Space.sm),
    PrimaryButton(
      label: 'Add a link',
      icon: Icons.add_rounded,
      onPressed: () async {
        if (await editLink(
          context,
          campus: widget.campus,
          dept: widget.dept,
          department: data.links,
        )) {
          _reload();
        }
      },
    ),
  ];

  List<Widget> _byCourse(BuildContext context, _Data data) {
    final byCourse = <String, List<Resource>>{};
    for (final r in data.links.where((r) => !r.removed)) {
      for (final c in r.courseIds) {
        (byCourse[c] ??= []).add(r);
      }
    }
    final ids = byCourse.keys.toList()..sort();
    return [
      for (final id in ids) ...[
        SectionLabel(id),
        RowGroup(
          children: [
            for (final r in byCourse[id]!)
              LinkRow(
                r: r,
                tag: r.isCourse ? null : 'IN DEPT',
                onTap: () async {
                  if (await editLink(
                    context,
                    campus: widget.campus,
                    dept: widget.dept,
                    department: data.links,
                    existing: r,
                  )) {
                    _reload();
                  }
                },
              ),
          ],
        ),
      ],
      if (ids.isEmpty) const Note('No course links yet.'),
    ];
  }

  List<Widget> _reported(BuildContext context, _Data data) {
    final byId = {for (final r in data.links) r.id: r};
    return [
      if (data.flags.isNotEmpty)
        SectionLabel(
          '${data.flags.length} link${data.flags.length == 1 ? '' : 's'} '
          'reported',
        ),
      for (final f in data.flags)
        if (byId[f.resourceId] case final r?) ...[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinkRow(r: r, showAdder: false),
                Text(
                  '${f.top.label} · ${f.count} report${f.count == 1 ? '' : 's'}'
                  '${r.fromCourse == null ? '' : ' · from ${r.fromCourse}'}',
                  style: TypeScale.caption.copyWith(
                    color: AppPalette.of(context).noticeTone.text,
                  ),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () async {
                        if (await editLink(
                          context,
                          campus: widget.campus,
                          dept: widget.dept,
                          department: data.links,
                          existing: r,
                          actingFor: widget.course,
                          fixing: true,
                        )) {
                          _reload();
                        }
                      },
                      child: const Text('Fix the link'),
                    ),
                    TextButton(
                      onPressed: () async {
                        try {
                          await _store.dismiss(f, r.title);
                          _reload();
                        } catch (e) {
                          if (context.mounted) _say(context, problem(e));
                        }
                      },
                      child: const Text('It works · dismiss'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.sm),
        ],
      if (data.flags.isEmpty) const Note('Nothing reported.'),
      Note(
        'A link stays up until someone here fixes it or dismisses the report. '
        'Fix the link edits it in place and closes its reports; It works '
        'dismisses them. Both are logged.'
        '${widget.course == null ? ' A CR sees this tab with their own '
                'course\'s reports only.' : ''}',
      ),
    ];
  }
}

/// `CrHome`'s course resources: the course's links, Add, Pick from the
/// department, and one pulsing amber row while any is reported.
class CourseResources extends StatefulWidget {
  const CourseResources({
    super.key,
    required this.campus,
    required this.courseId,
  });
  final String campus, courseId;

  @override
  State<CourseResources> createState() => _CourseResourcesState();
}

class _CourseResourcesState extends State<CourseResources> {
  int _loads = 0;
  String get _dept => deptOf(widget.courseId);

  Future<_Data> _load() async => (
    links: await _store.department(widget.campus, _dept),
    flags: await _store.courseFlags(widget.campus, widget.courseId),
  );

  Future<void> _pick(List<Resource> links) async {
    final choices = [
      for (final r in departmentList(links))
        if (!r.courseIds.contains(widget.courseId)) r,
    ];
    final r = await showModalBottomSheet<Resource>(
      context: context,
      builder:
          (context) => ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.all(Space.lg),
                child: Text('Pick from department resources'),
              ),
              for (final r in choices)
                LinkRow(r: r, onTap: () => Navigator.pop(context, r)),
              if (choices.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(Space.lg),
                  child: Text('Nothing else in the department yet.'),
                ),
            ],
          ),
    );
    if (r == null) return;
    try {
      await _store.update(
        r,
        r.copyWith(courseIds: [...r.courseIds, widget.courseId]),
        'Linked “${r.title}” to ${widget.courseId}',
        actingFor: widget.courseId,
      );
      setState(() => _loads++);
    } catch (e) {
      if (mounted) _say(context, problem(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Loaded<_Data>(
      key: ValueKey(_loads),
      load: _load,
      builder: (context, data, _) {
        final mine = courseList(data.links, widget.courseId);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: SectionLabel('Course resources')),
                TextButton(
                  onPressed: () async {
                    if (await editLink(
                      context,
                      campus: widget.campus,
                      dept: _dept,
                      department: data.links,
                      course: widget.courseId,
                      actingFor: widget.courseId,
                    )) {
                      setState(() => _loads++);
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            ),
            if (data.flags.isNotEmpty)
              AppCard(
                color: p.noticeTone.fill,
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder:
                          (_) => DeptResources(
                            campus: widget.campus,
                            dept: _dept,
                            course: widget.courseId,
                          ),
                    ),
                  );
                  setState(() => _loads++);
                },
                child: Row(
                  children: [
                    Expanded(
                      child: PulsingTab(
                        label:
                            '${data.flags.length} LINK'
                            '${data.flags.length == 1 ? '' : 'S'} REPORTED',
                        active: true,
                      ),
                    ),
                    Text('Open', style: TextStyle(color: p.noticeTone.text)),
                  ],
                ),
              ),
            const SizedBox(height: Space.xs),
            RowGroup(
              children: [
                for (final r in mine)
                  LinkRow(
                    r: r,
                    tag: r.isCourse ? null : 'IN DEPT',
                    onTap:
                        r.isCourse && r.fromCourse == widget.courseId
                            ? () async {
                              if (await editLink(
                                context,
                                campus: widget.campus,
                                dept: _dept,
                                department: data.links,
                                existing: r,
                                actingFor: widget.courseId,
                              )) {
                                setState(() => _loads++);
                              }
                            }
                            : null,
                  ),
              ],
            ),
            if (mine.isEmpty) const Note('No links for this course yet.'),
            TextButton.icon(
              onPressed: () => _pick(data.links),
              icon: const Icon(Icons.playlist_add_rounded),
              label: const Text('Pick from department resources'),
            ),
          ],
        );
      },
    );
  }
}
