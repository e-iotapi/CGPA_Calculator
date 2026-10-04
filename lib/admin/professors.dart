import 'package:cgpa_calculator/admin/grant_form.dart';
import 'package:cgpa_calculator/admin/maintain.dart';
import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/admin/dept_list.dart';
import 'package:cgpa_calculator/admin/duplicates.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/routes.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/models/offering.dart';
import 'package:cgpa_calculator/core/professors/professor.dart';
import 'package:cgpa_calculator/core/professors/professor_store.dart';
import 'package:cgpa_calculator/core/roles/maintain_store.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/bottom_action.dart';
import 'package:cgpa_calculator/shared/widgets/card_row.dart';
import 'package:cgpa_calculator/shared/widgets/circle_icon_button.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:cgpa_calculator/shared/widgets/notice.dart';
import 'package:cgpa_calculator/shared/debounce.dart';
import 'package:cgpa_calculator/shared/widgets/search_box.dart';
import 'package:cgpa_calculator/shared/widgets/sliver_row_group.dart';
import 'package:cgpa_calculator/shared/widgets/confirm_dialog.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

ProfessorStore get _store => ProfessorStore(roleStore!.db, roles: roleStore);

void _say(BuildContext context, String text) =>
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(text)));

/// The Rename dialog.
Future<String?> _nameDialog(
  BuildContext context, {
  required String title,
  String initial = '',
}) async {
  final c = TextEditingController(text: initial);
  final name = await showDialog<String>(
    context: context,
    builder:
        (context) => StatefulBuilder(
          builder: (context, setState) {
            final pal = AppPalette.of(context);
            return AppDialog(
              title: title,
              content: TextField(
                controller: c,
                autofocus: true,
                style: appFieldStyle(pal),
                cursorColor: pal.text,
                decoration: appFieldDecoration(pal, hint: 'Dr. R. Menon'),
                onChanged: (_) => setState(() {}),
              ),
              actions: [
                DialogAction('Cancel', onTap: () => Navigator.pop(context)),
                DialogAction(
                  'Save',
                  onTap:
                      c.text.trim().length < 2
                          ? null
                          : () => Navigator.pop(context, c.text.trim()),
                  ink: true,
                ),
              ],
            );
          },
        ),
  );
  c.dispose();
  return name;
}

typedef _Data =
    ({
      List<Professor> profs,
      Map<String, List<String>> teaching,
      Map<String, String> last,
    });

Future<_Data> _loadDept(String campus, String dept) async {
  final profs = await _store.department(campus, dept);
  final offerings = await MaintainStore(
    roleStore!,
  ).offerings(deptCourses(dept).map((c) => c.id), campus, maintainedTerm);
  final teaching = <String, List<String>>{};
  for (final o in offerings.values) {
    for (final id in o.professors) {
      (teaching[id] ??= []).add(o.courseId);
    }
  }
  final last = <String, String>{};
  for (final x in profs) {
    if (teaching.containsKey(x.id)) continue;
    try {
      final terms = [
        for (final l in (await _store.taught(x, campus)).values) ...l,
      ]..sort();
      if (terms.isNotEmpty) last[x.id] = terms.last;
    } catch (_) {}
  }
  return (profs: profs, teaching: teaching, last: last);
}

/// [_loadDept] from the saved copies; null if any part is not saved.
_Data? _peekDept(String campus, String dept) {
  final profs = _store.peekDepartment(campus, dept);
  final offerings = MaintainStore(
    roleStore!,
  ).peekOfferings(deptCourses(dept).map((c) => c.id), campus, maintainedTerm);
  if (profs == null || offerings == null) return null;
  final teaching = <String, List<String>>{};
  for (final o in offerings.values) {
    for (final id in o.professors) {
      (teaching[id] ??= []).add(o.courseId);
    }
  }
  final last = <String, String>{};
  for (final x in profs) {
    if (teaching.containsKey(x.id)) continue;
    final taught = _store.peekTaught(x, campus);
    if (taught == null) return null;
    final terms = [for (final l in taught.values) ...l]..sort();
    if (terms.isNotEmpty) last[x.id] = terms.last;
  }
  return (profs: profs, teaching: teaching, last: last);
}

/// Opens `ProfessorMerge` for the department; the list reloads after.
Future<void> _openMerge(BuildContext context, String campus, String dept) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfessorMerge(campus: campus, dept: dept),
      ),
    );

/// Board `DeptProfessors`: one entry per person, reused every term. Add
/// opens `ProfessorAdd`, which does the searching for duplicates; removed
/// professors are listed last and keep their reviews.
class DeptProfessors extends StatefulWidget {
  const DeptProfessors({super.key, required this.campus, required this.dept});
  final String campus, dept;

  static String cacheKey(String campus, String dept) =>
      'professors|$campus|$dept';

  /// Loads the screen's data in the background (TM-16).
  static Future<void> prefetch(String campus, String dept) =>
      prefetchLoaded(cacheKey(campus, dept), () => _loadDept(campus, dept));

  @override
  State<DeptProfessors> createState() => _DeptProfessorsState();
}

class _DeptProfessorsState extends State<DeptProfessors> {
  final _search = TextEditingController();

  /// The list follows the search after a pause in typing (UI_OPT O5.2).
  final _typed = Debouncer();
  int _loads = 0;

  @override
  void dispose() {
    _typed.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final loc = Routes.deptProfessorsAdd(widget.campus, widget.dept);
    final q = _search.text.trim();
    final at = q.isEmpty ? loc : '$loc?name=${Uri.encodeQueryComponent(q)}';
    // The page answers with a name when a possible duplicate was tapped: show
    // that professor here instead of adding.
    final open =
        GoRouter.maybeOf(context) != null
            ? await context.push<String>(at)
            : await Navigator.of(context).push<String>(
              MaterialPageRoute(
                builder:
                    (_) => ProfessorAdd(
                      campus: widget.campus,
                      dept: widget.dept,
                      initial: q,
                    ),
              ),
            );
    if (!mounted) return;
    setState(() {
      _loads++;
      if (open != null) _search.text = open;
    });
  }

  Future<void> _delete(Professor x) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete ${x.name}?',
      body:
          'Reviews stay under the name. They are no longer offered in '
          'searches or when picking who teaches a course.',
      action: 'Delete',
      cancel: 'Keep',
      danger: true,
    );
    if (!ok || !mounted) return;
    try {
      await _store.remove(x);
      if (mounted) setState(() => _loads++);
    } catch (e) {
      if (mounted) _say(context, problem(e));
    }
  }

  Future<void> _rename(Professor x) async {
    final name = await _nameDialog(context, title: 'Rename', initial: x.name);
    if (name == null || name == x.name) return;
    try {
      await _store.rename(x, name);
      if (mounted) setState(() => _loads++);
    } catch (e) {
      if (mounted) _say(context, problem(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final caption = TypeScale.caption.copyWith(
      height: 1.45,
      color: p.textMuted,
    );
    return Loaded<_Data>(
      cacheKey: DeptProfessors.cacheKey(widget.campus, widget.dept),
      key: ValueKey(_loads),
      load: () => _loadDept(widget.campus, widget.dept),
      peek: () => _peekDept(widget.campus, widget.dept),
      gated: (context, data, _, saved) {
        final q = _search.text.trim();
        final live = data.profs.where((x) => !x.removed);
        final shown = live.where((x) => x.matches(q)).toList();
        final gone = [
          for (final x in data.profs)
            if (x.removed && x.matches(q)) x,
        ];
        return PageFrame(
          header: PageHeader(
            eyebrow:
                '${campusName(widget.campus).toUpperCase()} · ${widget.dept} · '
                '${termLabel(maintainedTerm).toUpperCase()}',
            title: 'Professors',
          ),
          bottom: BottomAction(
            caption:
                q.length < 3
                    ? 'Search first: the name may already be here.'
                    : null,
            child: PrimaryButton(
              label: 'Add a professor',
              icon: Icons.add_rounded,
              onPressed: _add,
            ),
          ),
          children: [
            Text(
              'One entry per person, reused every term. Reviews are filed '
              'against the professor who taught that semester, so this list '
              'is what makes filtering work.',
              style: caption,
            ),
            const SizedBox(height: Space.md),
            SearchBox(
              controller: _search,
              hint: 'Search ${live.length} professors',
              onChanged:
                  (_) => _typed(() {
                    if (mounted) setState(() {});
                  }),
            ),
            const SizedBox(height: Space.sm),
            if (shown.isNotEmpty)
              SliverRowGroup(
                count: shown.length,
                inset: 13,
                row: (context, i) {
                  final x = shown[i];
                  return CardRow(
                    leading: const IconTile(Icons.school_outlined),
                    title: x.name,
                    titleLines: 2,
                    subtitle: switch ((data.teaching[x.id], data.last[x.id])) {
                      (final c?, _) => '${c.join(', ')} · teaching now',
                      (null, final t?) => 'Last taught ${termLabel(t)}',
                      _ => 'Not taught here yet',
                    },
                    minHeight: 58,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleIconButton(
                          icon: Icons.merge_type_rounded,
                          tooltip: 'Merge ${x.name}',
                          size: Sizes.minTouch,
                          onPressed:
                              saved
                                  ? null
                                  : () async {
                                    await _openMerge(
                                      context,
                                      widget.campus,
                                      widget.dept,
                                    );
                                    if (mounted) setState(() => _loads++);
                                  },
                        ),
                        CircleIconButton(
                          icon: Icons.delete_outline_rounded,
                          tooltip: 'Delete ${x.name}',
                          size: Sizes.minTouch,
                          onPressed: saved ? null : () => _delete(x),
                        ),
                        Icon(Icons.chevron_right_rounded, color: p.textMuted),
                      ],
                    ),
                    onTap: saved ? null : () => _rename(x),
                  );
                },
              ),
            if (shown.isEmpty && gone.isEmpty)
              Note(
                q.isEmpty
                    ? 'Nobody listed yet.'
                    : 'Nobody matches “$q”. Check other spellings before '
                        'adding.',
              ),
            if (gone.isNotEmpty) ...[
              const SectionLabel('Removed'),
              SliverRowGroup(
                count: gone.length,
                inset: 13,
                row:
                    (context, i) => CardRow(
                      leading: const IconTile(Icons.school_outlined),
                      title: gone[i].name,
                      titleLines: 2,
                      subtitle: 'Removed · reviews stay under the name',
                      minHeight: 58,
                    ),
              ),
            ],
            const SizedBox(height: Space.sm),
            const Notice(
              icon: Icons.warning_amber_rounded,
              text: TextSpan(
                text:
                    'Never type a name twice. “Dr. R. Menon” and “Ramesh '
                    'Menon” become two people and the review filter silently '
                    'splits in half. Search before adding: it matches partial '
                    'names for exactly this reason.',
              ),
            ),
            const SizedBox(height: Space.sm),
            AppCard(
              color: p.hero,
              onTap: () async {
                await _openMerge(context, widget.campus, widget.dept);
                if (mounted) setState(() => _loads++);
              },
              child: Row(
                children: [
                  Icon(Icons.merge_type_rounded, color: p.onHero),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Merge two entries',
                          style: TypeScale.body.copyWith(
                            fontWeight: FontWeight.w700,
                            color: p.onHero,
                          ),
                        ),
                        Text(
                          'Already added twice? Join them into one',
                          style: TypeScale.caption.copyWith(color: p.onHero),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: p.onHero),
                ],
              ),
            ),
            const SizedBox(height: Space.sm),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WHO CAN CHANGE THIS',
                    style: TypeScale.label.copyWith(
                      color: p.textMuted,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'You add, rename and merge professors for this '
                    'department, as can owners and admins. CRs pick from '
                    'this list for their own course each term, but cannot '
                    'create or rename one. Students only read it.',
                    style: caption,
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

/// Board `ProfessorAdd`: a name, the professor it may duplicate, Add. Pops
/// with that professor's name when it is tapped (the list then shows it).
class ProfessorAdd extends StatefulWidget {
  const ProfessorAdd({
    super.key,
    required this.campus,
    required this.dept,
    this.initial = '',
  });
  final String campus, dept, initial;

  @override
  State<ProfessorAdd> createState() => _ProfessorAddState();
}

class _ProfessorAddState extends State<ProfessorAdd> {
  late final _name = TextEditingController(text: widget.initial);
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    setState(() => _busy = true);
    try {
      await _store.add(_name.text.trim(), widget.campus, widget.dept);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _say(context, problem(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Loaded<List<Professor>>(
      cacheKey: 'professors-add|${widget.campus}|${widget.dept}',
      load: () => _store.department(widget.campus, widget.dept),
      peek: () => _store.peekDepartment(widget.campus, widget.dept),
      gated: (context, profs, _, saved) {
        final name = _name.text.trim();
        final same =
            [
              for (final x in profs)
                if (!x.removed && sameName(x.name, name)) x,
            ].firstOrNull;
        // duplicateOf needs two name words each; likelySame also catches
        // "Dr. R. Menon" vs "Ramesh Menon".
        final dup =
            same ??
            (name.isEmpty
                ? null
                : duplicateOf(name, profs) ??
                    [
                      for (final x in livePicks(profs))
                        if (likelySame(x.name, name)) x,
                    ].firstOrNull);
        return PageFrame(
          header: PageHeader(
            eyebrow:
                '${campusName(widget.campus).toUpperCase()} · ${widget.dept}',
            title: 'Add a professor',
          ),
          bottom: BottomAction(
            child: PrimaryButton(
              label: dup == null ? 'Add' : 'Add anyway',
              onPressed:
                  saved || _busy || name.length < 2 || same != null
                      ? null
                      : _add,
            ),
          ),
          children: [
            AppTextField(
              controller: _name,
              label: 'Name',
              hint: 'Dr. R. Menon',
              labelAbove: true,
              onChanged: (_) => setState(() {}),
            ),
            if (same != null)
              Note(
                '${same.name} is already listed. Use that entry instead of '
                'adding it again.',
              ),
            if (dup != null) ...[
              const SectionLabel('Possible duplicates'),
              AppCard(
                padding: EdgeInsets.zero,
                child: CardRow(
                  leading: const IconTile(Icons.school_outlined),
                  title: dup.name,
                  titleLines: 2,
                  subtitle:
                      dup.removed
                          ? 'Removed · tap to open instead'
                          : 'Tap to open instead',
                  minHeight: 58,
                  onTap: () => Navigator.of(context).pop(dup.name),
                ),
              ),
              Note(
                'If this is the same person, open that entry. Two entries '
                'split their reviews in half.',
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Board `ProfessorMerge`: pick the one to keep; the other becomes an alias
/// pointing at it (§16.3 fix 7). No unmerge.
class ProfessorMerge extends StatefulWidget {
  const ProfessorMerge({super.key, this.campus, this.dept});

  /// Null opens with a campus and department to choose (owners, admins).
  final String? campus, dept;

  @override
  State<ProfessorMerge> createState() => _ProfessorMergeState();
}

class _ProfessorMergeState extends State<ProfessorMerge> {
  late String _campus =
      widget.campus ??
      myRoles.value.presidencies.firstOrNull?.campus ??
      campusOfAddress(roleStore!.me) ??
      'goa';
  late String? _dept =
      widget.dept ?? myRoles.value.presidencies.firstOrNull?.scope;

  /// The row picked from the shared department list; its label.
  Branch? _branch;
  String? _keep, _gone;
  bool _busy = false;
  int _loads = 0;

  Future<void> _pickDept() async {
    final v = await showModalBottomSheet<Branch>(
      context: context,
      isScrollControlled: true,
      builder:
          (_) => DeptSheet(
            campus: _campus,
            selected: _branch,
            gen: myRoles.value.owner || myRoles.value.admin,
          ),
    );
    if (v == null || !mounted) return;
    setState(() {
      // Professors are listed per department: every ELEC branch shares one.
      _branch = v;
      _dept = v.dept;
      _keep = _gone = null;
    });
  }

  Future<void> _merge(Professor keep, Professor gone) async {
    setState(() => _busy = true);
    try {
      await _store.merge(keep, gone);
      setState(() {
        _keep = _gone = null;
        _loads++;
      });
      if (mounted) _say(context, 'Merged into ${keep.name}.');
    } catch (e) {
      if (mounted) _say(context, problem(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  PageFrame _frame(List<Widget> children, {Widget? bottom}) {
    final r = myRoles.value;
    final free = (r.owner || r.admin) && widget.campus == null;
    final dept = _dept;
    return PageFrame(
      header: const PageHeader(
        eyebrow: 'OWNERS, ADMINS, PRESIDENTS',
        title: 'Merge duplicates',
      ),
      bottom: bottom,
      children: [
        if (free) ...[
          ChoicePills<String>(
            values: const ['goa', 'hyderabad', 'pilani', 'dubai'],
            selected: _campus,
            label: campusName,
            onSelected:
                (c) => setState(() {
                  _campus = c;
                  _keep = _gone = null;
                }),
          ),
          const SizedBox(height: Space.sm),
          SelectRow(
            text:
                dept == null
                    ? 'Department'
                    : '${branchName(_branch ?? (dept: dept, programme: null))} · '
                        '${branchCodes(_branch ?? (dept: dept, programme: null))}',
            placeholder: dept == null,
            onTap: _pickDept,
          ),
          const SizedBox(height: Space.md),
        ] else if (dept != null) ...[
          ScopePills(campus: _campus, scope: dept),
          const SizedBox(height: Space.sm),
        ],
        ...children,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final caption = TypeScale.caption.copyWith(
      height: 1.45,
      color: p.textMuted,
    );
    final dept = _dept;
    if (dept == null) return _frame(const [Note('Pick a department.')]);
    return Loaded<
      (List<Professor>, Map<String, (int, int)>, List<DuplicatePair>)
    >(
      key: ValueKey('$_campus|$dept|$_loads'),
      load: () async {
        final profs = [
          for (final x in await _store.department(_campus, dept))
            if (!x.removed) x,
        ];
        final counts = <String, (int, int)>{};
        for (final x in profs) {
          final t = await _store.taught(x, _campus);
          counts[x.id] = (t.length, t.values.fold(0, (a, l) => a + l.length));
        }
        final dups = await duplicateSource.possible(_campus, dept, profs);
        return (profs, counts, dups);
      },
      peek: () {
        final saved = _store.peekDepartment(_campus, dept);
        if (saved == null || duplicateSource is! NameDuplicates) return null;
        final profs = [
          for (final x in saved)
            if (!x.removed) x,
        ];
        final counts = <String, (int, int)>{};
        for (final x in profs) {
          final t = _store.peekTaught(x, _campus);
          if (t == null) return null;
          counts[x.id] = (t.length, t.values.fold(0, (a, l) => a + l.length));
        }
        return (profs, counts, likelyPairs(profs));
      },
      builder: (context, data, _) {
        final (profs, counts, dups) = data;
        final keep = profs.where((x) => x.id == _keep).firstOrNull;
        final gone = profs.where((x) => x.id == _gone).firstOrNull;
        String offerings(int n) => '$n offering${n == 1 ? '' : 's'}';
        Widget pick(Professor x) {
          final isKeep = x.id == _keep, isGone = x.id == _gone;
          final (courses, runs) = counts[x.id] ?? (0, 0);
          return CardRow(
            leading: Icon(
              isKeep || isGone
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isKeep || isGone ? p.text : p.textMuted,
            ),
            title: x.name,
            titleLines: 2,
            subtitle:
                '$courses course${courses == 1 ? '' : 's'} · '
                '${offerings(runs)}',
            trailing:
                isKeep
                    ? const TierTag('KEEP', strong: true)
                    : isGone
                    ? const TierTag('MERGE')
                    : const SizedBox.shrink(),
            onTap:
                () => setState(() {
                  if (_keep == null || isKeep) {
                    _keep = isKeep ? null : x.id;
                    if (isKeep) _gone = null;
                  } else {
                    _gone = isGone ? null : x.id;
                  }
                }),
          );
        }

        final runs =
            keep == null || gone == null
                ? 0
                : counts[keep.id]!.$2 + counts[gone.id]!.$2;
        return _frame(
          [
            Text(
              'Two entries for one person split their reviews. Tap the one '
              'to keep, then the one to merge into it.',
              style: caption,
            ),
            const SizedBox(height: Space.sm),
            if (dups.isNotEmpty) ...[
              const SectionLabel('Possible duplicates'),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final (i, d) in dups.indexed) ...[
                      if (i > 0) const CardDivider(),
                      CardRow(
                        title: '${d.a.name} · ${d.b.name}',
                        titleLines: 2,
                        subtitle: 'Tap to pick both',
                        onTap:
                            () => setState(() {
                              // Keep the one with more offerings.
                              final aRuns = counts[d.a.id]?.$2 ?? 0;
                              final bRuns = counts[d.b.id]?.$2 ?? 0;
                              final (k, g) =
                                  aRuns >= bRuns ? (d.a, d.b) : (d.b, d.a);
                              _keep = k.id;
                              _gone = g.id;
                            }),
                      ),
                    ],
                  ],
                ),
              ),
              const SectionLabel('Everyone listed'),
            ],
            if (profs.isEmpty)
              const Note('No professors listed here yet.')
            else
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final (i, x) in profs.indexed) ...[
                      if (i > 0) const CardDivider(),
                      pick(x),
                    ],
                  ],
                ),
              ),
            if (keep != null && gone != null) ...[
              const SizedBox(height: Space.md),
              AppCard(
                color: p.hero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AFTER',
                      style: TypeScale.label.copyWith(
                        color: p.onHero,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${keep.name} · ${offerings(runs)}',
                      style: TypeScale.body.copyWith(
                        fontWeight: FontWeight.w800,
                        color: p.onHero,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Also known as ${[...keep.aliases, gone.name, ...gone.aliases].join(', ')}.',
                      style: TypeScale.caption.copyWith(
                        height: 1.45,
                        color: p.onHero,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.sm),
              Text(
                'It rewrites every review and the '
                '${offerings(counts[gone.id]!.$2)} that name ${gone.name}, '
                'and cannot be undone.',
                style: TypeScale.caption.copyWith(
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                  color: p.text,
                ),
              ),
            ],
            const SizedBox(height: Space.sm),
            Note(
              'It is logged with your name. A president merges only within '
              'their own department on their own campus.',
            ),
          ],
          bottom: BottomAction(
            child: PrimaryButton(
              label:
                  keep == null
                      ? 'Pick the one to keep'
                      : gone == null
                      ? 'Pick the duplicate'
                      : _busy
                      ? 'Merging…'
                      : 'Merge into ${keep.name}',
              onPressed:
                  keep == null || gone == null || _busy
                      ? null
                      : () => _merge(keep, gone),
            ),
          ),
        );
      },
    );
  }
}

/// `CrHome`'s "Taken by, this term": picked from the department's list,
/// never typed (§13.3). Up to two professors.
class TakenBy extends StatefulWidget {
  const TakenBy({
    super.key,
    required this.campus,
    required this.courseId,
    required this.offering,
    required this.onSaved,
  });

  final String campus, courseId;
  final Offering? offering;
  final VoidCallback onSaved;

  @override
  State<TakenBy> createState() => _TakenByState();
}

class _TakenByState extends State<TakenBy> {
  Future<void> _change(List<Professor> profs) async {
    final chosen = {...?widget.offering?.professors};
    final pal = AppPalette.of(context);
    final picked = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => SafeArea(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(
                      Space.lg,
                      0,
                      Space.lg,
                      Space.lg,
                    ),
                    children: [
                      Text(
                        'Who teaches ${widget.courseId}?',
                        style: TypeScale.title.copyWith(color: pal.text),
                      ),
                      Text(
                        'From the department list. Only a president can add a name.',
                        style: TypeScale.caption.copyWith(color: pal.textMuted),
                      ),
                      for (final x in profs)
                        if (!x.removed || chosen.contains(x.id))
                          CheckboxListTile(
                            value: chosen.contains(x.id),
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              x.name,
                              style: TypeScale.body.copyWith(color: pal.text),
                            ),
                            onChanged:
                                (v) => setState(() {
                                  if (v == true && chosen.length < 2) {
                                    chosen.add(x.id);
                                  } else {
                                    chosen.remove(x.id);
                                  }
                                }),
                          ),
                      if (profs.isEmpty)
                        const Note(
                          'Nobody is listed for this department yet. Ask your '
                          'department president to add the professor.',
                        ),
                      const SizedBox(height: Space.sm),
                      PrimaryButton(
                        label: 'Save',
                        onPressed: () => Navigator.pop(context, chosen),
                      ),
                    ],
                  ),
                ),
          ),
    );
    if (picked == null) return;
    final o = widget.offering;
    try {
      await MaintainStore(roleStore!).save(
        Offering(
          courseId: widget.courseId,
          campus: widget.campus,
          term: maintainedTerm,
          weighted: o?.weighted ?? true,
          totalMarks: o?.totalMarks ?? 100,
          components: o?.components ?? const [],
          courseAverage: o?.courseAverage,
          professors: picked.toList(),
          updatedAt: o?.updatedAt ?? 0,
          outOf: o?.outOf,
        ),
        'Set who teaches ${widget.courseId} in ${termLabel(maintainedTerm)}',
      );
      widget.onSaved();
    } catch (e) {
      if (mounted) _say(context, problem(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Loaded<List<Professor>>(
      cacheKey: 'professors-taken|${widget.campus}|${deptOf(widget.courseId)}',
      load: () => _store.department(widget.campus, deptOf(widget.courseId)),
      peek: () => _store.peekDepartment(widget.campus, deptOf(widget.courseId)),
      builder: (context, profs, _) {
        final byId = {for (final x in profs) x.id: x};
        final ids = widget.offering?.professors ?? const <String>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: SectionLabel('Taken by, this term')),
                TextLink('Change', onTap: () => _change(profs)),
              ],
            ),
            AppCard(
              padding: EdgeInsets.zero,
              child: CardRow(
                leading: const IconTile(Icons.school_outlined, mint: true),
                title:
                    ids.isEmpty
                        ? 'Not set yet'
                        : ids
                            .map((id) => byId[id]?.name ?? 'Unknown')
                            .join(', '),
                titleLines: 2,
                subtitle: 'Picked from the department list',
                onTap: () => _change(profs),
              ),
            ),
          ],
        );
      },
    );
  }
}
