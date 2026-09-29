import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/resources/resource.dart';
import 'package:cgpa_calculator/core/resources/resource_store.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/features/resources/resources_page.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/bottom_action.dart';
import 'package:cgpa_calculator/shared/widgets/pill_button.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:cgpa_calculator/shared/widgets/sliver_row_group.dart';
import 'package:cgpa_calculator/shared/widgets/dashed_outline.dart';
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

/// An http or https address with a host: any website, not a fixed list.
bool isWebLink(String url) {
  final u = Uri.tryParse(url.trim());
  return u != null &&
      (u.scheme == 'https' || u.scheme == 'http') &&
      u.host.contains('.');
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
    // Any website: an article is as good as a Drive folder. A bad link is
    // what the Reported tab is for.
    if (!isWebLink(url)) {
      return setState(() => _error = 'Paste a web link, starting https://.');
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
          AppTextField(controller: _url, label: 'Link', hint: 'https://…'),
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

/// Drives a reported pulse: runs only while [active] and its page is on top
/// (a pushed page pauses it). Under reduced motion it keeps a slower, dot-only
/// pulse, 1 ↔ 0.4 over 2400 ms: the board keeps the Reported dot pulsing
/// (UI.md §10.1.2; UI_OPT O6.1).
mixin _Pulse<T extends StatefulWidget>
    on State<T>, SingleTickerProviderStateMixin<T> {
  late final pulse = AnimationController(vsync: this);
  bool still = false;

  bool get active;
  Duration get period;

  /// Runs there and back rather than restarting; always under reduced motion.
  bool get bounce => still;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncPulse();
  }

  void syncPulse() {
    final s = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final shown = ModalRoute.isCurrentOf(context) ?? true;
    if (s != still || pulse.duration == null) {
      still = s;
      pulse.stop();
      pulse.duration = s ? const Duration(milliseconds: 2400) : period;
    }
    if (active && shown) {
      if (!pulse.isAnimating) pulse.repeat(reverse: bounce);
    } else {
      pulse.stop();
    }
  }

  @override
  void dispose() {
    pulse.dispose();
    super.dispose();
  }
}

/// A tab label that turns amber and pulses while anything is reported
/// (§16.3 fix 17). Only a ring layer and the dot animate, by transform and
/// opacity; the pill itself never rebuilds per tick (UI_OPT O6.1).
class PulsingTab extends StatefulWidget {
  const PulsingTab({super.key, required this.label, required this.active});
  final String label;
  final bool active;

  @override
  State<PulsingTab> createState() => _PulsingTabState();
}

class _PulsingTabState extends State<PulsingTab>
    with SingleTickerProviderStateMixin, _Pulse {
  @override
  bool get active => widget.active;

  @override
  Duration get period => const Duration(milliseconds: 1800);

  @override
  void didUpdateWidget(PulsingTab old) {
    super.didUpdateWidget(old);
    syncPulse();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    if (!widget.active) return Text(widget.label);
    final t = p.noticeTone;
    final shape = BorderRadius.circular(99);
    final pill = DecoratedBox(
      decoration: BoxDecoration(color: t.fill, borderRadius: shape),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: Tween(begin: 1.0, end: still ? 0.4 : 0.5).animate(pulse),
              child: SizedBox.square(
                dimension: 7,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: t.text,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(widget.label, style: TextStyle(color: t.text)),
          ],
        ),
      ),
    );
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.passthrough,
        clipBehavior: Clip.none,
        children: [
          // The ring: grows 6 px past the pill and fades, as the old
          // spreading shadow did, by transform and opacity only.
          if (!still)
            Positioned.fill(
              child: FadeTransition(
                opacity: Tween(begin: 0.35, end: 0.0).animate(pulse),
                child: LayoutBuilder(
                  builder:
                      (_, c) => AnimatedBuilder(
                        animation: pulse,
                        builder:
                            (_, ring) => Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.diagonal3Values(
                                1 + 12 * pulse.value / c.maxWidth,
                                1 + 12 * pulse.value / c.maxHeight,
                                1,
                              ),
                              child: ring,
                            ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: t.text,
                            borderRadius: shape,
                          ),
                        ),
                      ),
                ),
              ),
            ),
          pill,
        ],
      ),
    );
  }
}

/// Department Resources' tabs: equal pills that ease between states. The
/// last one is Reported; while anything is reported it is amber with a
/// pulsing dot, and amber-filled when selected.
class _Tabs extends StatefulWidget {
  const _Tabs({
    required this.tabs,
    required this.selected,
    required this.reported,
    required this.onSelected,
  });
  final List<String> tabs;
  final int selected;
  final bool reported;
  final ValueChanged<int> onSelected;

  @override
  State<_Tabs> createState() => _TabsState();
}

class _TabsState extends State<_Tabs>
    with SingleTickerProviderStateMixin, _Pulse {
  @override
  bool get active => widget.reported;

  @override
  Duration get period => const Duration(milliseconds: 1400);

  @override
  bool get bounce => true;

  @override
  void didUpdateWidget(_Tabs old) {
    super.didUpdateWidget(old);
    syncPulse();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final t = p.noticeTone;
    Widget pill(int i) {
      final on = i == widget.selected;
      final amber = widget.reported && i == widget.tabs.length - 1;
      final fill =
          on
              ? (amber ? t.text : p.inverse)
              : (amber ? t.fill : p.inverse.withValues(alpha: 0));
      final ink =
          on ? (amber ? t.fill : p.onInverse) : (amber ? t.text : p.text);
      final edge = on || amber ? fill : p.border;
      return Semantics(
        selected: on,
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onSelected(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            height: Sizes.pill,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: ShapeDecoration(
              color: fill,
              shape: StadiumBorder(side: BorderSide(color: edge)),
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (amber) ...[
                      // Its own layer: only the dot's opacity moves.
                      RepaintBoundary(
                        child: FadeTransition(
                          opacity: Tween(
                            begin: still ? 0.4 : 0.35,
                            end: 1.0,
                          ).animate(pulse),
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: ink,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 220),
                      style: TypeScale.body.copyWith(
                        fontSize: 12.5,
                        fontWeight: on ? FontWeight.w700 : FontWeight.w600,
                        color: ink,
                      ),
                      child: Text(widget.tabs[i], maxLines: 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        for (var i = 0; i < widget.tabs.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(child: pill(i)),
        ],
      ],
    );
  }
}

/// A link a CR's course rolled up into the department list: a mint wash.
class _RolledUp extends StatelessWidget {
  const _RolledUp({required this.on, required this.child});
  final bool on;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      on
          ? ColoredBox(
            color: AppPalette.of(context).hero.withValues(alpha: 0.35),
            child: child,
          )
          : child;
}

/// The ink card that says how course links roll up.
class _RollupCard extends StatelessWidget {
  const _RollupCard();

  @override
  Widget build(BuildContext context) => const InkCard(
    eyebrow: 'ROLLUP',
    text:
        'A link a CR adds to a course appears here too, unless the '
        'department already has it. Matching is on the address, not the '
        'name. Unpin removes it from this list only.',
  );
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
    // A report can outlive its link (removed, or moved departments); drop
    // it here so every count on this screen agrees with what is listed
    // (BUG-13: "Reported 4" over a list of 1).
    final ids = {for (final r in links) r.id};
    return (
      links: links,
      flags: [
        for (final f in flags)
          if (ids.contains(f.resourceId)) f,
      ],
    );
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
          bottom:
              course == null && tab == 0
                  ? BottomAction(
                    child: PrimaryButton(
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
                  )
                  : null,
          children: [
            _Tabs(
              tabs: tabs,
              selected: tab,
              reported: reported > 0,
              onSelected: (i) => setState(() => _tab = i),
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
    SliverRowGroup(
      count: dept.length,
      row: (context, i) {
        final r = dept[i];
        return _RolledUp(
          on: r.rolledUp,
          child: LinkRow(
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
                    ? TextLink(
                      'Unpin',
                      onTap: () async {
                        await _store.update(
                          r,
                          r.copyWith(pinnedToDepartment: false),
                          'Unpinned “${r.title}” from ${widget.dept}',
                        );
                        _reload();
                      },
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
        );
      },
    ),
    if (dept.isEmpty) const Note('No department links yet.'),
    const SizedBox(height: Space.md),
    const _RollupCard(),
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
    final t = AppPalette.of(context).noticeTone;
    return [
      if (data.flags.isNotEmpty) ...[
        AppCard(
          color: t.fill,
          child: Text(
            '${data.flags.length} LINK${data.flags.length == 1 ? '' : 'S'} '
            'REPORTED · '
            '${widget.course ?? 'DEPARTMENT AND ROLLED-UP COURSE LINKS'}',
            style: TypeScale.label.copyWith(
              color: t.text,
              letterSpacing: 1,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: Space.sm),
      ],
      for (final f in data.flags)
        if (byId[f.resourceId] case final r?) ...[
          AppCard(
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinkRow(r: r, showAdder: false),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${f.top.label} · ${f.count} report${f.count == 1 ? '' : 's'}'
                        '${r.fromCourse == null ? '' : ' · from ${r.fromCourse}'}',
                        style: TypeScale.caption.copyWith(
                          fontWeight: FontWeight.w700,
                          color: t.text,
                        ),
                      ),
                      const SizedBox(height: Space.sm),
                      Wrap(
                        spacing: Space.sm,
                        runSpacing: Space.sm,
                        children: [
                          PillButton(
                            label: 'Fix the link',
                            selected: true,
                            height: 34,
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
                          ),
                          AmberPill(
                            'It works · dismiss',
                            onTap: () async {
                              try {
                                await _store.dismiss(f, r.title);
                                _reload();
                              } catch (e) {
                                if (context.mounted) _say(context, problem(e));
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
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
                TextLink(
                  'Add',
                  onTap: () async {
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
                            initialTab: 2,
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
                    Text(
                      'Open',
                      style: TypeScale.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: p.noticeTone.text,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: p.noticeTone.text,
                    ),
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
            const SizedBox(height: Space.sm),
            DashedOutline(
              color: p.textMuted,
              radius: 22,
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => _pick(data.links),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.playlist_add_rounded,
                          size: 18,
                          color: p.text,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Pick from department resources',
                            style: TypeScale.body.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
