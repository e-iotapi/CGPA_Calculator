import 'package:cgpa_calculator/admin/bulk_upload.dart';
import 'package:cgpa_calculator/admin/dept_resources.dart';
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
        Widget tile(IconData icon, {bool amber = false}) {
          final t = p.noticeTone;
          return Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: amber ? t.fill : p.surfaceSunken,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 17, color: amber ? t.text : p.icon),
          );
        }

        Widget badge(int? n) =>
            n == null || n == 0 ? const SizedBox.shrink() : CountBadge('$n');
        String plural(int n, String one) => '$n $one${n == 1 ? '' : 's'}';

        final rows = [
          CardRow(
            leading: tile(Icons.account_tree_outlined),
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
            leading: tile(Icons.link_rounded),
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
            leading: tile(Icons.rate_review_outlined),
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
            leading: tile(Icons.school_outlined),
            title: 'Professors',
            subtitle:
                d.profs == null
                    ? 'Add, rename, merge duplicates'
                    : '${plural(d.profs!, 'professor')} · add, rename, merge',
            minHeight: 58,
            onTap: () => context.push(Routes.deptProfessors(campus, dept)),
          ),
          CardRow(
            leading: tile(Icons.badge_outlined),
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
                leading: tile(Icons.swap_horiz_rounded, amber: true),
                title: 'Hand over to your successor',
                titleLines: 2,
                subtitle: 'They start now · you keep access for 20 days',
                minHeight: 58,
                onTap: () => context.push(Routes.deptSuccession(campus, dept)),
              ),
            ),
            const SizedBox(height: Space.sm),
            AppCard(
              color: p.navBackground,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'THIS WEEK',
                    style: TypeScale.label.copyWith(
                      color: p.hero,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
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
  bool _missingOnly = false;
  int _loads = 0;

  @override
  void dispose() {
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
    return Loaded<Map<String, Offering>>(
      key: ValueKey(_loads),
      load:
          () => _store.offerings(
            courses.map((c) => c.id),
            widget.campus,
            maintainedTerm,
          ),
      builder: (context, offerings, reload) {
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
            UploadCard(
              onFile:
                  () async =>
                      _upload(await pickTextFile('.json,application/json')),
              onPaste: _paste,
            ),
            const SizedBox(height: Space.md),
            AppTextField(
              controller: _search,
              label: 'Search ${courses.length} courses',
              dense: true,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: Space.sm),
            ChoicePills<bool>(
              values: const [false, true],
              selected: _missingOnly,
              label: (v) => v ? 'No scheme' : 'All',
              onSelected: (v) => setState(() => _missingOnly = v),
            ),
            const SizedBox(height: Space.sm),
            RowGroup(
              children: [
                for (final c in shown)
                  NavRow(
                    icon:
                        offerings[c.id]?.hasScheme ?? false
                            ? Icons.check_circle_outline_rounded
                            : Icons.radio_button_unchecked_rounded,
                    title: '${c.id} · ${c.title}',
                    subtitle: schemeLine(offerings[c.id]),
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
                  ),
              ],
            ),
            if (shown.isEmpty) const Note('No course matches.'),
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

/// "Upload schemes as JSON", with the extraction prompt and its Copy button.
class UploadCard extends StatefulWidget {
  const UploadCard({super.key, required this.onFile, required this.onPaste});
  final VoidCallback onFile, onPaste;

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
          Text(
            'Upload schemes as JSON',
            style: TypeScale.body.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            'Many courses at once. You see every change before anything is '
            'written.',
            style: caption,
          ),
          const SizedBox(height: Space.md),
          Container(
            padding: const EdgeInsets.all(Space.md),
            decoration: BoxDecoration(
              color: p.surfaceSunken,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LabelRow(
                  label: Text(
                    'EXTRACTION PROMPT',
                    style: TypeScale.label.copyWith(color: p.textMuted),
                  ),
                  trailing: TextButton.icon(
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
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copy'),
                  ),
                ),
                Text(
                  'Paste this into any AI tool along with the handout PDFs. It '
                  'states the exact shape this page accepts, so what comes '
                  'back uploads without hand-editing.',
                  style: caption,
                ),
                const SizedBox(height: Space.sm),
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
                    ),
                  ),
                TextButton(
                  onPressed: () => setState(() => _open = !_open),
                  child: Text(_open ? 'Hide' : 'Show'),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.md),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: 'Choose a file',
                  icon: Icons.upload_file_rounded,
                  onPressed: widget.onFile,
                ),
              ),
              const SizedBox(width: Space.sm),
              TextButton(onPressed: widget.onPaste, child: const Text('Paste')),
            ],
          ),
          const SizedBox(height: Space.sm),
          Text(
            'Handouts differ per professor, so extraction is the messy part — '
            'not the upload. The preview still shows every change before '
            'anything is written.',
            style: caption,
          ),
        ],
      ),
    );
  }
}

/// Board `CrHome`: one course, as its CR keeps it this term (§13.3).
class CrHome extends StatelessWidget {
  const CrHome({super.key, required this.campus, required this.courseId});
  final String campus, courseId;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
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
            LabelRow(
              label: const SectionLabel('Evaluation scheme'),
              trailing: TextButton(
                onPressed: edit,
                child: Text(o?.hasScheme ?? false ? 'Edit' : 'Add'),
              ),
            ),
            if (o == null || !o.hasScheme)
              const Note(
                'No scheme yet. Students see their own components until you '
                'add one.',
              )
            else ...[
              RowGroup(
                children: [
                  for (final c in o.components)
                    NavRow(
                      icon: Icons.assignment_outlined,
                      title: c.name,
                      subtitle:
                          c.average == null
                              ? 'no avg'
                              : 'avg ${c.average!.toStringAsFixed(1)}',
                      trailing: Text(
                        o.weighted ? '${_n(c.weight)}%' : _n(c.weight),
                        style: TypeScale.body.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onTap: edit,
                    ),
                ],
              ),
              const SizedBox(height: Space.xs),
              Text(
                '${schemeLine(o)} · edited by '
                '${o.updatedByName.isEmpty ? 'someone' : o.updatedByName} '
                '${ago(DateTime.fromMillisecondsSinceEpoch(o.updatedAt))}',
                style: TypeScale.caption.copyWith(color: p.textMuted),
              ),
            ],
            if (o?.courseAverage case final avg?) ...[
              const SectionLabel('Course average'),
              AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'out of 100',
                        style: TypeScale.caption.copyWith(color: p.textMuted),
                      ),
                    ),
                    Text(
                      _n(avg),
                      style: TypeScale.title.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Stored against this term and this component set. An average '
                'without them compares nothing.',
                style: TypeScale.caption.copyWith(color: p.textMuted),
              ),
            ],
            const SizedBox(height: Space.md),
            CourseResources(campus: campus, courseId: courseId),
          ],
        );
      },
    );
  }
}
