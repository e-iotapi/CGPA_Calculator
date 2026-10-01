import 'package:cgpa_calculator/admin/people.dart';
import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/admin/volunteers.dart';
import 'package:cgpa_calculator/app/routes.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/roles/contacts.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/bottom_action.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:cgpa_calculator/shared/widgets/segmented.dart';
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
    final tabCampus = campus ?? pres?.campus ?? 'goa';
    return Loaded<
      (List<Grant>, Map<String, String>, List<Map<String, dynamic>>, int)
    >(
      cacheKey: 'roster|$campus|$tabCampus|${widget.volunteersTab != null}',
      load: () async {
        final store = roleStore!;
        return (
          await store.roster(campus: campus),
          await ContactStore(store).staffPhones(),
          await store.owners(),
          widget.volunteersTab == null ? 0 : await openOffers(tabCampus),
        );
      },
      builder: (context, data, reload) {
        final (all, phones, owners, offers) = data;
        final live =
            all.where((g) => g.active).where(_shows).toList()..sort((a, b) {
              final c = a.campus.compareTo(b.campus);
              if (c != 0) return c;
              final t = a.role.index.compareTo(b.role.index);
              return t != 0 ? t : a.name.compareTo(b.name);
            });
        final admins = live.where((g) => g.campus == 'all').toList();
        final activeOwners = [
          for (final o in owners)
            if (o['active'] == true) o,
        ];
        final campuses = {
          for (final g in live)
            if (g.campus != 'all') g.campus,
        };
        final people = {
          for (final g in all.where((g) => g.active)) g.email,
          for (final o in activeOwners) o['email'] as String? ?? '',
        };
        return PageFrame(
          header: PageHeader(
            eyebrow: '${people.length} PEOPLE',
            title: 'Roster',
          ),
          bottom: BottomAction(
            child: PrimaryButton(
              label: r.owner || r.admin ? 'Appoint someone' : 'Appoint a CR',
              icon: Icons.add_rounded,
              onPressed: () async {
                await context.push(Routes.adminGrant);
                reload();
              },
            ),
          ),
          children: [
            if (pres != null) ...[
              ScopePills(campus: pres.campus, scope: pres.scopeLabel),
              const SizedBox(height: Space.sm),
            ],
            if (widget.volunteersTab != null) ...[
              SegmentedTrack<bool>(
                tabs: [(false, 'Maintainers'), (true, 'Volunteers · $offers')],
                value: _volunteers,
                onChanged: (v) => setState(() => _volunteers = v),
              ),
              const SizedBox(height: Space.sm),
            ],
            if (_volunteers)
              widget.volunteersTab!(tabCampus)
            else ...[
              ChoicePills<String>(
                values: const ['All', 'Presidents', 'CRs', 'Expiring'],
                selected: _filter,
                label: (v) => v,
                equal: true,
                onSelected: (v) => setState(() => _filter = v),
              ),
              if (activeOwners.isNotEmpty || admins.isNotEmpty) ...[
                const SectionLabel('Who appoints · every campus'),
                RowGroup(
                  children: [
                    for (final o in activeOwners)
                      _AppointerRow(
                        tag: 'OWNER',
                        name: o['name'] as String? ?? '',
                        email: o['email'] as String? ?? '',
                        line: 'Appoints admins · publishes',
                        phone: phones[o['email']],
                      ),
                    for (final g in admins)
                      _AppointerRow(
                        tag: 'ADMIN',
                        name: g.name,
                        email: g.email,
                        line:
                            'Appoints presidents · until '
                            '${shortDay(g.expiresAt, year: true)}',
                        phone: phones[g.email],
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
              if (live.isEmpty && activeOwners.isEmpty)
                const Note('Nobody here yet.'),
              const Note(
                'Names, emails and staff phone numbers are never hidden here. '
                'Only owners, admins and presidents can open this page; '
                'presidents see their own campus.',
              ),
            ],
          ],
        );
      },
    );
  }
}

/// An owner or admin: tier tag, name and email, what they do, and the
/// staff phone on the right.
class _AppointerRow extends StatelessWidget {
  const _AppointerRow({
    required this.tag,
    required this.name,
    required this.email,
    required this.line,
    this.phone,
  });
  final String tag, name, email, line;
  final String? phone;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 12, 15, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TierTag(tag, strong: true),
              const SizedBox(width: 8),
              if (phone != null)
                Expanded(
                  child: Text(
                    phone!,
                    textAlign: TextAlign.end,
                    style: TypeScale.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: p.text,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          NameEmail(name, email),
          Text(line, style: TypeScale.caption.copyWith(color: p.textMuted)),
        ],
      ),
    );
  }
}
