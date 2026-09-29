import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/routes.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/analytics/analytics_store.dart';
import 'package:cgpa_calculator/core/catalog/publish.dart';
import 'package:cgpa_calculator/core/roles/capabilities.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/card_row.dart';
import 'package:cgpa_calculator/shared/widgets/count_badge.dart';
import 'package:cgpa_calculator/shared/widgets/notice.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// What the Controls rows say, read once when the page opens.
typedef _Live =
    ({
      List<Grant> grants,
      GrantTerms terms,
      PublicContact? contact,
      int owners,
      int drafts,
    });

/// "3 presidents", "1 admin".
String _n(int n, String one, [String? many]) =>
    '$n ${n == 1 ? one : many ?? '${one}s'}';

/// A grant term in words: "1 semester", "2 years", else days.
String termSpan(int days) {
  if (days % 365 == 0) return _n(days ~/ 365, 'year');
  final sems = (days / 183).round();
  if (sems > 0 && (days - sems * 183).abs() <= 3) return _n(sems, 'semester');
  return _n(days, 'day');
}

/// Board `AdminHome` (§10.2): tier and scope on an ink card, then the
/// sections this person can reach, each row with a live subtitle.
/// Publishing and ownership are owner only (§4).
class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  _Live? _live;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final store = roleStore;
    if (store == null) return;
    try {
      final r = await Future.wait<Object?>([
        store.roster(),
        store.terms(),
        store.publicContact(),
        store.owners(),
        CatalogStore(store).drafts(),
      ]);
      if (!mounted) return;
      setState(
        () =>
            _live = (
              grants: r[0] as List<Grant>,
              terms: r[1] as GrantTerms,
              contact: r[2] as PublicContact?,
              owners:
                  (r[3] as List<Map<String, dynamic>>)
                      .where((o) => o['active'] == true)
                      .length,
              drafts: (r[4] as List).length,
            ),
      );
    } catch (_) {
      // The rows keep their plain subtitles; each page says what failed.
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final r = myRoles.value;
    // Under Open as › Admin an owner sees what an admin sees.
    final owner = r.owner && viewAs.value?.role != Role.admin;
    final name = roleStore?.myName ?? '';
    final live = _live;
    void go(String to) => context.push(to);

    String? people() {
      if (live == null) return null;
      final now = DateTime.now();
      int count(GrantRole role) =>
          live.grants.where((g) => g.role == role && g.liveAt(now)).length;
      return '${_n(count(GrantRole.dept), 'president')} · '
          '${_n(count(GrantRole.course), 'course manager')} · '
          '${_n(count(GrantRole.admin), 'admin')}';
    }

    final contact = live?.contact;
    final contactOn =
        contact != null && contact.enabled && contact.target.isNotEmpty;

    return PageFrame(
      header: const ManagerHomeHeader(
        eyebrow: 'POINTER · ADMIN',
        title: 'Controls',
      ),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
          decoration: BoxDecoration(
            // Ink in both modes, as the board draws it (N11).
            color: p.navBackground,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TierTag(owner ? 'OWNER' : 'ADMIN'),
              const SizedBox(height: Space.sm),
              Text(
                '${name.isEmpty ? '' : '$name — '}'
                '${owner ? 'every campus, every department' : 'appointments, every campus'}',
                style: TypeScale.body.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: p.isDark ? p.text : p.onInverse,
                ),
              ),
              const SizedBox(height: Space.xs),
              Text(
                owner
                    ? 'Owners publish, appoint admins and add other owners. Any '
                        'verified Google account can be one — keep at least one '
                        'that survives graduation.'
                    : 'Admins appoint presidents and CRs and keep the public '
                        'contact. Publishing and ownership stay with owners.',
                style: TypeScale.caption.copyWith(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                  color: p.navIcon,
                ),
              ),
            ],
          ),
        ),
        const SectionLabel('People'),
        _Rows([
          _Row(
            Icons.group_outlined,
            'Maintainers',
            people() ?? 'Presidents, course managers and admins',
            () => go(Routes.adminPeople),
          ),
          _Row(
            Icons.add_rounded,
            'Appoint someone',
            // Only owners can appoint an admin (BUG-26): say so accurately.
            owner
                ? 'A president, CR or admin, for a set term'
                : 'A president or CR, for a set term',
            () => go(Routes.adminGrant),
            mint: true,
          ),
          _Row(
            Icons.badge_outlined,
            'Roster',
            'By campus, with volunteers',
            () => go(Routes.adminRoster),
          ),
        ]),
        const SectionLabel('Owners and admins'),
        _Rows([
          _Row(
            Icons.event_outlined,
            'Grant terms',
            live == null
                ? 'How long each grant lasts'
                : 'CR ${termSpan(live.terms.crDays)} · '
                    'president ${termSpan(live.terms.presidentDays)} · '
                    'admin ${termSpan(live.terms.adminDays)}',
            () => go(Routes.adminTerms),
          ),
          _Row(
            Icons.chat_bubble_outline_rounded,
            'Public contact',
            contact == null || contact.name.isEmpty
                ? 'Shown on empty pages'
                : '${contact.name} · ${contact.method == 'whatsapp' ? 'WhatsApp' : contact.method} · '
                    'shown on empty pages',
            () => go(Routes.adminContact),
            badge:
                live == null
                    ? null
                    : contactOn
                    ? const CountBadge('ON', tone: CountTone.on)
                    : const CountBadge('OFF', tone: CountTone.neutral),
          ),
          _Row(
            Icons.merge_type_rounded,
            'Merge professors',
            'Two entries for one person',
            () => go(Routes.adminMerge),
          ),
          _Row(
            Icons.notes_rounded,
            'Audit log',
            'Append-only · nothing here can be deleted',
            () => go(Routes.adminAudit),
          ),
        ]),
        if (owner) ...[
          const SectionLabel('Owner only'),
          _Rows([
            _Row(
              Icons.person_outline_rounded,
              'Owners',
              live == null
                  ? 'You cannot remove yourself'
                  : '${live.owners} active · you cannot remove yourself',
              () => go(Routes.adminOwners),
            ),
            _Row(
              Icons.publish_rounded,
              'Publish catalogue',
              live == null
                  ? 'The diff in CGPA terms, then Publish'
                  : live.drafts == 0
                  ? 'Nothing waiting'
                  : '${_n(live.drafts, 'change')} waiting',
              () => go(Routes.adminPublish),
              badge:
                  (live?.drafts ?? 0) > 0
                      ? CountBadge('${live!.drafts}')
                      : null,
            ),
            _Row(
              Icons.visibility_outlined,
              'Open Pointer as',
              'See the app as any role; saves stay yours',
              () => go(Routes.openAs),
            ),
            _Row(
              Icons.insights_outlined,
              'Site analytics',
              'Users, daily actives and the busiest hours',
              () => go(Routes.adminAnalytics),
            ),
          ]),
        ],
        const Note(
          'An admin sees everything above Owner only. Publishing and ownership '
          'stay with owners; the admin term is set by owners alone.',
        ),
      ],
    );
  }
}

/// One Controls row: a 32 px tile, the title over a live subtitle, and a
/// badge or chevron. No [onTap] draws it disabled.
class _Row {
  const _Row(
    this.icon,
    this.title,
    this.subtitle,
    this.onTap, {
    this.mint = false,
    this.badge,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback? onTap;
  final bool mint;
  final Widget? badge;
}

class _Rows extends StatelessWidget {
  const _Rows(this.rows);
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (i, r) in rows.indexed) ...[
            if (i > 0) const CardDivider(),
            Opacity(
              opacity: r.onTap == null ? 0.55 : 1,
              child: CardRow(
                minHeight: 56,
                leading: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: r.mint ? p.hero : p.surfaceSunken,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    r.icon,
                    size: 17,
                    color: r.mint ? p.onHero : p.icon,
                  ),
                ),
                title: r.title,
                subtitle: r.subtitle,
                trailing:
                    r.badge == null
                        ? null
                        : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            r.badge!,
                            Icon(
                              Icons.chevron_right_rounded,
                              color: p.textMuted,
                            ),
                          ],
                        ),
                onTap: r.onTap,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "1,240".
String _thousands(int n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

/// Owners only (§4, "Publishing, analytics"): Controls' structure over the
/// sampled day docs and exact people counts (PERF_TEST_PLAN.md §D). Rows of
/// numbers, no charts; about 40 reads an open.
class SiteAnalytics extends StatefulWidget {
  const SiteAnalytics({super.key, this.now});

  /// Fixed in render tests, so the dates do not move daily.
  final DateTime? now;

  @override
  State<SiteAnalytics> createState() => _SiteAnalyticsState();
}

class _SiteAnalyticsState extends State<SiteAnalytics> {
  String? _campus;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final store = AnalyticsStore(roleStore!.db);
    return Loaded<(PeopleCounts, List<DayCounts>)>(
      key: ValueKey(_campus),
      load: () async {
        final r = await Future.wait<Object>([
          store.counts(campus: _campus, now: widget.now),
          store.days(30, campus: _campus, now: widget.now),
        ]);
        return (r[0] as PeopleCounts, r[1] as List<DayCounts>);
      },
      builder: (context, data, _) {
        final (people, days) = data;
        final today = days.first;
        final peakDay = days.fold<DayCounts?>(
          null,
          (b, d) => d.dau > 0 && (b == null || d.dau > b.dau) ? d : b,
        );
        Widget rows(List<Widget> children) => AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final (i, c) in children.indexed) ...[
                if (i > 0) const CardDivider(),
                c,
              ],
            ],
          ),
        );
        CardRow row(
          String title,
          String value, {
          String? subtitle,
          bool peak = false,
        }) => CardRow(
          title: title,
          subtitle: subtitle,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (peak) ...[
                const CountBadge('PEAK', tone: CountTone.on),
                const SizedBox(width: Space.xs),
              ],
              Text(
                value,
                style: TypeScale.body.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        );
        String day(String d) {
          final t = DateTime.parse(d);
          const w = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
          const m = [
            'Jan',
            'Feb',
            'Mar',
            'Apr',
            'May',
            'Jun',
            'Jul',
            'Aug',
            'Sep',
            'Oct',
            'Nov',
            'Dec',
          ];
          return '${w[t.weekday - 1]} ${t.day} ${m[t.month - 1]}';
        }

        final hours =
            today.hours.entries.toList()
              ..sort((a, b) => a.key.compareTo(b.key));
        return PageFrame(
          header: const PageHeader(
            eyebrow: 'OWNERS ONLY',
            title: 'Site analytics',
          ),
          children: [
            ChoicePills<String?>(
              values: const [null, ...campuses],
              selected: _campus,
              label: (c) => c == null ? 'All campuses' : campusName(c),
              onSelected: (c) => setState(() => _campus = c),
            ),
            const SizedBox(height: Space.sm),
            Container(
              padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
              decoration: BoxDecoration(
                color: p.navBackground,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TierTag('TODAY'),
                  const SizedBox(height: Space.sm),
                  Text(
                    'About ${_thousands(today.dau)} active · '
                    '${_thousands(people.users)} users · '
                    '${_thousands(people.newToday)} new',
                    style: TypeScale.body.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: p.isDark ? p.text : p.onInverse,
                    ),
                  ),
                  const SizedBox(height: Space.xs),
                  Text(
                    today.peak == null
                        ? 'No sampled activity yet today.'
                        : 'Busiest so far ${today.peak!.key}:00, '
                            'about ${_thousands(today.peak!.value)} opens.',
                    style: TypeScale.caption.copyWith(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      height: 1.45,
                      color: p.navIcon,
                    ),
                  ),
                ],
              ),
            ),
            const SectionLabel('Users'),
            rows([
              row('Signed up', _thousands(people.users)),
              row('New this week', _thousands(people.newWeek)),
              row(
                'Active this week',
                _thousands(people.week),
                subtitle: 'Seen in the last 7 days, give or take a week',
              ),
              row('Active this month', _thousands(people.month)),
            ]),
            const SectionLabel('Daily actives, last 30 days'),
            rows([
              for (final d in days)
                row(day(d.day), _thousands(d.dau), peak: d == peakDay),
            ]),
            if (hours.isNotEmpty) ...[
              const SectionLabel('Today by hour'),
              rows([
                for (final h in hours)
                  row(
                    '${h.key}:00',
                    _thousands(h.value),
                    peak: h.key == today.peak?.key,
                  ),
              ]),
            ],
            const SizedBox(height: Space.sm),
            const Notice(
              text: TextSpan(
                text:
                    'Active counts are estimates from 1 in 20 people a day, '
                    'in India time. User counts are exact.',
              ),
            ),
          ],
        );
      },
    );
  }
}
