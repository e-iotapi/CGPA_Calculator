import 'package:cgpa_calculator/admin/bulk_upload.dart';
import 'package:cgpa_calculator/admin/dept_resources.dart';
import 'package:cgpa_calculator/admin/offering_scale.dart';
import 'package:cgpa_calculator/admin/professors.dart';
import 'package:cgpa_calculator/admin/scheme_editor.dart';
import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/routes.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/shared/widgets/count_badge.dart';
import 'package:cgpa_calculator/core/catalog/catalog.dart';
import 'package:cgpa_calculator/core/grading/eval_import.dart';
import 'package:cgpa_calculator/core/models/offering.dart';
import 'package:cgpa_calculator/core/platform/browser.dart';
import 'package:cgpa_calculator/core/roles/maintain_store.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/features/marks/official.dart';
import 'package:cgpa_calculator/mastercourselist.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:cgpa_calculator/core/professors/professor_store.dart';
import 'package:cgpa_calculator/core/resources/resource.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cgpa_calculator/features/resources/resources_page.dart';
import 'package:cgpa_calculator/features/reviews/review_widgets.dart';
import 'package:cgpa_calculator/shared/widgets/card_row.dart';
import 'package:cgpa_calculator/shared/widgets/dashed_outline.dart';
import 'package:cgpa_calculator/shared/widgets/pill_button.dart';
import 'package:cgpa_calculator/shared/debounce.dart';
import 'package:cgpa_calculator/shared/widgets/search_box.dart';
import 'package:cgpa_calculator/shared/widgets/sliver_row_group.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

MaintainStore get _store => MaintainStore(roleStore!);

/// The term maintainers edit: the one running now.
String get maintainedTerm => currentTerm(DateTime.now());

/// [dept]'s courses on offer, by code (§4: electronics is one department).
List<Mastercourselist> deptCourses(String dept) =>
    catalog.master
        .where((m) => deptOf(m.id) == dept && !catalog.retired.contains(m.id))
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));

String courseTitle(String id) =>
    catalog.master.where((m) => m.id == id).firstOrNull?.title ?? '';

/// "4 components · 100% assigned", or "No scheme yet".
String schemeLine(Offering? o) {
  if (o == null || !o.hasScheme) return 'No scheme yet';
  final n = o.components.length;
  final sum = o.components.fold(0.0, (s, c) => s + c.weight);
  final total =
      o.weighted
          ? '${_n(sum)}% assigned'
          : '${_n(sum)} of ${_n(o.totalMarks)} marks';
  return '$n component${n == 1 ? '' : 's'} · $total';
}

String _n(double d) =>
    d == d.roundToDouble() ? '${d.toInt()}' : d.toStringAsFixed(1);

/// The programme a president was appointed for, when there is one.
String _scopeLabel(String campus, String dept) {
  final g =
      myRoles.value.presidencies
          .where((g) => g.campus == campus && g.scope == dept)
          .firstOrNull;
  return g?.scopeLabel ?? dept;
}

/// A value that is only decoration on [DeptHome]: null when it can't load.
Future<T?> _maybe<T>(Future<T>? f) async {
  try {
    return await f;
  } catch (_) {
    return null;
  }
}

typedef _HomeData =
    ({
      Map<String, Offering> offerings,
      int? links,
      int? flagged,
      int? reported,
      int? profs,
      List<AuditEntry>? audit,
    });

/// Board `DeptHome`: a president's department on their campus.
class DeptHome extends StatelessWidget {
  const DeptHome({super.key, required this.campus, required this.dept});
  final String campus, dept;

  Future<_HomeData> _load() async {
    final courses = deptCourses(dept);
    final links = await _maybe(resourceStore?.department(campus, dept));
    final flags = await _maybe(resourceStore?.flags(campus, dept));
    final reported = await _maybe(
      reviewStore?.moderation(campus, dept, hidden: false, reportedOnly: true),
    );
    final profs = await _maybe(
      ProfessorStore(roleStore!.db, roles: roleStore).department(campus, dept),
    );
    return (
      offerings: await _store.offerings(
        courses.map((c) => c.id),
        campus,
        maintainedTerm,
      ),
      links: links == null ? null : departmentList(links).length,
      flagged: flags?.length,
      reported: reported?.length,
      profs: profs?.length,
      audit: await _maybe(roleStore!.audit(campus: campus, limit: 200)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final courses = deptCourses(dept);
    final ids = {for (final c in courses) c.id};
    final mine =
        myRoles.value.presidencies
            .where((g) => g.campus == campus && g.scope == dept)
            .firstOrNull
            ?.programme;
    final others = [
      for (final x in departments[dept]?.programmes ?? const <String>[])
        if (x != mine) x,
    ];
    final shared =
        others.isEmpty || (mine == null && others.length < 2)
            ? ''
            : '. You share it, as equals, with the ${others.join(', ')} '
                'president${others.length == 1 ? '' : 's'}';
    return Loaded<_HomeData>(
      load: _load,
      builder: (context, d, reload) {
        final missing =
            courses
                .where((c) => !(d.offerings[c.id]?.hasScheme ?? false))
                .length;
        Widget badge(int? n) =>
            n == null || n == 0 ? const SizedBox.shrink() : CountBadge('$n');
        String plural(int n, String one) => '$n $one${n == 1 ? '' : 's'}';

        final rows = [
          CardRow(
            leading: IconTile(Icons.account_tree_outlined),
            title: 'Course structures',
            titleLines: 2,
            subtitle:
                '${plural(courses.length, 'course')}'
                '${missing == 0 ? '' : ' · $missing without a scheme'}',
            trailing: badge(missing),
            minHeight: 58,
            onTap: () async {
              await context.push(Routes.deptCourses(campus, dept));
              reload();
            },
          ),
          CardRow(
            leading: IconTile(Icons.link_rounded),
            title: 'Resources',
            subtitle:
                d.links == null
                    ? 'Department and course links'
                    : '${plural(d.links!, 'link')}'
                        '${(d.flagged ?? 0) == 0 ? '' : ' · ${d.flagged} reported'}',
            trailing: badge(d.flagged),
            minHeight: 58,
            onTap: () async {
              await context.push(Routes.deptResources(campus, dept));
              reload();
            },
          ),
          CardRow(
            leading: IconTile(Icons.rate_review_outlined),
            title: 'Reviews',
            subtitle:
                d.reported == null || d.reported == 0
                    ? 'Nothing reported'
                    : '${plural(d.reported!, 'review')} reported',
            trailing: badge(d.reported),
            minHeight: 58,
            onTap: () async {
              await context.push(Routes.deptReviews(campus, dept));
              reload();
            },
          ),
          CardRow(
            leading: IconTile(Icons.school_outlined),
            title: 'Professors',
            subtitle:
                d.profs == null
                    ? 'Add, rename, merge duplicates'
                    : '${plural(d.profs!, 'professor')} · add, rename, merge',
            minHeight: 58,
            onTap: () => context.push(Routes.deptProfessors(campus, dept)),
          ),
          CardRow(
            leading: IconTile(Icons.badge_outlined),
            title: 'People',
            subtitle: 'Presidents and CRs on your campus',
            minHeight: 58,
            onTap: () => context.push(Routes.adminRoster),
          ),
        ];

        final me = roleStore!.me;
        final week = DateTime.now().subtract(const Duration(days: 7));
        final recent = [
          for (final e in d.audit ?? const <AuditEntry>[])
            if ((e.at?.isAfter(week) ?? false) &&
                (e.actorEmail == me || ids.contains(e.course)))
              e,
        ];
        final byMe = recent.where((e) => e.actorEmail == me).length;
        final byPres =
            recent
                .where((e) => e.actorEmail != me && e.actorRole == 'dept')
                .length;
        final byCrs = recent.where((e) => e.actorRole == 'course').length;

        return PageFrame(
          header: const PageHeader(
            eyebrow: 'DEPARTMENT PRESIDENT',
            title: 'Your department',
            leading: false,
          ),
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ScopeChip(campusName(campus), icon: Icons.place_outlined),
                ScopeChip(_scopeLabel(campus, dept), muted: true),
                ScopeChip(termLabel(maintainedTerm), muted: true),
              ],
            ),
            const SizedBox(height: Space.sm),
            Text(
              'Everything below is ${campusName(campus)} '
              '${departmentName(dept).toLowerCase()}'
              '$shared. '
              'The audit log says who changed what.',
              style: TypeScale.caption.copyWith(
                height: 1.45,
                color: p.textMuted,
              ),
            ),
            const SizedBox(height: Space.md),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final (i, r) in rows.indexed) ...[
                    if (i > 0) const CardDivider(),
                    r,
                  ],
                ],
              ),
            ),
            const SizedBox(height: Space.sm),
            AppCard(
              padding: EdgeInsets.zero,
              child: CardRow(
                leading: IconTile(Icons.swap_horiz_rounded, amber: true),
                title: 'Hand over to your successor',
                titleLines: 2,
                subtitle: 'They start now · you keep access for 20 days',
                minHeight: 58,
                onTap: () => context.push(Routes.deptSuccession(campus, dept)),
              ),
            ),
            const SizedBox(height: Space.sm),
            InkCard(
              eyebrow: 'THIS WEEK',
              children: [
                Text(
                  '$byMe by you · $byPres by other presidents · '
                  '$byCrs by CRs',
                  style: TypeScale.body.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                    color: p.isDark ? p.text : p.onInverse,
                  ),
                ),
                const SizedBox(height: Space.xs),
                InkWell(
                  onTap: () => context.push(Routes.adminAudit),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Audit log',
                          style: TypeScale.body.copyWith(
                            fontWeight: FontWeight.w700,
                            color: p.hero,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: p.hero,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Board `DeptCourses`: the department's courses this term, each opening the
/// eval structure editor, and the JSON bulk upload (§13.2).
class DeptCourses extends StatefulWidget {
  const DeptCourses({super.key, required this.campus, required this.dept});
  final String campus, dept;

  @override
  State<DeptCourses> createState() => _DeptCoursesState();
}

class _DeptCoursesState extends State<DeptCourses> {
  final _search = TextEditingController();

  /// The list follows the search after a pause in typing (UI_OPT O5.2).
  final _typed = Debouncer();
  bool _missingOnly = false;
  int _loads = 0;

  @override
  void dispose() {
    _typed.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _upload(String? source) async {
    if (source == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BulkUploadPage(campus: widget.campus, source: source),
      ),
    );
    setState(() => _loads++);
  }

  Future<void> _paste() async {
    final c = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Paste JSON'),
            content: SizedBox(
              width: 480,
              child: TextField(
                controller: c,
                maxLines: 12,
                minLines: 6,
                decoration: const InputDecoration(
                  hintText: '{"schema":"pointer.eval.v1", …}',
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, c.text),
                child: const Text('Preview'),
              ),
            ],
          ),
    );
    c.dispose();
    await _upload(text);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final courses = deptCourses(widget.dept);
    return Loaded<(Map<String, Offering>, Map<String, String>)>(
      key: ValueKey(_loads),
      load: () async {
        final offerings = await _store.offerings(
          courses.map((c) => c.id),
          widget.campus,
          maintainedTerm,
        );
        final grants = await _maybe(roleStore!.roster(campus: widget.campus));
        return (
          offerings,
          {
            for (final g in grants ?? const <Grant>[])
              if (g.active && g.role == GrantRole.course) g.scope: g.email,
          },
        );
      },
      builder: (context, data, reload) {
        final (offerings, crs) = data;
        final q = _search.text.trim().toLowerCase();
        final shown = [
          for (final c in courses)
            if ((q.isEmpty ||
                    c.id.toLowerCase().contains(q) ||
                    c.title.toLowerCase().contains(q)) &&
                (!_missingOnly || !(offerings[c.id]?.hasScheme ?? false)))
              c,
        ];
        return PageFrame(
          header: PageHeader(
            eyebrow:
                '${campusName(widget.campus).toUpperCase()} · '
                '${_scopeLabel(widget.campus, widget.dept)} · '
                '${termLabel(maintainedTerm).toUpperCase()}',
            title: 'Course structures',
          ),
          children: [
            _DropZone(
              onFile:
                  () async =>
                      _upload(await pickTextFile('.json,application/json')),
              onPaste: _paste,
            ),
            const SizedBox(height: Space.sm),
            const UploadCard(),
            const SizedBox(height: Space.md),
            SearchBox(
              controller: _search,
              hint: 'Search ${courses.length} courses',
              onChanged:
                  (_) => _typed(() {
                    if (mounted) setState(() {});
                  }),
              trailing: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: TextLink(
                  _missingOnly ? 'All' : 'No scheme',
                  onTap: () => setState(() => _missingOnly = !_missingOnly),
                ),
              ),
            ),
            const SizedBox(height: Space.sm),
            // Lazy: a department has up to ~130 courses (UI_OPT O5.1).
            if (shown.isNotEmpty)
              SliverRowGroup(
                count: shown.length,
                inset: 13,
                row: (context, i) {
                  final c = shown[i];
                  return _CourseRow(
                    title: '${c.id} · ${c.title}',
                    o: offerings[c.id],
                    cr: crs[c.id],
                    onTap: () async {
                      final saved = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder:
                              (_) => SchemeEditorPage(
                                courseId: c.id,
                                campus: widget.campus,
                                term: maintainedTerm,
                                existing: offerings[c.id],
                              ),
                        ),
                      );
                      if (saved == true) reload();
                    },
                  );
                },
              ),
            if (shown.isEmpty) const Note('No course matches.'),
            const SizedBox(height: Space.sm),
            Text(
              'You are editing this term\'s offering. Course titles, codes '
              'and credits belong to the catalogue and are not editable here.',
              style: TypeScale.caption.copyWith(
                height: 1.45,
                color: p.textMuted,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// One course: code and title, then 20 tall chips for its scheme and CR.
class _CourseRow extends StatelessWidget {
  const _CourseRow({
    required this.title,
    required this.o,
    required this.cr,
    required this.onTap,
  });
  final String title;
  final Offering? o;
  final String? cr;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final o = this.o;
    final chips = <Widget>[];
    if (o == null || !o.hasScheme) {
      chips.add(const MiniChip('No scheme yet', dashed: true));
    } else {
      final n = o.components.length;
      final sum = o.components.fold(0.0, (s, c) => s + c.weight);
      final full = o.weighted ? sum >= 100 : sum >= o.totalMarks;
      chips.add(
        MiniChip(
          '$n component${n == 1 ? '' : 's'}',
          fill: p.hero,
          ink: p.onHero,
        ),
      );
      chips.add(
        MiniChip(
          o.weighted
              ? '${_n(sum)}% assigned'
              : '${_n(sum)} of ${_n(o.totalMarks)} marks',
          fill: full ? null : p.noticeTone.fill,
          ink: full ? null : p.noticeTone.text,
        ),
      );
    }
    chips.add(
      cr == null
          ? const MiniChip('No CR', dashed: true)
          : MiniChip('CR: ${shortEmail(cr!)}', ink: p.text),
    );
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 58),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 10, 8, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TypeScale.body.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(spacing: 5, runSpacing: 5, children: chips),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: p.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// The dashed mint drop zone: upload many courses' schemes as JSON.
class _DropZone extends StatelessWidget {
  const _DropZone({required this.onFile, required this.onPaste});
  final VoidCallback onFile, onPaste;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return DashedOutline(
      color: p.hero,
      radius: 22,
      width: 2,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Space.lg),
        decoration: BoxDecoration(
          color: p.hero.withValues(alpha: 0.34),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          children: [
            Icon(Icons.upload_file_rounded, color: p.text),
            const SizedBox(height: 6),
            Text(
              'Upload schemes as JSON',
              textAlign: TextAlign.center,
              style: TypeScale.body.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              'Many courses at once. You see every change before anything '
              'is written.',
              textAlign: TextAlign.center,
              style: TypeScale.caption.copyWith(height: 1.45, color: p.text),
            ),
            const SizedBox(height: Space.md),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                PillButton(
                  label: 'Choose a file',
                  icon: Icons.upload_file_rounded,
                  selected: true,
                  onPressed: onFile,
                ),
                PillButton(label: 'Paste', onPressed: onPaste),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The EXTRACTION PROMPT card: Copy, what it is for, and a quoted preview
/// that Show opens.
class UploadCard extends StatefulWidget {
  const UploadCard({super.key});

  @override
  State<UploadCard> createState() => _UploadCardState();
}

class _UploadCardState extends State<UploadCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final caption = TypeScale.caption.copyWith(
      height: 1.45,
      color: p.textMuted,
    );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'EXTRACTION PROMPT',
                  style: TypeScale.label.copyWith(
                    color: p.textMuted,
                    letterSpacing: 1,
                  ),
                ),
              ),
              PillButton(
                label: 'Copy',
                icon: Icons.copy_rounded,
                selected: true,
                height: 30,
                padding: 12,
                onPressed: () async {
                  await Clipboard.setData(
                    const ClipboardData(text: evalPrompt),
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context)
                    ..clearSnackBars()
                    ..showSnackBar(
                      const SnackBar(content: Text('Prompt copied.')),
                    );
                },
              ),
            ],
          ),
          const SizedBox(height: Space.xs),
          Text(
            'Paste this into any AI tool along with the handout PDFs. It '
            'states the exact shape this page accepts, so what comes back '
            'uploads without hand-editing.',
            style: caption,
          ),
          const SizedBox(height: Space.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            decoration: BoxDecoration(
              color: p.surfaceSunken,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_open)
                  SelectableText(
                    evalPrompt,
                    style: TypeScale.caption.copyWith(height: 1.5),
                  )
                else
                  Text(
                    '“Read every attached course handout and return one JSON '
                    'object…”',
                    style: TypeScale.caption.copyWith(
                      fontStyle: FontStyle.italic,
                      color: p.text,
                    ),
                  ),
                TextLink(
                  _open ? 'Hide' : 'Show',
                  onTap: () => setState(() => _open = !_open),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.sm),
          Text(
            'Handouts differ per professor, so extraction is the messy part, '
            'not the upload. The preview still shows every change before '
            'anything is written.',
            style: caption,
          ),
        ],
      ),
    );
  }
}

/// `CrHome`'s COURSE AVERAGE: the CR types it on the course's scale (0 to
/// "Graded out of", see offering_scale.dart) once it is out; it is stored in
/// course units on this term's offering, with the scheme it belongs to.
class _CourseAverage extends StatefulWidget {
  const _CourseAverage({required this.o, required this.onSaved});
  final Offering o;
  final VoidCallback onSaved;

  @override
  State<_CourseAverage> createState() => _CourseAverageState();
}

class _CourseAverageState extends State<_CourseAverage> {
  late final double _scale = scaleOf(widget.o);
  late final double _units = courseUnits(
    weighted: widget.o.weighted,
    totalMarks: widget.o.totalMarks,
  );

  /// The saved average on the manager's scale.
  late final double? _shown = switch (widget.o.courseAverage) {
    final a? => toShown(a, scale: _scale, units: _units),
    null => null,
  };
  late final _c = TextEditingController(text: _shown == null ? '' : _n(_shown));
  bool _saving = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// The typed value: null when blank, NaN when it isn't 0 to the scale.
  double? get _value {
    final t = _c.text.trim();
    if (t.isEmpty) return null;
    final v = double.tryParse(t);
    return v == null || v < 0 || v > _scale ? double.nan : v;
  }

  Future<void> _save() async {
    final o = widget.o;
    final v = _value;
    setState(() => _saving = true);
    try {
      await _store.save(
        withOutOf(
          Offering(
            courseId: o.courseId,
            campus: o.campus,
            term: o.term,
            weighted: o.weighted,
            totalMarks: o.totalMarks,
            components: o.components,
            courseAverage:
                v == null ? null : toStored(v, scale: _scale, units: _units),
            professors: o.professors,
            updatedAt: o.updatedAt,
          ),
          offeringOutOf(o),
        ),
        v == null
            ? 'Cleared the course average for ${o.courseId} in '
                '${termLabel(o.term)}'
            : 'Set the course average for ${o.courseId} in '
                '${termLabel(o.term)} to ${_n(v)} of ${_n(_scale)}',
      );
      widget.onSaved();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(problem(e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final v = _value;
    final bad = v != null && v.isNaN;
    final changed = v != _shown && !bad;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: AppTextField(
                  controller: _c,
                  label: 'Out of ${_n(_scale)}',
                  hint: 'Blank until it is out',
                  number: true,
                  labelAbove: true,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: Space.sm),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: PillButton(
                  label: _saving ? 'Saving…' : 'Save',
                  selected: true,
                  onPressed: changed && !_saving ? _save : null,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.xs),
        Text(
          bad
              ? 'Type a number from 0 to ${_n(_scale)}.'
              : 'Stored against this term and this component set. Students '
                  'see it beside their own marks; clear it to take it back.',
          style: TypeScale.caption.copyWith(
            height: 1.45,
            color: bad ? p.behind : p.textMuted,
          ),
        ),
      ],
    );
  }
}

Text _name(String name) => Text(
  name,
  style: TypeScale.body.copyWith(fontSize: 13, fontWeight: FontWeight.w700),
);

/// Board `CrHome`: one course, as its CR keeps it this term (§13.3).
class CrHome extends StatelessWidget {
  const CrHome({super.key, required this.campus, required this.courseId});
  final String campus, courseId;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    // Large text puts a component's chips under its name.
    final stack = MediaQuery.textScalerOf(context).scale(10) > 12;
    return Loaded<Offering?>(
      load: () => _store.offering(courseId, campus, maintainedTerm),
      builder: (context, o, reload) {
        Future<void> edit() async {
          final saved = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder:
                  (_) => SchemeEditorPage(
                    courseId: courseId,
                    campus: campus,
                    term: maintainedTerm,
                    existing: o,
                  ),
            ),
          );
          if (saved == true) reload();
        }

        return PageFrame(
          header: PageHeader(eyebrow: 'COURSE MANAGER', title: courseId),
          children: [
            ScopePills(campus: campus, scope: termLabel(maintainedTerm)),
            const SizedBox(height: Space.xs),
            Text(
              courseTitle(courseId),
              style: TypeScale.body.copyWith(color: p.textMuted),
            ),
            const SizedBox(height: Space.md),
            TakenBy(
              campus: campus,
              courseId: courseId,
              offering: o,
              onSaved: reload,
            ),
            const SizedBox(height: Space.md),
            Row(
              children: [
                const Expanded(child: SectionLabel('Evaluation scheme')),
                TextLink(o?.hasScheme ?? false ? 'Edit' : 'Add', onTap: edit),
              ],
            ),
            if (o == null || !o.hasScheme)
              const Note(
                'No scheme yet. Students see their own components until you '
                'add one.',
              )
            else ...[
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, c) in o.components.indexed) ...[
                      if (i > 0) const CardDivider(),
                      InkWell(
                        onTap: edit,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 52),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 10,
                            ),
                            child: Flex(
                              direction:
                                  stack ? Axis.vertical : Axis.horizontal,
                              crossAxisAlignment:
                                  stack
                                      ? CrossAxisAlignment.start
                                      : CrossAxisAlignment.center,
                              children: [
                                if (stack)
                                  _name(c.name)
                                else
                                  Expanded(child: _name(c.name)),
                                const SizedBox(width: Space.sm, height: 6),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    MiniChip(
                                      o.weighted
                                          ? '${_n(c.weight)}%'
                                          : _n(c.weight),
                                      ink: p.text,
                                    ),
                                    const SizedBox(width: 5),
                                    if (c.average case final a?)
                                      MiniChip(
                                        'avg ${a.toStringAsFixed(1)}',
                                        fill: p.hero,
                                        ink: p.onHero,
                                      )
                                    else
                                      const MiniChip('no avg', dashed: true),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: Space.xs),
              Text(
                '${schemeLine(o)} · edited by '
                '${o.updatedByName.isEmpty ? 'someone' : o.updatedByName} '
                '${ago(DateTime.fromMillisecondsSinceEpoch(o.updatedAt))}',
                style: TypeScale.caption.copyWith(color: p.textMuted),
              ),
            ],
            const SectionLabel('Course average'),
            if (o == null || !o.hasScheme)
              const Note(
                'Add the scheme first. An average without its components '
                'compares nothing.',
              )
            else
              _CourseAverage(o: o, onSaved: reload),
            const SizedBox(height: Space.md),
            CourseResources(campus: campus, courseId: courseId),
          ],
        );
      },
    );
  }
}
