import 'package:cgpa_calculator/admin/people.dart';
import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/routes.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/roles/contacts.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Board `Roster`: every grant on the campus with name and email, for
/// owners, admins and presidents (§4). Presidents see their own campus plus
/// who appoints on every campus.
class RosterPage extends StatefulWidget {
  const RosterPage({
    super.key,
    this.volunteersTab,
    this.initialVolunteers = false,
  });

  /// Roster's second tab (§16.3 fix 16); null until volunteers exist.
  final Widget Function(String campus)? volunteersTab;

  /// Opens straight to the volunteers tab (`roster/volunteers`, T3.4).
  final bool initialVolunteers;

  @override
  State<RosterPage> createState() => _RosterPageState();
}

class _RosterPageState extends State<RosterPage> {
  String _filter = 'All';
  late bool _volunteers = widget.initialVolunteers;

  bool _shows(Grant g) => switch (_filter) {
    'Presidents' => g.role == GrantRole.dept,
    'CRs' => g.role == GrantRole.course,
    'Expiring' =>
      g.active && g.expiresAt.difference(DateTime.now()).inDays <= 14,
    _ => true,
  };

  @override
  Widget build(BuildContext context) {
    final r = myRoles.value;
    final pres = r.presidencies.firstOrNull;
    final campus = r.owner || r.admin ? null : pres?.campus;
    return Loaded<(List<Grant>, Map<String, String>)>(
      load:
          () async => (
            await roleStore!.roster(campus: campus),
            await ContactStore(roleStore!).staffPhones(),
          ),
      builder: (context, data, reload) {
        final (all, phones) = data;
        final live =
            all.where((g) => g.active).where(_shows).toList()..sort((a, b) {
              final c = a.campus.compareTo(b.campus);
              if (c != 0) return c;
              final t = a.role.index.compareTo(b.role.index);
              return t != 0 ? t : a.name.compareTo(b.name);
            });
        final everyCampus = live.where((g) => g.campus == 'all').toList();
        final campuses = {
          for (final g in live)
            if (g.campus != 'all') g.campus,
        };
        final people = {for (final g in all.where((g) => g.active)) g.email};
        return PageFrame(
          header: PageHeader(
            eyebrow: '${people.length} PEOPLE',
            title: 'Roster',
          ),
          children: [
            if (pres != null) ...[
              ScopePills(campus: pres.campus, scope: pres.scopeLabel),
              const SizedBox(height: Space.sm),
            ],
            if (widget.volunteersTab != null) ...[
              ChoicePills<bool>(
                values: const [false, true],
                selected: _volunteers,
                label: (v) => v ? 'Volunteers' : 'Maintainers',
                onSelected: (v) => setState(() => _volunteers = v),
              ),
              const SizedBox(height: Space.sm),
            ],
            if (_volunteers)
              widget.volunteersTab!(campus ?? pres?.campus ?? 'goa')
            else ...[
              ChoicePills<String>(
                values: const ['All', 'Presidents', 'CRs', 'Expiring'],
                selected: _filter,
                label: (v) => v,
                onSelected: (v) => setState(() => _filter = v),
              ),
              if (everyCampus.isNotEmpty) ...[
                const SectionLabel('Who appoints · every campus'),
                RowGroup(
                  children: [
                    for (final g in everyCampus)
                      GrantTile(
                        g: g,
                        line:
                            'Appoints presidents · until '
                            '${shortDay(g.expiresAt)}',
                        phone: phones[g.email],
                        showPhone: true,
                      ),
                  ],
                ),
              ],
              for (final c in campuses.toList()..sort()) ...[
                SectionLabel(campusName(c)),
                RowGroup(
                  children: [
                    for (final g in live.where((g) => g.campus == c))
                      GrantTile(
                        g: g,
                        phone: phones[g.email],
                        showPhone: true,
                        onTap:
                            r.owner || r.admin
                                ? () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => PersonPage(grant: g),
                                    ),
                                  );
                                  reload();
                                }
                                : null,
                      ),
                  ],
                ),
              ],
              if (live.isEmpty) const Note('Nobody here yet.'),
              const Note(
                'Names, emails and staff phone numbers are never hidden here. '
                'Only owners, admins and presidents can open this page; '
                'presidents see their own campus.',
              ),
            ],
            const SizedBox(height: Space.lg),
            PrimaryButton(
              label: r.owner || r.admin ? 'Appoint someone' : 'Appoint a CR',
              icon: Icons.add_rounded,
              onPressed: () async {
                await context.push(Routes.adminGrant);
                reload();
              },
            ),
          ],
        );
      },
    );
  }
}
