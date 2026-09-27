import 'package:cgpa_calculator/admin/maintain.dart';
import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/models/offering.dart';
import 'package:cgpa_calculator/core/professors/professor.dart';
import 'package:cgpa_calculator/core/professors/professor_store.dart';
import 'package:cgpa_calculator/core/roles/maintain_store.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:flutter/material.dart';

ProfessorStore get _store => ProfessorStore(roleStore!.db, roles: roleStore);

void _say(BuildContext context, String text) =>
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(text)));

Future<String?> _nameDialog(
  BuildContext context, {
  required String title,
  String initial = '',
  List<Professor> others = const [],
}) async {
  final c = TextEditingController(text: initial);
  final name = await showDialog<String>(
    context: context,
    builder:
        (context) => StatefulBuilder(
          builder: (context, setState) {
            final similar = [
              for (final p in others)
                if (c.text.trim().length > 2 && likelySame(p.name, c.text)) p,
            ];
            return AlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: c,
                    autofocus: true,
                    decoration: const InputDecoration(hintText: 'Dr. R. Menon'),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (similar.isNotEmpty) ...[
                    const SizedBox(height: Space.sm),
                    Text(
                      'Already listed: ${similar.map((p) => p.name).join(', ')}. '
                      'If that is the same person, use it instead.',
                      style: TypeScale.caption.copyWith(
                        color: AppPalette.of(context).noticeTone.text,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed:
                      c.text.trim().length < 2
                          ? null
                          : () => Navigator.pop(context, c.text.trim()),
                  child: Text(similar.isEmpty ? 'Save' : 'Add anyway'),
                ),
              ],
            );
          },
        ),
  );
  c.dispose();
  return name;
}

typedef _Data = ({List<Professor> profs, Map<String, List<String>> teaching});

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
  return (profs: profs, teaching: teaching);
}

/// Board `DeptProfessors`: one entry per person, reused every term. Search
/// comes before Add (§10.1).
class DeptProfessors extends StatefulWidget {
  const DeptProfessors({super.key, required this.campus, required this.dept});
  final String campus, dept;

  @override
  State<DeptProfessors> createState() => _DeptProfessorsState();
}

class _DeptProfessorsState extends State<DeptProfessors> {
  final _search = TextEditingController();
  int _loads = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final caption = TypeScale.caption.copyWith(
      height: 1.45,
      color: p.textMuted,
    );
    return Loaded<_Data>(
      key: ValueKey(_loads),
      load: () => _loadDept(widget.campus, widget.dept),
      builder: (context, data, _) {
        final q = _search.text.trim();
        final shown = data.profs.where((x) => x.matches(q)).toList();
        return PageFrame(
          header: PageHeader(
            eyebrow:
                '${campusName(widget.campus).toUpperCase()} · ${widget.dept} · '
                '${termLabel(maintainedTerm).toUpperCase()}',
            title: 'Professors',
          ),
          children: [
            Text(
              'One entry per person, reused every term. Reviews are filed '
              'against the professor who taught that semester, so this list '
              'is what makes filtering work.',
              style: caption,
            ),
            const SizedBox(height: Space.md),
            AppTextField(
              controller: _search,
              label: 'Search ${data.profs.length} professors',
              dense: true,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: Space.sm),
            RowGroup(
              children: [
                for (final x in shown)
                  NavRow(
                    icon: Icons.person_outline_rounded,
                    title: x.name,
                    subtitle: switch (data.teaching[x.id]) {
                      final c? => '${c.join(', ')} · teaching now',
                      null => 'Not teaching this term',
                    },
                    onTap: () async {
                      final name = await _nameDialog(
                        context,
                        title: 'Rename',
                        initial: x.name,
                      );
                      if (name == null || name == x.name) return;
                      try {
                        await _store.rename(x, name);
                        setState(() => _loads++);
                      } catch (e) {
                        if (context.mounted) _say(context, problem(e));
                      }
                    },
                  ),
              ],
            ),
            if (shown.isEmpty)
              Note(
                q.isEmpty
                    ? 'Nobody listed yet.'
                    : 'Nobody matches “$q”. Check other spellings before '
                        'adding.',
              ),
            Text(
              'Never type a name twice. “Dr. R. Menon” and “Ramesh Menon” '
              'become two people and the review filter silently splits in '
              'half. Search before adding — the search matches partial names '
              'for exactly this reason.',
              style: caption,
            ),
            const SizedBox(height: Space.sm),
            RowGroup(
              children: [
                NavRow(
                  icon: Icons.merge_type_rounded,
                  title: 'Merge two entries',
                  subtitle: 'Already added twice? Join them into one',
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder:
                            (_) => ProfessorMerge(
                              campus: widget.campus,
                              dept: widget.dept,
                            ),
                      ),
                    );
                    setState(() => _loads++);
                  },
                ),
              ],
            ),
            const SectionLabel('Who can change this'),
            Text(
              'You add, rename and merge professors for this department, as '
              'can owners and admins. CRs pick from this list for their own '
              'course each term, but cannot create or rename one. Students '
              'only read it.',
              style: caption,
            ),
            const SizedBox(height: Space.lg),
            PrimaryButton(
              label:
                  q.length < 3 ? 'Search first, then add' : 'Add a professor',
              icon: Icons.add_rounded,
              onPressed:
                  q.length < 3
                      ? null
                      : () async {
                        final name = await _nameDialog(
                          context,
                          title: 'Add a professor',
                          initial: q,
                          others: data.profs,
                        );
                        if (name == null) return;
                        try {
                          await _store.add(name, widget.campus, widget.dept);
                          _search.clear();
                          setState(() => _loads++);
                        } catch (e) {
                          if (context.mounted) _say(context, problem(e));
                        }
                      },
            ),
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
  String? _keep, _gone;
  bool _busy = false;
  int _loads = 0;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final caption = TypeScale.caption.copyWith(
      height: 1.45,
      color: p.textMuted,
    );
    final r = myRoles.value;
    final free = r.owner || r.admin;
    final pickers = <Widget>[
      if (free && widget.campus == null) ...[
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
        DropdownButtonFormField<String>(
          initialValue: _dept,
          isExpanded: true,
          hint: const Text('Department'),
          items: [
            for (final e in departments.entries)
              DropdownMenuItem(
                value: e.key,
                child: Text('${e.key} · ${e.value.name}'),
              ),
          ],
          onChanged:
              (v) => setState(() {
                _dept = v;
                _keep = _gone = null;
              }),
        ),
        const SizedBox(height: Space.md),
      ],
    ];
    final dept = _dept;
    return PageFrame(
      header: PageHeader(
        eyebrow: 'OWNERS, ADMINS, PRESIDENTS',
        title: 'Merge duplicates',
      ),
      children: [
        ...pickers,
        if (dept == null)
          const Note('Pick a department.')
        else
          Loaded<List<Professor>>(
            key: ValueKey('$_campus|$dept|$_loads'),
            load: () => _store.department(_campus, dept),
            builder: (context, profs, _) {
              final keep = profs.where((x) => x.id == _keep).firstOrNull;
              final gone = profs.where((x) => x.id == _gone).firstOrNull;
              Widget pick(Professor x) {
                final isKeep = x.id == _keep, isGone = x.id == _gone;
                return AppCard(
                  color: isKeep ? p.inverse : null,
                  onTap:
                      () => setState(() {
                        if (_keep == null || isKeep) {
                          _keep = isKeep ? null : x.id;
                        } else {
                          _gone = isGone ? null : x.id;
                        }
                      }),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          x.name,
                          style: TypeScale.body.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isKeep ? p.onInverse : p.text,
                          ),
                        ),
                      ),
                      if (isKeep) const TierTag('KEEP', strong: true),
                      if (isGone) const TierTag('MERGE'),
                    ],
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ScopePills(campus: _campus, scope: dept),
                  const SizedBox(height: Space.sm),
                  Text(
                    'Two entries for one person split their reviews. Tap the '
                    'one to keep, then the one to merge into it.',
                    style: caption,
                  ),
                  const SizedBox(height: Space.sm),
                  for (final x in profs) ...[
                    pick(x),
                    const SizedBox(height: Space.xs),
                  ],
                  if (keep != null && gone != null) ...[
                    const SectionLabel('After'),
                    Text(
                      keep.name,
                      style: TypeScale.body.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Also known as ${gone.name}. Every review and offering '
                      'that named either now reads as one person.',
                      style: caption,
                    ),
                  ],
                  const SizedBox(height: Space.sm),
                  Text(
                    'It is logged with your name. There is no unmerge: check '
                    'the course list first. A president merges only within '
                    'their own department on their own campus.',
                    style: caption,
                  ),
                  const SizedBox(height: Space.md),
                  PrimaryButton(
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
                            : () async {
                              setState(() => _busy = true);
                              try {
                                await _store.merge(keep, gone);
                                setState(() {
                                  _keep = _gone = null;
                                  _loads++;
                                });
                                if (context.mounted) {
                                  _say(context, 'Merged into ${keep.name}.');
                                }
                              } catch (e) {
                                if (context.mounted) _say(context, problem(e));
                              } finally {
                                if (mounted) setState(() => _busy = false);
                              }
                            },
                  ),
                ],
              );
            },
          ),
      ],
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
    final picked = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => SafeArea(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(Space.lg),
                    children: [
                      Text(
                        'Who teaches ${widget.courseId}?',
                        style: TypeScale.title,
                      ),
                      Text(
                        'From the department list. Only a president can add a name.',
                        style: TypeScale.caption,
                      ),
                      for (final x in profs)
                        CheckboxListTile(
                          value: chosen.contains(x.id),
                          title: Text(x.name),
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
    final p = AppPalette.of(context);
    return Loaded<List<Professor>>(
      load: () => _store.department(widget.campus, deptOf(widget.courseId)),
      builder: (context, profs, _) {
        final byId = {for (final x in profs) x.id: x};
        final ids = widget.offering?.professors ?? const <String>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: SectionLabel('Taken by, this term')),
                TextButton(
                  onPressed: () => _change(profs),
                  child: const Text('Change'),
                ),
              ],
            ),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ids.isEmpty
                        ? 'Not set yet'
                        : ids
                            .map((id) => byId[id]?.name ?? 'Unknown')
                            .join(', '),
                    style: TypeScale.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'Picked from the department list — you cannot add a new '
                    'name',
                    style: TypeScale.caption.copyWith(color: p.textMuted),
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
