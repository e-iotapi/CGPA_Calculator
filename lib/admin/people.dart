import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/routes.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
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
    final left = g.expiresAt.difference(DateTime.now()).inDays;
    final soon = g.active && left >= 0 && left <= 14;
    return InkWell(
      onTap: onTap,
      child: Container(
        color: soon ? p.noticeTone.fill : null,
        padding: const EdgeInsets.fromLTRB(15, 12, 15, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TierTag.of(g.role),
                if (g.role != GrantRole.admin) ...[
                  ScopeChip(campusName(g.campus), icon: Icons.place_outlined),
                  ScopeChip(
                    g.role == GrantRole.dept && g.programme != null
                        ? '${g.scope} · for ${g.programme}'
                        : g.scope,
                    muted: true,
                  ),
                ],
                if (!g.active)
                  Text(
                    'REVOKED',
                    style: TypeScale.label.copyWith(color: p.behind),
                  )
                else if (soon)
                  Text(
                    'EXPIRES IN $left DAYS',
                    style: TypeScale.label.copyWith(color: p.noticeTone.text),
                  ),
              ],
            ),
            const SizedBox(height: 7),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: g.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: '  ${g.email}',
                    style: TextStyle(fontSize: 11, color: p.textMuted),
                  ),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TypeScale.body.copyWith(fontSize: 13),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    line ??
                        [
                          if (g.grantedByName.isNotEmpty)
                            'Appointed by ${g.grantedByName}',
                          g.active
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
                if (showPhone && g.active) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.call_outlined, size: 12, color: p.textMuted),
                  const SizedBox(width: 4),
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
          ],
        ),
      ),
    );
  }
}

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
    'Expiring' =>
      g.active && g.expiresAt.difference(DateTime.now()).inDays <= 14,
    _ => campusName(g.campus) == _filter || g.campus == 'all',
  };

  @override
  Widget build(BuildContext context) => Loaded<List<Grant>>(
    load: () async {
      final all = await roleStore!.roster();
      return all..sort((a, b) {
        final r = a.role.index.compareTo(b.role.index);
        return r != 0 ? r : a.name.compareTo(b.name);
      });
    },
    builder: (context, grants, reload) {
      final shown = grants.where(_shows).toList();
      final people = {for (final g in grants) g.email}.length;
      return PageFrame(
        header: PageHeader(eyebrow: '$people PEOPLE', title: 'Maintainers'),
        children: [
          ChoicePills<String>(
            values: const ['All', 'Goa', 'Hyderabad', 'Pilani', 'Expiring'],
            selected: _filter,
            label: (v) => v == 'Hyderabad' ? 'Hyd' : v,
            onSelected: (v) => setState(() => _filter = v),
          ),
          const SizedBox(height: Space.md),
          if (shown.isEmpty)
            const Note('Nobody here yet.')
          else
            RowGroup(
              children: [
                for (final g in shown)
                  GrantTile(
                    g: g,
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => PersonPage(grant: g)),
                      );
                      reload();
                    },
                  ),
              ],
            ),
          const Note(
            'Names and emails are always shown. Tap anyone to see what they '
            'have changed, and revoke from that same screen — removing '
            'someone does not undo their edits.',
          ),
          const SizedBox(height: Space.lg),
          PrimaryButton(
            label: 'Appoint someone',
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
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: Text('Revoke ${_g.name}?'),
            content: Text(
              'Their ${_g.role.label.toLowerCase()} access for ${_g.scopeLabel} '
              'ends now. What they changed stays; revert a bad edit '
              'separately.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Keep'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Revoke'),
              ),
            ],
          ),
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
      GrantRole.course =>
        r.owner ||
            r.admin ||
            r.presidencies.any(
              (p) => p.campus == _g.campus && p.scope == deptOf(_g.scope),
            ),
    };
    return PageFrame(
      header: PageHeader(eyebrow: _g.role.tag, title: _g.name),
      children: [
        RowGroup(children: [GrantTile(g: _g)]),
        const SectionLabel('Recent edits'),
        Loaded<List<AuditEntry>>(
          load: () => roleStore!.audit(actor: _g.email, limit: 20),
          builder:
              (context, entries, _) =>
                  entries.isEmpty
                      ? const Note('Nothing changed yet.')
                      : AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final e in entries)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Text(
                                  '${e.summary} · ${ago(e.at)}',
                                  style: TypeScale.body.copyWith(fontSize: 12),
                                ),
                              ),
                          ],
                        ),
                      ),
        ),
        const SizedBox(height: Space.lg),
        if (mayRevoke && _g.active)
          PrimaryButton(
            label: _busy ? 'Revoking…' : 'Revoke ${_g.role.tag.toLowerCase()}',
            onPressed: _busy ? null : _revoke,
          ),
        if (mayRevoke && _g.active)
          const Note(
            'Revoking deactivates the grant; it is kept, with the audit log '
            'pointing at it. Their CRs stay in place.',
          ),
      ],
    );
  }
}
