import 'package:cgpa_calculator/admin/grant_form.dart';
import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/catalog/catalog.dart';
import 'package:cgpa_calculator/core/roles/contacts.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/core/roles/volunteer_message.dart';
import 'package:cgpa_calculator/features/marks/official.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Roster › Volunteers (§16.3 fix 16): open CR offers in a department, by
/// course. Copy a message for the course's WhatsApp group, appoint, or
/// dismiss.
class VolunteersTab extends StatefulWidget {
  const VolunteersTab({super.key, required this.campus});
  final String campus;

  @override
  State<VolunteersTab> createState() => _VolunteersTabState();
}

class _VolunteersTabState extends State<VolunteersTab> {
  late String? _dept =
      myRoles.value.presidencies
          .where((g) => g.campus == widget.campus)
          .firstOrNull
          ?.scope ??
      (myRoles.value.reachesAdmin ? departments.keys.first : null);
  int _loads = 0;

  ContactStore get _store => ContactStore(roleStore!);

  List<String> get _depts {
    final r = myRoles.value;
    if (r.reachesAdmin) return departments.keys.toList();
    return [
      for (final g in r.presidencies)
        if (g.campus == widget.campus) g.scope,
    ];
  }

  String _message(String courseId, List<Volunteer> offers) {
    final pres =
        myRoles.value.presidencies
            .where((g) => g.campus == widget.campus && g.scope == _dept)
            .firstOrNull;
    return volunteerMessage(
      courseCode: courseId,
      courseTitle:
          catalog.master.where((m) => m.id == courseId).firstOrNull?.title ??
          '',
      volunteers: [for (final v in offers) v.name],
      deadline: deadlineText(defaultDeadline(DateTime.now())),
      presidentName: pres?.name ?? roleStore!.myName,
      departmentName: departments[_dept]?.name ?? _dept!,
      deptKey: _dept!,
      campusName: campusName(widget.campus),
    );
  }

  Future<void> _act(Future<void> Function() f, String done) async {
    try {
      await f();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(done)));
      setState(() => _loads++);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(problem(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final caption = TypeScale.caption.copyWith(
      height: 1.45,
      color: p.textMuted,
    );
    final dept = _dept;
    if (dept == null) {
      return const Note('Volunteers reach department presidents.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_depts.length > 1) ...[
          ChoicePills<String>(
            values: _depts,
            selected: dept,
            label: (d) => d,
            onSelected: (d) => setState(() => _dept = d),
          ),
          const SizedBox(height: Space.sm),
        ],
        Loaded<Map<String, List<Volunteer>>>(
          key: ValueKey('$dept|$_loads'),
          load:
              () => _store.offers(
                widget.campus,
                dept,
                term: currentTerm(DateTime.now()),
              ),
          builder: (context, byCourse, _) {
            if (byCourse.isEmpty) {
              return Note(
                'No open offers in $dept. Students volunteer from '
                'Representatives when a course has no CR.',
              );
            }
            final courses = byCourse.keys.toList()..sort();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final c in courses) ...[
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '$c · ${byCourse[c]!.length} '
                                'offer${byCourse[c]!.length == 1 ? '' : 's'}',
                                style: TypeScale.body.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Copy the message for WhatsApp',
                              icon: const Icon(Icons.copy_rounded, size: 18),
                              onPressed: () async {
                                await Clipboard.setData(
                                  ClipboardData(
                                    text: _message(c, byCourse[c]!),
                                  ),
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Copied. Edit it in WhatsApp before '
                                      'sending.',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        for (final v in byCourse[c]!)
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${v.name} · ${v.email}',
                                  style: TypeScale.caption,
                                ),
                              ),
                              TextButton(
                                onPressed: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder:
                                          (_) => AdminGrant(
                                            prefill: (
                                              role: GrantRole.course,
                                              email: v.email,
                                              scope: c,
                                            ),
                                            closeOffers: [
                                              for (final o in byCourse[c]!)
                                                o.id,
                                            ],
                                          ),
                                    ),
                                  );
                                  if (mounted) setState(() => _loads++);
                                },
                                child: const Text('Appoint as CR'),
                              ),
                              TextButton(
                                onPressed:
                                    () => _act(
                                      () => _store.dismiss(v),
                                      'Dismissed.',
                                    ),
                                child: const Text('Dismiss'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.xs),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: Space.sm),
        Text(
          'The message proposes an election for several offers and an '
          'objection notice for one. Pointer sends nothing and records '
          'nothing; appoint here once the group has decided. Offers close '
          'when the term ends.',
          style: caption,
        ),
      ],
    );
  }
}
