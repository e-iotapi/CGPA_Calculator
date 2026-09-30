import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/routes.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/models/programmes.dart';
import 'package:cgpa_calculator/core/resources/resource.dart';
import 'package:cgpa_calculator/core/resources/resource_store.dart';
import 'package:cgpa_calculator/core/roles/capabilities.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/core/storage/courses.dart';
import 'package:cgpa_calculator/features/marks/official.dart';
import 'package:cgpa_calculator/script.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/bottom_action.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:cgpa_calculator/shared/widgets/pill_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cgpa_calculator/core/platform/browser.dart';

ResourceStore? get resourceStore => switch (roleStore) {
  final r? => ResourceStore(r, uid: myUid),
  null => null,
};

/// The programme codes in [discipline] ("B3A7" → B3, A7; "--" is none).
List<String> programmesOf(String discipline) => [
  for (var i = 0; i + 2 <= discipline.length; i += 2)
    if (discipline.substring(i, i + 2) != '--') discipline.substring(i, i + 2),
];

/// Courses the student is taking now: in progress or cleared without a
/// grade, and charted for this term (not a past or future semester's course
/// carrying the same status).
Set<String> takingNow() {
  final term = currentTerm(DateTime.now());
  return {
    for (final c in allCourses())
      if ((c.grade1 == GradeCode.ongoing || c.grade1 == GradeCode.clr) &&
          termFor(c) == term)
        c.id,
  };
}

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
      onTap: onTap ?? () => openUrl(r.url),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: EdgeInsets.only(left: 15, right: onReport == null ? 15 : 4),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: p.surfaceSunken,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  switch (r.kind) {
                    'video' => Icons.play_circle_outline_rounded,
                    'doc' => Icons.description_outlined,
                    'folder' => Icons.folder_outlined,
                    _ => Icons.link_rounded,
                  },
                  size: 15,
                  color: p.icon,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              r.title,
                              style: TypeScale.body.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (tag != null) ...[
                            const SizedBox(width: 6),
                            _InkTag(tag!),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${r.host}${showAdder ? by : ''}',
                        style: TypeScale.caption.copyWith(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                          color: p.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (trailing != null) trailing!,
              if (onReport != null)
                SizedBox.square(
                  dimension: 44,
                  child: IconButton(
                    tooltip: 'More options for this link',
                    icon: Icon(Icons.more_horiz, size: 18, color: p.textMuted),
                    onPressed: onReport,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An 18 px ink tag with mint text: "FROM CS F301", or a course code.
class _InkTag extends StatelessWidget {
  const _InkTag(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: p.inverse,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          text,
          // Mint on ink reads in light; dark's ink is pale, so its own text.
          style: TypeScale.label.copyWith(
            fontSize: 8.5,
            color: p.isDark ? p.onInverse : p.hero,
          ),
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
    // Scrolls, so 2x text on a small phone never overflows (N37).
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 40,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: p.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 11),
          Text(
            'Report this link',
            style: TypeScale.title.copyWith(
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${r.title} · ${r.host}'
            '${r.addedByName.isEmpty ? '' : ' · added by ${r.addedByName}'}',
            style: TypeScale.caption.copyWith(
              fontSize: 11.5,
              height: 1.45,
              color: p.textMuted,
            ),
          ),
          const SizedBox(height: 11),
          for (final reason in ReportReason.values) ...[
            _ReasonButton(
              label: reason.label,
              on: _reason == reason,
              onTap: () => setState(() => _reason = reason),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 3),
          AppTextField(
            controller: _note,
            label: 'Add a note (optional)',
            dense: true,
          ),
          if (_error != null)
            Text(_error!, style: TypeScale.caption.copyWith(color: p.behind)),
          const SizedBox(height: 11),
          PrimaryButton(
            label: _busy ? 'Sending…' : 'Send report',
            onPressed: _reason == null || _busy ? null : _send,
          ),
          const SizedBox(height: 11),
          Text(
            'Goes to the owners and your department president. The link '
            'stays up until one of them acts.',
            style: TypeScale.caption.copyWith(height: 1.45, color: p.textMuted),
          ),
        ],
      ),
    );
  }
}

/// A 44 tall, radius 14, left-aligned reason with a radio dot; ink when on.
class _ReasonButton extends StatelessWidget {
  const _ReasonButton({
    required this.label,
    required this.on,
    required this.onTap,
  });
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final fg = on ? p.onInverse : p.text;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: on,
      child: Material(
        color: on ? p.inverse : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: on ? BorderSide.none : BorderSide(color: p.outline),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    on
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 16,
                    color: on ? p.hero : p.textMuted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: TypeScale.body.copyWith(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: fg,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          radius: 22,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: p.surfaceSunken,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(Icons.folder_outlined, size: 24, color: p.icon),
              ),
              const SizedBox(height: 12),
              Text(
                'No resources here yet',
                textAlign: TextAlign.center,
                style: TypeScale.body.copyWith(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Ask your CR or department president to add some — they can '
                'post Drive links, notes, past papers and lecture videos for '
                'the whole department.',
                textAlign: TextAlign.center,
                style: TypeScale.body.copyWith(
                  fontSize: 12,
                  height: 1.5,
                  color: p.textMuted,
                ),
              ),
              if (onRepresentatives != null) ...[
                const SizedBox(height: 12),
                Material(
                  color: p.inverse,
                  shape: const StadiumBorder(),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: onRepresentatives,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 42),
                      child: Center(
                        widthFactor: 1,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 8,
                          ),
                          child: Text(
                            'Find your representatives',
                            textAlign: TextAlign.center,
                            style: TypeScale.body.copyWith(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: p.onInverse,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
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
            final tone = p.noticeTone;
            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: tone.fill,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ARE YOU THE DEPARTMENT PRESIDENT?',
                          style: TypeScale.label.copyWith(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: tone.text,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'You can post resources for your whole department '
                          'once you have access. Get in touch and it takes a '
                          'minute to set up.',
                          style: TypeScale.body.copyWith(
                            fontSize: 12,
                            height: 1.45,
                            color: tone.text,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _ContactRow(
                          name: c.name,
                          how: switch (c.method) {
                            'phone' => 'By phone',
                            'email' => 'By email',
                            _ => 'On WhatsApp',
                          },
                          onTap: () => openUrl('$uri'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This block shows only while the owners keep a public '
                    'contact switched on.',
                    style: caption,
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// The ink row in the public contact block: a mint disc, then "Message"
/// and the name over how. The number itself is never drawn.
class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.name,
    required this.how,
    required this.onTap,
  });
  final String name, how;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Material(
      color: p.inverse,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: p.hero,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 14,
                    color: p.onHero,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Message $name',
                        style: TypeScale.body.copyWith(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: p.onInverse,
                        ),
                      ),
                      Text(
                        how,
                        style: TypeScale.caption.copyWith(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                          color: p.onInverse.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
      builder: (context, degrees, reload) {
        final keep = [
          for (final d in degrees)
            if (campus != null &&
                myRoles.value.may(
                  Capability.departmentResources,
                  campus: campus,
                  scope: d.dept,
                ))
              d.dept,
        ];
        return PageFrame(
          header: PageHeader(
            eyebrow: resourcesEyebrow(campus, dual: dual),
            title: 'Resources',
          ),
          bottom:
              keep.isEmpty
                  ? null
                  : BottomAction(
                    child: PrimaryButton(
                      label: 'Add a link',
                      icon: Icons.add_rounded,
                      onPressed:
                          () => GoRouter.maybeOf(
                            context,
                          )?.push(Routes.deptResources(campus!, keep.first)),
                    ),
                  ),
          children: [
            if (roleStore == null)
              const Note('Sign in with your BITS account to see resources.'),
            for (final (i, d) in degrees.indexed) ...[
              if (i > 0) const SizedBox(height: 11),
              Row(
                children: [
                  _CodeTile(d.code, second: i > 0),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      programmeName(d.code),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TypeScale.body.copyWith(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              if (d.links.isEmpty)
                ResourcesEmpty(onRepresentatives: widget.onRepresentatives)
              else
                _degree(context, d, now, p),
            ],
            if (degrees.any((d) => d.links.any((r) => r.rolledUp))) ...[
              const SizedBox(height: 11),
              Text(
                'A course link tagged FROM is also listed under its '
                'department, so everyone in the degree finds it.',
                style: TypeScale.caption.copyWith(
                  height: 1.45,
                  color: p.textMuted,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _degree(
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
    final label = TypeScale.label.copyWith(color: p.textMuted);
    Widget rows(List<Resource> links, String? Function(Resource) tag) => Column(
      children: [
        for (final (i, r) in links.indexed) ...[
          if (i > 0) Divider(height: 1, indent: 15, color: p.divider),
          LinkRow(r: r, tag: tag(r), onReport: () => reportLink(context, r)),
        ],
      ],
    );
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 10, 15, 6),
            child: Text('DEPARTMENT · ${dept.length}', style: label),
          ),
          if (dept.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 0, 15, 12),
              child: Text(
                'No department links yet.',
                style: TypeScale.caption.copyWith(color: p.textMuted),
              ),
            )
          else
            rows(dept, (r) => r.rolledUp ? 'FROM ${r.fromCourse}' : null),
          Divider(height: 1, color: p.divider),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 10, 15, 6),
            child: Row(
              children: [
                Expanded(child: Text('COURSES', style: label)),
                for (final v in const [false, true]) ...[
                  if (v) const SizedBox(width: 6),
                  PillButton(
                    label: v ? 'All' : 'This semester',
                    height: 24,
                    padding: 10,
                    selected: all == v,
                    onPressed:
                        () => setState(
                          () => v ? _all.add(d.code) : _all.remove(d.code),
                        ),
                  ),
                ],
              ],
            ),
          ),
          if (courseLinks.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 4, 15, 14),
              child: Text(
                all
                    ? 'No course links yet.'
                    : 'Nothing for your courses this semester. Tap All for '
                        'every course.',
                style: TypeScale.caption.copyWith(color: p.textMuted),
              ),
            )
          else
            rows(
              courseLinks,
              (r) => r.courseIds.firstWhere(
                now.contains,
                orElse: () => r.courseIds.first,
              ),
            ),
        ],
      ),
    );
  }
}

/// "GOA · DUAL DEGREE" from the parts that are known: never a stray
/// separator when the campus is not (§8.11 fix 1).
String resourcesEyebrow(String? campus, {required bool dual}) => [
  if (campus != null) campusName(campus).toUpperCase(),
  if (dual) 'DUAL DEGREE',
].join(' · ');

/// A 30 × 24 code tile: the first degree mint, the second ink with mint text.
class _CodeTile extends StatelessWidget {
  const _CodeTile(this.code, {this.second = false});
  final String code;
  final bool second;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 30, minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: second ? p.inverse : p.hero,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: Text(
          code,
          style: TypeScale.label.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: second ? (p.isDark ? p.onInverse : p.hero) : p.onHero,
          ),
        ),
      ),
    );
  }
}
