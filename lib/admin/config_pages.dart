import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:flutter/material.dart';

void _say(BuildContext context, String text) =>
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(text)));

/// Board `Owners`: add an owner by any verified Google address, or remove
/// one. Nobody removes themselves, so there is always one left (§4).
class OwnersPage extends StatefulWidget {
  const OwnersPage({super.key});

  @override
  State<OwnersPage> createState() => _OwnersPageState();
}

class _OwnersPageState extends State<OwnersPage> {
  final _email = TextEditingController();
  final _name = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Loaded<List<Map<String, dynamic>>>(
    load: () => roleStore!.owners(),
    builder: (context, owners, reload) {
      final p = AppPalette.of(context);
      final me = myRoles.value.email;
      final active = owners.where((o) => o['active'] == true).length;
      Future<void> run(Future<void> Function() f, String done) async {
        try {
          await f();
          if (context.mounted) _say(context, done);
          reload();
        } on Object catch (e) {
          if (context.mounted) _say(context, problem(e));
        }
      }

      return PageFrame(
        header: PageHeader(eyebrow: '$active ACTIVE', title: 'Owners'),
        children: [
          const Note(
            'Owners hold every power, on every campus, with no expiry. Any '
            'verified Google account can be one — it does not need a BITS '
            'address.',
          ),
          const SizedBox(height: Space.sm),
          RowGroup(
            children: [
              for (final o in owners)
                Padding(
                  padding: const EdgeInsets.fromLTRB(15, 12, 15, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TierTag(
                              o['active'] == true ? 'OWNER' : 'INACTIVE',
                              strong: o['active'] == true,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${o['name'] ?? ''}',
                              style: TypeScale.body.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${o['email']}',
                              style: TypeScale.caption.copyWith(
                                color: p.textMuted,
                              ),
                            ),
                            Text(
                              o['email'] == me
                                  ? 'You · you can\'t remove yourself'
                                  : o['addedBy'] is Map
                                  ? 'Added by ${(o['addedBy'] as Map)['name']}'
                                  : 'Set in the Firebase console',
                              style: TypeScale.caption.copyWith(
                                fontSize: 10.5,
                                color: p.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (o['email'] != me)
                        TextButton(
                          onPressed:
                              () => run(
                                () => roleStore!.setOwnerActive(
                                  o['email'] as String,
                                  o['active'] != true,
                                ),
                                o['active'] == true
                                    ? 'Removed. Kept for the audit log.'
                                    : 'Restored.',
                              ),
                          child: Text(
                            o['active'] == true ? 'Remove' : 'Restore',
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
          const SectionLabel('Add an owner'),
          AppCard(
            child: Column(
              children: [
                AppTextField(
                  controller: _email,
                  label: 'Email',
                  hint: 'name@gmail.com',
                ),
                const SizedBox(height: Space.sm),
                AppTextField(controller: _name, label: 'Name'),
              ],
            ),
          ),
          const Note(
            'They sign in with this account. Removing an owner marks them '
            'inactive and is logged; nobody can remove themselves, so there is '
            'always one left. Every owner lost at once? The Firebase console is '
            'the only way back in.',
          ),
          const SizedBox(height: Space.lg),
          PrimaryButton(
            label: 'Add owner',
            onPressed: () {
              final e = _email.text.trim();
              if (!e.contains('@') || _name.text.trim().isEmpty) {
                return _say(context, 'An email and a name, please.');
              }
              run(() async {
                await roleStore!.addOwner(e, _name.text.trim());
                _email.clear();
                _name.clear();
              }, 'Added.');
            },
          ),
        ],
      );
    },
  );
}

/// Board `Terms`: how long a grant lasts from the day it is given. Admins
/// change the CR and president lengths; only owners the admin length.
class TermsPage extends StatefulWidget {
  const TermsPage({super.key});

  @override
  State<TermsPage> createState() => _TermsPageState();
}

class _TermsPageState extends State<TermsPage> {
  GrantTerms? _t;
  bool _busy = false;

  @override
  Widget build(BuildContext context) => Loaded<GrantTerms>(
    load: () => roleStore!.terms(),
    builder: (context, loaded, _) {
      final t = _t ??= loaded;
      final owner = myRoles.value.owner;
      Widget row(
        String tag,
        String title,
        int days,
        bool may,
        int step,
        GrantTerms Function(int) set,
      ) {
        final ends = DateTime.now().add(Duration(days: days));
        return Padding(
          padding: const EdgeInsets.fromLTRB(15, 12, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TierTag(tag, strong: tag != 'PRESIDENT'),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: TypeScale.body.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Given today → ends ${shortDay(ends, year: true)}',
                      style: TypeScale.caption.copyWith(
                        color: AppPalette.of(context).textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Shorter',
                onPressed:
                    may && days > step
                        ? () => setState(() => _t = set(days - step))
                        : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              SizedBox(
                width: 58,
                child: Text(
                  '$days d',
                  textAlign: TextAlign.center,
                  style: TypeScale.body.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: 'Longer',
                onPressed:
                    may ? () => setState(() => _t = set(days + step)) : null,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        );
      }

      return PageFrame(
        header: const PageHeader(
          eyebrow: 'CONFIG · GRANT TERMS',
          title: 'How long a grant lasts',
        ),
        children: [
          const Note(
            'Counted from the day each grant is given. Nothing here revokes '
            'anyone: the rules simply stop honouring a grant past its end '
            'date. Owners never expire.',
          ),
          const SizedBox(height: Space.sm),
          RowGroup(
            children: [
              row(
                'CR',
                'Course manager · one semester',
                t.crDays,
                true,
                7,
                (d) => (
                  crDays: d,
                  presidentDays: t.presidentDays,
                  adminDays: t.adminDays,
                ),
              ),
              row(
                'PRESIDENT',
                'Department president · one year',
                t.presidentDays,
                true,
                7,
                (d) => (
                  crDays: t.crDays,
                  presidentDays: d,
                  adminDays: t.adminDays,
                ),
              ),
              row(
                'ADMIN',
                'Admin · two years',
                t.adminDays,
                owner,
                30,
                (d) => (
                  crDays: t.crDays,
                  presidentDays: t.presidentDays,
                  adminDays: d,
                ),
              ),
            ],
          ),
          const Note(
            'Admins change CR and president terms; only owners change the '
            'admin term. A new length applies to grants given or renewed from '
            'now on. Grants already running keep their end date. Every change '
            'is logged with your name.',
          ),
          const SizedBox(height: Space.lg),
          PrimaryButton(
            label: _busy ? 'Saving…' : 'Save grant terms',
            onPressed:
                _busy
                    ? null
                    : () async {
                      setState(() => _busy = true);
                      try {
                        await roleStore!.saveTerms(t);
                        if (context.mounted) _say(context, 'Saved.');
                      } on Object catch (e) {
                        if (context.mounted) _say(context, problem(e));
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
          ),
        ],
      );
    },
  );
}

/// Board `PublicContact`: who students on an empty page are told to message
/// (§10.5). The number is never drawn; it sits behind the button.
class PublicContactPage extends StatefulWidget {
  const PublicContactPage({super.key});

  @override
  State<PublicContactPage> createState() => _PublicContactPageState();
}

class _PublicContactPageState extends State<PublicContactPage> {
  final _name = TextEditingController(), _target = TextEditingController();
  bool _enabled = true, _loaded = false, _busy = false;
  String _method = 'whatsapp';

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Loaded<PublicContact?>(
    load: () => roleStore!.publicContact(),
    builder: (context, c, _) {
      if (!_loaded && c != null) {
        _name.text = c.name;
        _target.text = c.target;
        _enabled = c.enabled;
        _method = c.method;
      }
      _loaded = true;
      final p = AppPalette.of(context);
      return PageFrame(
        header: const PageHeader(
          eyebrow: 'CONFIG · PUBLIC · OWNERS AND ADMINS',
          title: 'Public contact',
        ),
        children: [
          AppCard(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
              title: const Text('Show on empty pages'),
              subtitle: const Text('Off hides the whole block, everywhere.'),
            ),
          ),
          const SizedBox(height: Space.sm),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  controller: _name,
                  label: 'Name on the button',
                  onChanged: (_) => setState(() {}),
                ),
                const SectionLabel('How'),
                ChoicePills<String>(
                  values: const ['whatsapp', 'phone', 'email'],
                  selected: _method,
                  label:
                      (m) => switch (m) {
                        'whatsapp' => 'WhatsApp',
                        'phone' => 'Phone',
                        _ => 'Email',
                      },
                  onSelected: (m) => setState(() => _method = m),
                ),
                const SizedBox(height: Space.sm),
                AppTextField(
                  controller: _target,
                  label: _method == 'email' ? 'Address' : 'Number',
                ),
                const Note(
                  'Never drawn on the page. It sits behind the button.',
                ),
              ],
            ),
          ),
          const SectionLabel('Students see'),
          AppCard(
            color: p.surfaceSunken,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you the department president?',
                  style: TypeScale.body.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: Space.sm),
                FilledButton(
                  onPressed: null,
                  child: Text(
                    'Message ${_name.text.isEmpty ? '…' : _name.text}',
                  ),
                ),
                const Note('Only on a department with no resources yet.'),
              ],
            ),
          ),
          const SizedBox(height: Space.lg),
          PrimaryButton(
            label: _busy ? 'Saving…' : 'Save · students see it at once',
            onPressed:
                _busy
                    ? null
                    : () async {
                      setState(() => _busy = true);
                      try {
                        await roleStore!.savePublicContact((
                          name: _name.text.trim(),
                          method: _method,
                          target: _target.text.trim(),
                          enabled: _enabled,
                        ));
                        if (context.mounted) _say(context, 'Saved.');
                      } on Object catch (e) {
                        if (context.mounted) _say(context, problem(e));
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
          ),
        ],
      );
    },
  );
}

/// Board `AuditLog`: who did what, with names and emails, filterable by
/// person and by course. Presidents see their own campus (§4).
class AuditLogPage extends StatefulWidget {
  const AuditLogPage({super.key, this.campus, this.course});
  final String? campus, course;

  @override
  State<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends State<AuditLogPage> {
  late String? _course = widget.course;
  final _courseField = TextEditingController();

  @override
  void dispose() {
    _courseField.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = myRoles.value;
    // Owners and admins read everything; a president their campus.
    final campus =
        r.owner || r.admin
            ? widget.campus
            : widget.campus ?? r.presidencies.firstOrNull?.campus;
    return PageFrame(
      header: const PageHeader(eyebrow: 'APPEND-ONLY', title: 'Audit log'),
      children: [
        if (campus != null) ...[
          ScopePills(campus: campus),
          const SizedBox(height: Space.sm),
        ],
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: _courseField,
                label: _course ?? 'Filter by course',
                hint: 'EEE F211',
              ),
            ),
            const SizedBox(width: Space.sm),
            IconButton(
              tooltip: _course == null ? 'Filter' : 'Clear',
              onPressed:
                  () => setState(() {
                    _course =
                        _course == null
                            ? _courseField.text.trim().toUpperCase()
                            : null;
                    if (_course?.isEmpty ?? false) _course = null;
                    _courseField.clear();
                  }),
              icon: Icon(
                _course == null
                    ? Icons.filter_list_rounded
                    : Icons.close_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.sm),
        Loaded<List<AuditEntry>>(
          key: ValueKey('$campus|$_course'),
          load: () => roleStore!.audit(campus: campus, course: _course),
          builder:
              (context, entries, _) =>
                  entries.isEmpty
                      ? const Note('Nothing logged here yet.')
                      : RowGroup(
                        children: [for (final e in entries) AuditTile(e)],
                      ),
        ),
        const Note(
          'Every change to shared data lands here in the same write, with the '
          'name and email of whoever made it. Nothing can be edited or '
          'deleted.',
        ),
      ],
    );
  }
}

class AuditTile extends StatelessWidget {
  const AuditTile(this.e, {super.key});
  final AuditEntry e;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final role = switch (e.actorRole) {
      'owner' => 'OWNER',
      'admin' => 'ADMIN',
      'president' || 'dept' => 'PRESIDENT',
      'course' || 'cr' => 'CR',
      final r => r.toUpperCase(),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 11, 15, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TierTag(role, strong: role != 'PRESIDENT'),
              const SizedBox(width: 6),
              Flexible(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: e.actorName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(
                        text: '  ${e.actorEmail}',
                        style: TextStyle(fontSize: 10.5, color: p.textMuted),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TypeScale.body.copyWith(fontSize: 12.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            e.summary,
            style: TypeScale.body.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            ago(e.at),
            style: TypeScale.caption.copyWith(
              fontSize: 10.5,
              color: p.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
