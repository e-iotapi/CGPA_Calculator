import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/roles/contacts.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/features/marks/official.dart';
import 'package:cgpa_calculator/features/resources/resources_page.dart';
import 'package:cgpa_calculator/features/roles/rep_profile.dart';
import 'package:cgpa_calculator/script.dart' as app;
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/dashed_outline.dart';
import 'package:cgpa_calculator/shared/widgets/tag_badge.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:cgpa_calculator/features/setup/campus_pick_page.dart';
import 'package:flutter/material.dart';
import 'package:cgpa_calculator/core/platform/browser.dart';

typedef _Data = ({List<DirectoryEntry> people, Map<String, Volunteer?> offers});

/// Board `Representatives` (§13.5): the department president and the CR of
/// each course the student is taking, with only what each chose to show.
/// A course with no CR offers "Volunteer" (§16.3 fix 16).
class RepresentativesPage extends StatefulWidget {
  const RepresentativesPage({super.key});

  @override
  State<RepresentativesPage> createState() => _RepresentativesPageState();
}

class _RepresentativesPageState extends State<RepresentativesPage> {
  int _loads = 0;

  String? get _campus => viewCampus();

  Future<_Data> _load(List<String> courses) async {
    final store = contactStore!;
    final people = await store.directory(_campus!);
    final now = DateTime.now();
    final offers = <String, Volunteer?>{};
    for (final c in courses) {
      final hasCr = people.any(
        (p) => p
            .liveAt(now)
            .any((r) => r.role == GrantRole.course && r.scope == c),
      );
      if (!hasCr) offers[c] = await store.myOffer(_campus!, c);
    }
    return (people: people, offers: offers);
  }

  Future<void> _volunteer(String courseId, Volunteer? mine) async {
    final store = contactStore!;
    try {
      if (mine != null && mine.open) {
        await store.withdraw(mine);
      } else {
        await store.volunteer(
          _campus!,
          courseId,
          name: roleStore!.myName,
          term: currentTerm(DateTime.now()),
        );
      }
      if (mounted) setState(() => _loads++);
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
    final campus = _campus;
    final header = PageHeader(
      eyebrow:
          [
            campus == null ? 'Representatives' : campusName(campus),
            [
              app.selecteddiscipline.substring(0, 2),
              app.selecteddiscipline.substring(2),
            ].where((h) => h != '--' && h != 'B-').join(' '),
          ].where((s) => s.isNotEmpty).join(' · ').toUpperCase(),
      title: 'Representatives',
    );
    if (contactStore == null || campus == null) {
      return PageFrame(
        header: header,
        children: [
          if (campus == null && roleStore != null)
            campusPrompt(context)
          else
            const Note(
              'Sign in with your BITS account to see your representatives.',
            ),
        ],
      );
    }
    final courses = takingNow().toList()..sort();
    final degrees = [
      app.selecteddiscipline.substring(0, 2),
      app.selecteddiscipline.substring(2),
    ];
    final depts = myDepartments(courses, degrees);
    final crFor = [
      for (final g in myRoles.value.grants)
        if (g.role == GrantRole.course && g.active) g.scope,
    ];
    return Loaded<_Data>(
      key: ValueKey(_loads),
      load: () => _load(courses),
      builder: (context, data, _) {
        final now = DateTime.now();
        List<(DirectoryEntry, ListedRole)> holders(
          GrantRole role,
          String s, {
          bool secretary = false,
        }) => [
          for (final e in data.people)
            for (final r in e.liveAt(now))
              if (r.role == role && r.scope == s && r.secretary == secretary)
                (e, r),
        ]..sort((a, b) => a.$2.until.compareTo(b.$2.until));
        // Presidents go by branch code: a student's own branch of a
        // department, else every branch of it that has one listed.
        List<(DirectoryEntry, ListedRole)> pres(
          String branch, {
          bool secretary = false,
        }) => [
          for (final d in depts)
            for (final h in holders(GrantRole.dept, d, secretary: secretary))
              if (branchCode(d, h.$2.programme) == branch) h,
        ];
        final branches = <String>[], missing = <String>[];
        for (final d in depts) {
          final all = departments[d]?.programmes ?? [d];
          final own = all.where(degrees.contains);
          final listed = {
            for (final h in holders(GrantRole.dept, d))
              branchCode(d, h.$2.programme),
          };
          // One appointed before branches were recorded goes by [d].
          branches.addAll(
            listed.where((b) => own.isEmpty || own.contains(b) || b == d),
          );
          missing.addAll(
            own.isEmpty
                ? (listed.isEmpty ? all : const [])
                : own.where((b) => !listed.contains(b)),
          );
        }
        return PageFrame(
          header: header,
          children: [
            Text(
              'Who maintains your courses on your campus. Names always show; '
              'each contact detail appears only if that person chose to share '
              'it.',
              style: TypeScale.caption.copyWith(
                fontSize: 11.5,
                height: 1.45,
                color: p.textMuted,
              ),
            ),
            if (courses.isEmpty)
              const Note(
                'Your representatives follow the courses you are taking this '
                'semester. Add them to your grades first.',
              ),
            if (depts.isNotEmpty) const SectionLabel('Department'),
            for (final b in branches)
              if (pres(b) case final list when list.isNotEmpty) ...[
                _President(code: b, list: list, now: now),
                if (pres(b, secretary: true) case final s
                    when s.isNotEmpty) ...[
                  const SizedBox(height: Space.xs),
                  _President(
                    code: b,
                    list: s,
                    now: now,
                    title: 'Department secretary',
                  ),
                ],
              ],
            if (missing.isNotEmpty) ...[
              Note('No president listed for ${missing.join(', ')} yet.'),
              const SizedBox(height: Space.sm),
              publicContactBlock(context),
            ],
            if (courses.isNotEmpty) ...[
              const SectionLabel('Your courses this semester'),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Column(
                  children: [
                    for (final (i, c) in courses.indexed) ...[
                      if (i > 0) Divider(height: 1, color: p.divider),
                      _CourseRow(
                        title: '$c · ${courseTitle(c)}',
                        cr: holders(GrantRole.course, c).firstOrNull?.$1,
                        offer: data.offers[c],
                        noCr: data.offers.containsKey(c),
                        onVolunteer: () => _volunteer(c, data.offers[c]),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            for (final c in crFor) _CrCard(course: c),
          ],
        );
      },
    );
  }
}

/// "email and phone": what [e] chose to share, in words.
String _shared(DirectoryEntry e) {
  final all = [
    if (e.shownEmail != null) 'email',
    if (e.whatsapp != null) 'WhatsApp',
    if (e.phone != null) 'phone',
  ];
  if (all.isEmpty) return 'nothing shared';
  if (all.length == 1) return all.first;
  return '${all.sublist(0, all.length - 1).join(', ')} and ${all.last}';
}

/// "98xxx 41xxx": enough to recognise the number, not to copy it off a
/// screenshot. Tapping still dials the whole number.
String maskPhone(String t) {
  final d = t.replaceAll(RegExp(r'[^0-9]'), '');
  final ten = d.length > 10 ? d.substring(d.length - 10) : d;
  if (ten.length < 10) return t;
  return '${ten.substring(0, 2)}xxx ${ten.substring(5, 7)}xxx';
}

typedef _Channel = (IconData, String, Uri);

List<_Channel> _channels(DirectoryEntry e) => [
  if (e.shownEmail case final m?)
    (Icons.mail_outline, 'Email', Uri.parse('mailto:$m')),
  if (e.whatsapp case final w?)
    (
      Icons.chat_outlined,
      'WhatsApp',
      Uri.parse('https://wa.me/${w.replaceAll(RegExp(r'[^0-9]'), '')}'),
    ),
  if (e.phone case final t?)
    (
      Icons.call_outlined,
      maskPhone(t),
      Uri.parse('tel:${t.replaceAll(' ', '')}'),
    ),
];

void _open(Uri uri) => openUrl('$uri');

class _President extends StatelessWidget {
  const _President({
    required this.code,
    required this.list,
    required this.now,
    this.title = 'Department president',
  });
  final String code, title;
  final List<(DirectoryEntry, ListedRole)> list;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    // Sorted by end: the first is in office; a later one is taking over.
    final (e, r) = list.first;
    final next = list.length > 1 ? list[1].$1 : null;
    final days = r.until.difference(now).inDays;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: p.hero,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  code,
                  style: TypeScale.body.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: p.onHero,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.name,
                      style: TypeScale.body.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '$title · ${_shared(e)}',
                      style: TypeScale.caption.copyWith(
                        fontSize: 10.5,
                        color: p.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_channels(e) case final ch when ch.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (icon, label, uri) in ch)
                  _ContactPill(
                    icon: icon,
                    label: label,
                    onTap: () => _open(uri),
                  ),
              ],
            ),
          ],
          if (next != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TagBadge(
                  'HANDOVER IN $days DAY${days == 1 ? '' : 'S'}',
                  tone: TagTone.yours,
                ),
                Text(
                  '${next.name} is taking over',
                  style: TypeScale.caption.copyWith(
                    fontSize: 10.5,
                    color: p.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ContactPill extends StatelessWidget {
  const _ContactPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Material(
      color: p.surfaceSunken,
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: p.text),
              const SizedBox(width: 6),
              Text(
                label,
                style: TypeScale.body.copyWith(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: p.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CourseRow extends StatelessWidget {
  const _CourseRow({
    required this.title,
    required this.cr,
    required this.offer,
    required this.noCr,
    required this.onVolunteer,
  });
  final String title;
  final DirectoryEntry? cr;
  final Volunteer? offer;
  final bool noCr;
  final VoidCallback onVolunteer;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final e = cr;
    final offered = offer?.open ?? false;
    final sub =
        e != null
            ? '${e.name} · ${_shared(e)}'
            : offered
            ? 'You offered to be CR'
            : 'No CR appointed yet';
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 58),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TypeScale.body.copyWith(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    sub,
                    style: TypeScale.caption.copyWith(
                      fontSize: 10.5,
                      color: p.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (e != null)
              for (final (icon, label, uri) in _channels(e))
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Tooltip(
                    message: label,
                    child: Material(
                      color: p.surfaceSunken,
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: () => _open(uri),
                        customBorder: const CircleBorder(),
                        child: SizedBox.square(
                          dimension: 32,
                          child: Icon(icon, size: 15, color: p.text),
                        ),
                      ),
                    ),
                  ),
                ),
            if (e == null && noCr)
              Semantics(
                button: true,
                label: offered ? 'Withdraw' : 'Volunteer',
                onTap: onVolunteer,
                excludeSemantics: true,
                child: InkWell(
                  onTap: onVolunteer,
                  customBorder: const StadiumBorder(),
                  child: DashedOutline(
                    color: p.textMuted,
                    radius: 14,
                    child: SizedBox(
                      height: 28,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Center(
                          widthFactor: 1,
                          child: Text(
                            offered ? 'Withdraw' : 'Volunteer',
                            style: TypeScale.body.copyWith(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CrCard extends StatelessWidget {
  const _CrCard({required this.course});
  final String course;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        color: p.inverse,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You are a CR for $course',
                  style: TypeScale.body.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: p.onInverse,
                  ),
                ),
                Text(
                  'Choose what this page shows about you',
                  style: TypeScale.caption.copyWith(
                    fontSize: 10.5,
                    color: const Color(0xFFB0B0A4),
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: p.hero,
            shape: const StadiumBorder(),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap:
                  () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const RepProfilePage(),
                    ),
                  ),
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                child: Text(
                  'Edit',
                  style: TypeScale.body.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: p.onHero,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
