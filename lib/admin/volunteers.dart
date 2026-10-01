import 'package:cgpa_calculator/admin/dept_list.dart';
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
import 'package:cgpa_calculator/shared/widgets/card_row.dart';
import 'package:cgpa_calculator/shared/widgets/pill_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The department whose offers the tab opens on: the president's own, or
/// for owners and admins the first.
String? defaultDept(String campus) =>
    myRoles.value.presidencies
        .where((g) => g.campus == campus)
        .firstOrNull
        ?.scope ??
    (myRoles.value.reachesAdmin ? departments.keys.first : null);

/// Open offers the Volunteers tab starts on, for its label.
Future<int> openOffers(String campus) async {
  final dept = defaultDept(campus);
  final store = roleStore;
  if (dept == null || store == null) return 0;
  final byCourse = await ContactStore(
    store,
  ).offers(campus, dept, term: currentTerm(DateTime.now()));
  return byCourse.values.fold<int>(0, (n, l) => n + l.length);
}

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
  late String? _dept = defaultDept(widget.campus);

  /// The row picked from the shared department list; its label.
  Branch? _branch;
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
    final dept = _dept;
    if (dept == null) {
      return const Note('Volunteers reach department presidents.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_depts.length > 1) ...[
          // The shared department list, as Open as and Merge show it.
          SelectRow(
            text:
                '${branchName(_branch ?? (dept: dept, programme: null))} · '
                '${branchCodes(_branch ?? (dept: dept, programme: null))}',
            onTap: () async {
              final v = await showModalBottomSheet<Branch>(
                context: context,
                isScrollControlled: true,
                builder:
                    (_) => DeptSheet(
                      campus: widget.campus,
                      selected: _branch,
                      only: _depts,
                    ),
              );
              if (v == null || !mounted) return;
              setState(() {
                _branch = v;
                _dept = v.dept;
              });
            },
          ),
          const SizedBox(height: Space.sm),
        ],
        Loaded<Map<String, List<Volunteer>>>(
          cacheKey: 'volunteers|${widget.campus}|$dept|${currentTerm(DateTime.now())}',
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
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(15, 6, 6, 0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '$c · ${byCourse[c]!.length} '
                                  'offer${byCourse[c]!.length == 1 ? '' : 's'}',
                                  style: TypeScale.body.copyWith(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: p.text,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip:
                                    byCourse[c]!.length == 1
                                        ? 'Copy the objection notice'
                                        : 'Copy the election notice',
                                icon: Icon(
                                  Icons.content_paste_rounded,
                                  size: 19,
                                  color: p.icon,
                                ),
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
                        ),
                        for (final (i, v) in byCourse[c]!.indexed) ...[
                          if (i > 0) const CardDivider(),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(15, 8, 15, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                NameEmail(v.name, shortEmail(v.email)),
                                if (v.createdAt != null)
                                  Text(
                                    'Offered ${ago(v.createdAt)}',
                                    style: TypeScale.caption.copyWith(
                                      color: p.textMuted,
                                    ),
                                  ),
                                const SizedBox(height: Space.sm),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    PillButton(
                                      label: 'Appoint as CR',
                                      selected: true,
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
                                                    for (final o
                                                        in byCourse[c]!)
                                                      o.id,
                                                  ],
                                                ),
                                          ),
                                        );
                                        if (mounted) setState(() => _loads++);
                                      },
                                    ),
                                    PillButton(
                                      label: 'Dismiss',
                                      onPressed:
                                          () => _act(
                                            () => _store.dismiss(v),
                                            'Dismissed.',
                                          ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.sm),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: Space.sm),
        Note(
          'The message proposes an election for several offers and an '
          'objection notice for one. Pointer sends nothing and records '
          'nothing; appoint here once the group has decided. Offers close '
          'when the term ends.',
        ),
      ],
    );
  }
}
