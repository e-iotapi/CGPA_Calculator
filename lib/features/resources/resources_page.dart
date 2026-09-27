import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/models/programmes.dart';
import 'package:cgpa_calculator/core/resources/resource.dart';
import 'package:cgpa_calculator/core/resources/resource_store.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/core/storage/courses.dart';
import 'package:cgpa_calculator/script.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

ResourceStore? get resourceStore => switch (roleStore) {
  final r? => ResourceStore(r, uid: myUid),
  null => null,
};

/// The programme codes in [discipline] ("B3A7" → B3, A7; "--" is none).
List<String> programmesOf(String discipline) => [
  for (var i = 0; i + 2 <= discipline.length; i += 2)
    if (discipline.substring(i, i + 2) != '--') discipline.substring(i, i + 2),
];

/// Courses the student is taking now.
Set<String> takingNow() => {
  for (final c in allCourses())
    if (c.grade1 == GradeCode.ongoing || c.grade1 == GradeCode.clr) c.id,
};

/// One link: title, host and who added it; opens in the browser. [onReport]
/// adds the Report this link path (§6).
class LinkRow extends StatelessWidget {
  const LinkRow({
    super.key,
    required this.r,
    this.onReport,
    this.tag,
    this.trailing,
    this.onTap,
    this.showAdder = true,
  });

  final Resource r;
  final VoidCallback? onReport;
  final String? tag;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showAdder;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final by = r.addedByName.isEmpty ? '' : ' · added by ${r.addedByName}';
    return InkWell(
      onTap:
          onTap ??
          () =>
              launchUrl(Uri.parse(r.url), mode: LaunchMode.externalApplication),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        child: Row(
          children: [
            Icon(
              switch (r.kind) {
                'video' => Icons.play_circle_outline_rounded,
                'doc' => Icons.description_outlined,
                'folder' => Icons.folder_outlined,
                _ => Icons.link_rounded,
              },
              size: 20,
              color: p.icon,
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          r.title,
                          style: TypeScale.body.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (tag != null) ...[
                        const SizedBox(width: Space.xs),
                        TierTag(tag!),
                      ],
                    ],
                  ),
                  Text(
                    '${r.host}${showAdder ? by : ''}',
                    style: TypeScale.caption.copyWith(color: p.textMuted),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
            if (onReport != null)
              IconButton(
                tooltip: 'Report this link',
                icon: Icon(Icons.flag_outlined, size: 18, color: p.textMuted),
                onPressed: onReport,
              ),
          ],
        ),
      ),
    );
  }
}

/// Board `ReportLink`: why, an optional note, send. Goes to the owners and
/// the department's president; the link stays up until one of them acts.
Future<void> reportLink(BuildContext context, Resource r) async {
  final store = resourceStore;
  if (store == null) return;
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ReportSheet(r: r, store: store),
  );
  if (sent == null || !context.mounted) return;
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(
          sent
              ? 'Reported. Thank you.'
              : 'You have already reported this link.',
        ),
      ),
    );
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.r, required this.store});
  final Resource r;
  final ResourceStore store;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  ReportReason? _reason;
  final _note = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    try {
      final ok = await widget.store.report(
        widget.r,
        _reason!,
        note: _note.text,
      );
      if (mounted) Navigator.of(context).pop(ok);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = problem(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final r = widget.r;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Space.gutter,
        Space.lg,
        Space.gutter,
        MediaQuery.viewInsetsOf(context).bottom + Space.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Report this link', style: TypeScale.title),
          Text(
            '${r.title} · ${r.host}'
            '${r.addedByName.isEmpty ? '' : ' · added by ${r.addedByName}'}',
            style: TypeScale.caption.copyWith(color: p.textMuted),
          ),
          const SizedBox(height: Space.md),
          for (final reason in ReportReason.values)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                _reason == reason
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: _reason == reason ? p.accent : p.textMuted,
              ),
              title: Text(reason.label),
              onTap: () => setState(() => _reason = reason),
            ),
          AppTextField(
            controller: _note,
            label: 'Add a note (optional)',
            dense: true,
          ),
          if (_error != null)
            Text(_error!, style: TypeScale.caption.copyWith(color: p.behind)),
          const SizedBox(height: Space.md),
          PrimaryButton(
            label: _busy ? 'Sending…' : 'Send report',
            onPressed: _reason == null || _busy ? null : _send,
          ),
          const SizedBox(height: Space.sm),
          Text(
            'Goes to the owners and your department president. The link '
            'stays up until one of them acts.',
            style: TypeScale.caption.copyWith(color: p.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Board `ResourcesEmpty` (§10.5): who can fix an empty department, with the
/// public contact when it is switched on.
class ResourcesEmpty extends StatelessWidget {
  const ResourcesEmpty({super.key, this.onRepresentatives});
  final VoidCallback? onRepresentatives;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final caption = TypeScale.caption.copyWith(
      height: 1.45,
      color: p.textMuted,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No resources here yet',
                style: TypeScale.body.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                'Ask your CR or department president to add some — they can '
                'post Drive links, notes, past papers and lecture videos for '
                'the whole department.',
                style: caption,
              ),
              if (onRepresentatives != null)
                TextButton(
                  onPressed: onRepresentatives,
                  child: const Text('Find your representatives'),
                ),
            ],
          ),
        ),
        FutureBuilder<PublicContact?>(
          future: roleStore?.publicContact().catchError((_) => null),
          builder: (context, s) {
            final c = s.data;
            if (c == null || !c.enabled || c.target.isEmpty) {
              return const SizedBox.shrink();
            }
            final uri = switch (c.method) {
              'phone' => Uri.parse('tel:${c.target}'),
              'email' => Uri.parse('mailto:${c.target}'),
              _ => Uri.parse(
                'https://wa.me/${c.target.replaceAll(RegExp(r'[^0-9]'), '')}',
              ),
            };
            return Padding(
              padding: const EdgeInsets.only(top: Space.sm),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ARE YOU THE DEPARTMENT PRESIDENT?',
                      style: TypeScale.label.copyWith(color: p.textMuted),
                    ),
                    const SizedBox(height: Space.xs),
                    Text(
                      'You can post resources for your whole department once '
                      'you have access. Get in touch and it takes a minute to '
                      'set up.',
                      style: caption,
                    ),
                    const SizedBox(height: Space.sm),
                    PrimaryButton(
                      label: 'Message ${c.name}',
                      icon: Icons.chat_bubble_outline_rounded,
                      onPressed:
                          () => launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Board `Resources` (§10.4): by degree, then department and course links;
/// courses default to this semester, All is one tap.
class ResourcesPage extends StatefulWidget {
  const ResourcesPage({super.key, this.onRepresentatives});
  final VoidCallback? onRepresentatives;

  @override
  State<ResourcesPage> createState() => _ResourcesPageState();
}

typedef _Degree = ({String code, String dept, List<Resource> links});

class _ResourcesPageState extends State<ResourcesPage> {
  final _all = <String>{};

  Future<List<_Degree>> _load() async {
    final store = resourceStore;
    final campus = campusOfAddress(roleStore?.me ?? '');
    if (store == null || campus == null) return const [];
    final codes = programmesOf(selecteddiscipline);
    return [
      for (final code in codes)
        if (departmentOfProgramme(code) case final dept?)
          (code: code, dept: dept, links: await store.department(campus, dept)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final campus = campusOfAddress(roleStore?.me ?? '');
    final dual = programmesOf(selecteddiscipline).length > 1;
    final now = takingNow();
    return Loaded<List<_Degree>>(
      load: _load,
      builder:
          (context, degrees, reload) => PageFrame(
            header: PageHeader(
              eyebrow:
                  '${campus == null ? '' : campusName(campus).toUpperCase()}'
                  '${dual ? ' · DUAL DEGREE' : ''}',
              title: 'Resources',
            ),
            children: [
              if (roleStore == null)
                const Note('Sign in with your BITS account to see resources.'),
              for (final d in degrees) ...[
                const SizedBox(height: Space.sm),
                Row(
                  children: [
                    TierTag(d.code, strong: true),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Text(
                        programmeName(d.code),
                        style: TypeScale.body.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (d.links.isEmpty) ...[
                  const SizedBox(height: Space.sm),
                  ResourcesEmpty(onRepresentatives: widget.onRepresentatives),
                ] else
                  ..._degree(context, d, now, p),
              ],
            ],
          ),
    );
  }

  List<Widget> _degree(
    BuildContext context,
    _Degree d,
    Set<String> now,
    AppPalette p,
  ) {
    final dept = departmentList(d.links);
    final all = _all.contains(d.code);
    final courseLinks = [
      for (final r in d.links)
        if (!r.removed &&
            r.courseIds.isNotEmpty &&
            (all || r.courseIds.any(now.contains)))
          r,
    ]..sort((a, b) => a.courseIds.first.compareTo(b.courseIds.first));
    return [
      SectionLabel('Department · ${dept.length}'),
      RowGroup(
        children: [
          for (final r in dept)
            LinkRow(
              r: r,
              tag: r.rolledUp ? 'FROM ${r.fromCourse}' : null,
              onReport: () => reportLink(context, r),
            ),
        ],
      ),
      Row(
        children: [
          const Expanded(child: SectionLabel('Courses')),
          ChoicePills<bool>(
            values: const [false, true],
            selected: all,
            label: (v) => v ? 'All' : 'This semester',
            onSelected:
                (v) =>
                    setState(() => v ? _all.add(d.code) : _all.remove(d.code)),
          ),
        ],
      ),
      if (courseLinks.isEmpty)
        Note(
          all
              ? 'No course links yet.'
              : 'Nothing for your courses this semester. Tap All for every '
                  'course.',
        )
      else
        RowGroup(
          children: [
            for (final r in courseLinks)
              LinkRow(
                r: r,
                tag: r.courseIds.firstWhere(
                  now.contains,
                  orElse: () => r.courseIds.first,
                ),
                onReport: () => reportLink(context, r),
              ),
          ],
        ),
    ];
  }
}
