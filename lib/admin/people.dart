import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/routes.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/bottom_action.dart';
import 'package:cgpa_calculator/shared/widgets/card_row.dart';
import 'package:cgpa_calculator/shared/widgets/confirm_dialog.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:cgpa_calculator/shared/widgets/sliver_row_group.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// One grant as a card: tier, scope pills, name and email, and a line.
class GrantTile extends StatelessWidget {
  const GrantTile({
    super.key,
    required this.g,
    this.line,
    this.onTap,
    this.phone,
    this.showPhone = false,
  });
  final Grant g;
  final String? line;
  final VoidCallback? onTap;

  /// The person's staff phone (fix 8), shown when [showPhone] is set.
  final String? phone;
  final bool showPhone;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final now = DateTime.now();
    final left = g.expiresAt.difference(now).inDays;
    final soon = expiresSoon(g);
    final live = g.liveAt(now);
    final right = TypeScale.label.copyWith(
      color:
          !live
              ? p.behind
              : soon
              ? p.noticeTone.text
              : p.textMuted,
    );
    return InkWell(
      onTap: onTap,
      child: Container(
        color: soon ? p.noticeTone.fill : null,
        padding: const EdgeInsets.fromLTRB(15, 12, 15, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TierTag.of(g.role),
                      if (g.role != GrantRole.admin) ...[
                        ScopeChip(
                          campusName(g.campus),
                          icon: Icons.place_outlined,
                        ),
                        ScopeChip(g.scopeLabel, muted: true),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // At most a third of the row, wrapping, so large text never
                // pushes it off the edge.
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      !live
                          ? (g.active ? 'EXPIRED' : 'REVOKED')
                          : soon
                          ? 'EXPIRES IN $left DAY${left == 1 ? '' : 'S'}'
                          : shortDay(g.expiresAt, year: true),
                      textAlign: TextAlign.end,
                      style: right,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            NameEmail(g.name, g.email),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    line ??
                        [
                          if (g.grantedByName.isNotEmpty)
                            'Appointed by ${g.grantedByName}',
                          live
                              ? 'until ${shortDay(g.expiresAt, year: true)}'
                              : 'ended',
                        ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TypeScale.caption.copyWith(
                      fontSize: 10.5,
                      color: p.textMuted,
                    ),
                  ),
                ),
                if (showPhone && live) ...[
                  const SizedBox(width: 8),
                  // No icon for a number that is not there.
                  if (phone != null) ...[
                    Icon(Icons.call_outlined, size: 12, color: p.textMuted),
                    const SizedBox(width: 4),
                  ],
                  SelectableText(
                    phone ?? 'No phone yet',
                    style: TypeScale.caption.copyWith(
                      fontSize: phone == null ? 10.5 : 11,
                      color: phone == null ? p.textMuted : p.text,
                      fontWeight:
                          phone == null ? FontWeight.w500 : FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
            if (soon) ...[
              const SizedBox(height: 4),
              Text(
                'Renewing is deliberate. Do nothing and the grant lapses on '
                'its own.',
                style: TypeScale.caption.copyWith(
                  fontSize: 10.5,
                  height: 1.4,
                  color: p.noticeTone.text,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A live grant with at most 7 days left (§10.3): drawn amber.
bool expiresSoon(Grant g, [DateTime? now]) {
  final left = g.expiresAt.difference(now ?? DateTime.now()).inDays;
  return g.active && left >= 0 && left <= 7;
}

List<Grant> _byRole(List<Grant> all) => all..sort((a, b) {
  final r = a.role.index.compareTo(b.role.index);
  return r != 0 ? r : a.name.compareTo(b.name);
});

/// Board `AdminPeople`: every grant, filtered by campus or expiring soon;
/// tap one for that person's recent edits and the revoke button.
class AdminPeople extends StatefulWidget {
  const AdminPeople({super.key});

  @override
  State<AdminPeople> createState() => _AdminPeopleState();
}

class _AdminPeopleState extends State<AdminPeople> {
  String _filter = 'All';

  bool _shows(Grant g) => switch (_filter) {
    'All' => true,
    'Expiring' => expiresSoon(g),
    _ => campusName(g.campus) == _filter || g.campus == 'all',
  };

  @override
  Widget build(BuildContext context) => Loaded<List<Grant>>(
    cacheKey: 'people-roster',
    load: () async => _byRole(await roleStore!.roster()),
    peek: () => switch (roleStore!.peekRoster()) {
      final all? => _byRole(all),
      _ => null,
    },
    builder: (context, grants, reload) {
      final shown = grants.where(_shows).toList();
      final now = DateTime.now();
      final people =
          {
            for (final g in grants)
              if (g.liveAt(now)) g.email,
          }.length;
      return PageFrame(
        header: PageHeader(eyebrow: '$people PEOPLE', title: 'Maintainers'),
        bottom: BottomAction(
          child: PrimaryButton(
            label: 'Appoint someone',
            icon: Icons.add_rounded,
            onPressed: () async {
              await context.push(Routes.adminGrant);
              reload();
            },
          ),
        ),
        children: [
          ChoicePills<String>(
            values: const [
              'All',
              'Goa',
              'Hyderabad',
              'Pilani',
              'Dubai',
              'Expiring',
            ],
            selected: _filter,
            label: (v) => v == 'Hyderabad' ? 'Hyd' : v,
            equal: true,
            onSelected: (v) => setState(() => _filter = v),
          ),
          const SizedBox(height: Space.md),
          if (shown.isEmpty)
            const Note('Nobody here yet.')
          else
            // Lazy: a campus roster runs to hundreds (UI_OPT O5.1).
            SliverRowGroup(
              count: shown.length,
              row: (context, i) {
                final g = shown[i];
                return GrantTile(
                  g: g,
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => PersonPage(grant: g)),
                    );
                    reload();
                  },
                );
              },
            ),
          const Note(
            'Names and emails are always shown. Tap anyone to see what they '
            'have changed, and revoke from that same screen — removing '
            'someone does not undo their edits.',
          ),
        ],
      );
    },
  );
}

/// One person's grant, their recent edits from the audit log, and revoke
/// beside them (§4: removal does not undo what they wrote).
class PersonPage extends StatefulWidget {
  const PersonPage({super.key, required this.grant});
  final Grant grant;

  @override
  State<PersonPage> createState() => _PersonPageState();
}

class _PersonPageState extends State<PersonPage> {
  bool _busy = false;
  late Grant _g = widget.grant;

  Future<void> _revoke() async {
    final ok = await confirmDialog(
      context,
      title: 'Revoke ${_g.name}?',
      body:
          'Their ${_g.role.label.toLowerCase()} access for ${_g.scopeLabel} '
          'ends now. What they changed stays; revert a bad edit separately.',
      action: 'Revoke',
      cancel: 'Keep',
      danger: true,
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await roleStore!.revoke(_g);
      _g = Grant(
        role: _g.role,
        email: _g.email,
        name: _g.name,
        campus: _g.campus,
        scope: _g.scope,
        programme: _g.programme,
        active: false,
        expiresAt: _g.expiresAt,
        grantedByName: _g.grantedByName,
      );
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(problem(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = myRoles.value;
    final mayRevoke = switch (_g.role) {
      GrantRole.admin => r.owner,
      GrantRole.dept => r.owner || r.admin,
      GrantRole.contributor =>
        r.owner ||
            r.admin ||
            r.presidencies.any((p) => p.campus == _g.campus),
      GrantRole.course =>
        r.owner ||
            r.admin ||
            r.presidencies.any(
              (p) => p.campus == _g.campus && p.scope == deptOf(_g.scope),
            ),
    };
    final revoke = mayRevoke && _g.active;
    // "CR" is an acronym, not a sentence-case word (BUG-51): keep it as is,
    // sentence-case everything else instead of the tag's raw ALL-CAPS form.
    final roleWord =
        _g.role == GrantRole.course
            ? 'CR'
            : '${_g.role.tag[0]}${_g.role.tag.substring(1).toLowerCase()}';
    return PageFrame(
      header: PageHeader(eyebrow: _g.role.tag, title: _g.name),
      bottom:
          revoke
              ? BottomAction(
                caption:
                    'Revoking deactivates the grant; it is kept, with the '
                    'audit log pointing at it.'
                    // Only a president grant leaves CRs behind (BUG-51).
                    '${_g.role == GrantRole.dept ? ' Their CRs stay in place.' : ''}',
                child: PrimaryButton(
                  label: _busy ? 'Revoking…' : 'Revoke $roleWord',
                  onPressed: _busy ? null : _revoke,
                ),
              )
              : null,
      children: [
        RowGroup(children: [GrantTile(g: _g)]),
        const SectionLabel('Recent edits'),
        Loaded<List<AuditEntry>>(
          cacheKey: 'people-recent-edits|${_g.email}',
          load: () => roleStore!.audit(actor: _g.email, limit: 20),
          peek: () => roleStore!.peekAudit(actor: _g.email, limit: 20),
          builder:
              (context, entries, _) =>
                  entries.isEmpty
                      ? const Note('Nothing changed yet.')
                      : AppCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (final (i, e) in entries.indexed) ...[
                              if (i > 0) const CardDivider(),
                              CardRow(
                                title: e.summary,
                                titleLines: 2,
                                subtitle: ago(e.at),
                              ),
                            ],
                          ],
                        ),
                      ),
        ),
      ],
    );
  }
}
