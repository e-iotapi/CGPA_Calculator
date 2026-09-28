import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/bottom_action.dart';
import 'package:cgpa_calculator/shared/widgets/dashed_outline.dart';
import 'package:cgpa_calculator/shared/widgets/notice.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:cgpa_calculator/shared/widgets/pill_button.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

      String note(Map<String, dynamic> o) {
        final by = o['addedBy'];
        final first = by is! Map || by['email'] == o['email'];
        final at = o['addedAt'];
        final when = at is Timestamp ? ', ${shortDay(at.toDate())}' : '';
        final how =
            first
                ? 'first owner, set in the Firebase console'
                : 'added by ${by['name']}$when';
        if (o['email'] == me) return 'You · $how';
        return how[0].toUpperCase() + how.substring(1);
      }

      Widget block(Map<String, dynamic> o) {
        final on = o['active'] == true;
        final mine = o['email'] == me;
        return Padding(
          padding: const EdgeInsets.fromLTRB(15, 12, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    on
                        ? const TierTag('OWNER')
                        : const TierTag('INACTIVE', strong: true),
                    const SizedBox(height: 6),
                    NameEmail('${o['name'] ?? ''}', '${o['email']}'),
                    const SizedBox(height: 2),
                    Text(
                      note(o),
                      style: TypeScale.caption.copyWith(
                        fontSize: 10.5,
                        color: p.textMuted,
                      ),
                    ),
                    if (mine) ...[
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(minHeight: 30),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: p.surfaceSunken,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Center(
                          widthFactor: 1,
                          heightFactor: 1,
                          child: Text(
                            'You can\'t remove yourself',
                            style: TypeScale.caption.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: p.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!mine)
                _SmallPill(
                  label: on ? 'Remove' : 'Restore',
                  color: on ? p.behind : p.text,
                  onTap:
                      () => run(
                        () => roleStore!.setOwnerActive(
                          o['email'] as String,
                          !on,
                        ),
                        on ? 'Removed. Kept for the audit log.' : 'Restored.',
                      ),
                ),
            ],
          ),
        );
      }

      final inactive = [
        for (final o in owners)
          if (o['active'] != true) o,
      ];
      return PageFrame(
        header: PageHeader(eyebrow: '$active ACTIVE', title: 'Owners'),
        bottom: BottomAction(
          child: PrimaryButton(
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
        ),
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
                if (o['active'] == true) block(o),
            ],
          ),
          if (inactive.isNotEmpty) ...[
            const SectionLabel('Inactive'),
            RowGroup(children: [for (final o in inactive) block(o)]),
          ],
          const SectionLabel('Add an owner'),
          AppCard(
            child: Column(
              children: [
                AppTextField(
                  controller: _email,
                  label: 'Email',
                  hint: 'name@gmail.com',
                  labelAbove: true,
                ),
                const SizedBox(height: Space.sm),
                AppTextField(
                  controller: _name,
                  label: 'Name',
                  labelAbove: true,
                ),
              ],
            ),
          ),
          const Note(
            'They sign in with this account. Removing an owner marks them '
            'inactive and is logged; nobody can remove themselves, so there is '
            'always one left. Every owner lost at once? The Firebase console is '
            'the only way back in.',
          ),
        ],
      );
    },
  );
}

/// A 32 tall outlined pill with a 44 px hit area (Owners' Remove, N16).
class _SmallPill extends StatelessWidget {
  const _SmallPill({
    required this.label,
    required this.color,
    required this.onTap,
  });
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Container(
              constraints: const BoxConstraints(minHeight: 32),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: ShapeDecoration(
                shape: StadiumBorder(side: BorderSide(color: p.outline)),
              ),
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: Text(
                  label,
                  style: TypeScale.body.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
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
      final p = AppPalette.of(context);
      final t = _t ??= loaded;
      final owner = myRoles.value.owner;
      // Every row stacks its stepper under the label together, on a narrow
      // screen or with large text, rather than one row at a time (N4).
      final stacked =
          MediaQuery.sizeOf(context).width < 360 ||
          MediaQuery.textScalerOf(context).scale(10) > 12;
      // A CR term is counted in semesters of 182 days, the others in years
      // (N14); − / + step a whole unit.
      Widget row(
        String tag,
        String title,
        int days,
        bool may,
        GrantTerms Function(int) set, {
        bool semesters = false,
      }) {
        final step = semesters ? 182 : 365;
        final n = (days / step).round();
        final unit = semesters ? 'semester' : 'year';
        final ends = DateTime.now().add(Duration(days: days));
        final number = Container(
          constraints: const BoxConstraints(minWidth: 34),
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: p.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: p.outline),
          ),
          child: Text(
            '$n',
            style: TypeScale.body.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: p.text,
            ),
          ),
        );
        final unitText = Text(
          '$unit${n == 1 ? '' : 's'}',
          style: TypeScale.caption.copyWith(
            fontWeight: FontWeight.w600,
            color: p.textMuted,
          ),
        );
        return Padding(
          padding: const EdgeInsets.fromLTRB(15, 12, 12, 12),
          child: _Stepped(
            stacked: stacked,
            label: Column(
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
                  style: TypeScale.caption.copyWith(color: p.textMuted),
                ),
              ],
            ),
            trailing:
                may
                    ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PillButton.icon(
                          icon: Icons.remove_rounded,
                          semanticLabel: 'Shorter',
                          onPressed:
                              n > 1
                                  ? () => setState(() => _t = set(days - step))
                                  : null,
                        ),
                        const SizedBox(width: 8),
                        number,
                        const SizedBox(width: 5),
                        unitText,
                        const SizedBox(width: 8),
                        PillButton.icon(
                          icon: Icons.add_rounded,
                          semanticLabel: 'Longer',
                          onPressed:
                              () => setState(() => _t = set(days + step)),
                        ),
                      ],
                    )
                    // Locked: the length in a grey pill, no buttons.
                    : Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: p.surfaceSunken,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 14,
                            color: p.textMuted,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '$n $unit${n == 1 ? '' : 's'}',
                            style: TypeScale.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              color: p.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
          ),
        );
      }

      return PageFrame(
        header: const PageHeader(
          eyebrow: 'CONFIG · GRANT TERMS',
          title: 'How long a grant lasts',
        ),
        bottom: BottomAction(
          child: PrimaryButton(
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
                'Course manager',
                t.crDays,
                true,
                semesters: true,
                (d) => (
                  crDays: d,
                  presidentDays: t.presidentDays,
                  adminDays: t.adminDays,
                ),
              ),
              row(
                'PRESIDENT',
                'President',
                t.presidentDays,
                true,
                (d) => (
                  crDays: t.crDays,
                  presidentDays: d,
                  adminDays: t.adminDays,
                ),
              ),
              row(
                'ADMIN',
                'Admin',
                t.adminDays,
                owner,
                (d) => (
                  crDays: t.crDays,
                  presidentDays: t.presidentDays,
                  adminDays: d,
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          const Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ScopeChip('Admins: CR and president terms'),
              ScopeChip('Owners only: the admin term', muted: true),
            ],
          ),
          const SizedBox(height: Space.md),
          const Notice(
            text: TextSpan(
              text:
                  'A new length applies to grants given or renewed from now '
                  'on. Grants already running keep their end date. Every '
                  'change is logged with your name.',
            ),
          ),
        ],
      );
    },
  );
}

/// A label with its trailing control beside it, or under it and to the
/// right when [stacked].
class _Stepped extends StatelessWidget {
  const _Stepped({
    required this.stacked,
    required this.label,
    required this.trailing,
  });
  final bool stacked;
  final Widget label, trailing;

  @override
  Widget build(BuildContext context) =>
      stacked
          ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              label,
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerRight, child: trailing),
            ],
          )
          : Row(
            children: [
              Expanded(child: label),
              const SizedBox(width: 8),
              trailing,
            ],
          );
}

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

  /// The contact, and who last changed it with their role, from the audit
  /// entry the save wrote.
  Future<(PublicContact?, ({String name, String? role, DateTime? at})?)>
  _load() async {
    final store = roleStore!;
    final c = await store.publicContact();
    final m = (await store.db.collection('config').doc('public').get()).data();
    final by = m?['updatedBy'] as Map?;
    if (by == null) return (c, null);
    String? role;
    if (m?['auditId'] case final String id) {
      final e = (await store.db.collection('audit').doc(id).get()).data();
      role = (e?['actor'] as Map?)?['role'] as String?;
    }
    return (
      c,
      (
        name: by['name'] as String? ?? '',
        role: role,
        at: (m?['updatedAt'] as Timestamp?)?.toDate(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Loaded(
    load: _load,
    builder: (context, loaded, _) {
      final (c, changed) = loaded;
      if (!_loaded && c != null) {
        _name.text = c.name;
        _target.text = c.target;
        _enabled = c.enabled;
        _method = c.method;
      }
      _loaded = true;
      final p = AppPalette.of(context);
      final name = _name.text.trim();
      return PageFrame(
        header: const PageHeader(
          eyebrow: 'CONFIG · PUBLIC · OWNERS AND ADMINS',
          title: 'Public contact',
        ),
        // The contact is read live, so a save shows at once (a Departure
        // from "after the next publish", agreed with the user).
        bottom: BottomAction(
          child: PrimaryButton(
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
        ),
        children: [
          AppCard(
            // One node: the switch is announced with its title.
            child: MergeSemantics(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Show on empty pages',
                          style: TypeScale.body.copyWith(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: p.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Off hides the whole block, everywhere.',
                          style: TypeScale.caption.copyWith(color: p.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Switch(
                    value: _enabled,
                    onChanged: (v) => setState(() => _enabled = v),
                  ),
                ],
              ),
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
                  labelAbove: true,
                  onChanged: (_) => setState(() {}),
                ),
                const SectionLabel('How'),
                ChoicePills<String>(
                  values: const ['whatsapp', 'phone', 'email'],
                  selected: _method,
                  equal: true,
                  label:
                      (m) => switch (m) {
                        'whatsapp' => 'WhatsApp',
                        'phone' => 'Phone',
                        _ => 'Email',
                      },
                  onSelected: (m) => setState(() => _method = m),
                ),
                const SizedBox(height: Space.md),
                AppTextField(
                  controller: _target,
                  label: _method == 'email' ? 'Address' : 'Number',
                  labelAbove: true,
                ),
                const Note(
                  'Never drawn on the page. It sits behind the button.',
                ),
              ],
            ),
          ),
          if (changed != null)
            Note(
              'Last changed by ${changed.name}'
              '${changed.role == null ? '' : ' (${changed.role})'}'
              '${changed.at == null ? '' : ', ${ago(changed.at)}'}. '
              'Every change is logged.',
            ),
          const SectionLabel('Students see'),
          DashedOutline(
            color: p.outline,
            radius: 20,
            width: 1.5,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Are you the department president?',
                    style: TypeScale.body.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: p.text,
                    ),
                  ),
                  const SizedBox(height: Space.sm),
                  // A picture of the button, not a button.
                  ExcludeSemantics(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: ShapeDecoration(
                        color: p.inverse,
                        shape: const StadiumBorder(),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 15,
                            color: p.onInverse,
                          ),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              'Message ${name.isEmpty ? '…' : name}',
                              style: TypeScale.body.copyWith(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: p.onInverse,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Note('Only on a department with no resources yet.'),
                ],
              ),
            ),
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
                        text: '  ${shortEmail(e.actorEmail)}',
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
