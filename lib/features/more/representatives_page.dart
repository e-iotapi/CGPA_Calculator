import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/catalog/catalog.dart';
import 'package:cgpa_calculator/core/roles/contacts.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/features/marks/official.dart';
import 'package:cgpa_calculator/features/resources/resources_page.dart';
import 'package:cgpa_calculator/features/roles/rep_profile.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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

  String? get _campus => campusOfAddress(roleStore?.me ?? '');

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
    final caption = TypeScale.caption.copyWith(
      height: 1.45,
      color: p.textMuted,
    );
    final campus = _campus;
    final header = PageHeader(
      eyebrow:
          campus == null ? 'REPRESENTATIVES' : campusName(campus).toUpperCase(),
      title: 'Representatives',
    );
    if (contactStore == null || campus == null) {
      return PageFrame(
        header: header,
        children: const [
          Note('Sign in with your BITS account to see your representatives.'),
        ],
      );
    }
    final courses = takingNow().toList()..sort();
    final depts = {for (final c in courses) deptOf(c)}.toList()..sort();
    return Loaded<_Data>(
      key: ValueKey(_loads),
      load: () => _load(courses),
      builder: (context, data, _) {
        final now = DateTime.now();
        List<(DirectoryEntry, ListedRole)> holders(GrantRole role, String s) =>
            [
              for (final e in data.people)
                for (final r in e.liveAt(now))
                  if (r.role == role && r.scope == s) (e, r),
            ]..sort((a, b) => b.$2.until.compareTo(a.$2.until));
        return PageFrame(
          header: header,
          children: [
            if (courses.isEmpty)
              const Note(
                'Your representatives follow the courses you are taking this '
                'semester. Add them to your grades first.',
              ),
            for (final d in depts) ...[
              SectionLabel('President · ${departments[d]?.name ?? d}'),
              ..._people(
                p,
                holders(GrantRole.dept, d),
                now,
                empty: 'No president listed for $d yet.',
              ),
            ],
            if (courses.isNotEmpty) const SectionLabel('Class representatives'),
            for (final c in courses) ...[
              Text(
                '$c · ${catalog.master.where((m) => m.id == c).firstOrNull?.title ?? ''}',
                style: TypeScale.label.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: Space.xs),
              if (data.offers.containsKey(c))
                _VolunteerCard(
                  mine: data.offers[c],
                  onTap: () => _volunteer(c, data.offers[c]),
                )
              else
                ..._people(p, holders(GrantRole.course, c), now, empty: ''),
              const SizedBox(height: Space.sm),
            ],
            Text(
              'Only what each person chose to show is here, and only to '
              'students on ${campusName(campus)}.',
              style: caption,
            ),
          ],
        );
      },
    );
  }

  List<Widget> _people(
    AppPalette p,
    List<(DirectoryEntry, ListedRole)> list,
    DateTime now, {
    required String empty,
  }) {
    if (list.isEmpty) return [if (empty.isNotEmpty) Note(empty)];
    return [
      for (final (i, (e, r)) in list.indexed) ...[
        _PersonCard(
          entry: e,
          // Two holders of one scope: the earlier end is handing over.
          handover:
              list.length > 1 && i > 0 && r.until.difference(now).inDays <= 20
                  ? r.until
                  : null,
        ),
        const SizedBox(height: Space.xs),
      ],
    ];
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.entry, this.handover});
  final DirectoryEntry entry;
  final DateTime? handover;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final e = entry;
    Widget link(IconData icon, String label, Uri uri) => TextButton.icon(
      onPressed: () => launchUrl(uri, mode: LaunchMode.externalApplication),
      icon: Icon(icon, size: 16),
      label: Text(label),
    );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            e.name,
            style: TypeScale.body.copyWith(fontWeight: FontWeight.w700),
          ),
          if (handover != null)
            Text(
              'Handing over · access ends ${shortDay(handover!)}',
              style: TypeScale.caption.copyWith(color: p.behind),
            ),
          Wrap(
            spacing: Space.xs,
            children: [
              if (e.shownEmail case final m?)
                link(Icons.mail_outline, 'Email', Uri.parse('mailto:$m')),
              if (e.whatsapp case final w?)
                link(
                  Icons.chat_outlined,
                  'WhatsApp',
                  Uri.parse(
                    'https://wa.me/${w.replaceAll(RegExp(r'[^0-9]'), '')}',
                  ),
                ),
              if (e.phone case final t?)
                link(
                  Icons.call_outlined,
                  t,
                  Uri.parse('tel:${t.replaceAll(' ', '')}'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VolunteerCard extends StatelessWidget {
  const _VolunteerCard({required this.mine, required this.onTap});
  final Volunteer? mine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final offered = mine?.open ?? false;
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Text(
              offered
                  ? 'You offered to be CR. The department president will '
                      'be in touch.'
                  : 'No CR yet.',
              style: TypeScale.caption.copyWith(color: p.textMuted),
            ),
          ),
          TextButton(
            onPressed: onTap,
            child: Text(offered ? 'Withdraw' : 'Volunteer'),
          ),
        ],
      ),
    );
  }
}
