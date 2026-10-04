import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/routes.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/resources/resource.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/features/contribute/add_page.dart';
import 'package:cgpa_calculator/features/contribute/apply_page.dart';
import 'package:cgpa_calculator/features/contribute/contribute_data.dart';
import 'package:cgpa_calculator/features/contribute/edit_page.dart';
import 'package:cgpa_calculator/features/contribute/leaderboard_page.dart';
import 'package:cgpa_calculator/features/contribute/pending_page.dart';
import 'package:cgpa_calculator/features/resources/resources_page.dart';
import 'package:cgpa_calculator/features/setup/campus_pick_page.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/circle_icon_button.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:cgpa_calculator/shared/widgets/sliver_row_group.dart';
import 'package:flutter/material.dart';

String mineKey(String campus) => 'rmine-ui|$campus|${roleStore?.me}';

/// My links, shown when no filter is on or `f` matches.
enum ContribFilter { all, awaiting, approved, rejected }

bool _matches(ContribFilter f, LinkState s) => switch (f) {
  ContribFilter.all => true,
  ContribFilter.awaiting => s == LinkState.awaiting || s == LinkState.expired,
  ContribFilter.approved => s == LinkState.approved,
  ContribFilter.rejected => s == LinkState.rejected,
};

/// Board `Contribute`: my links with their state, and Add links. Staff
/// publish at once, so they get the button and no states.
class ContributePage extends StatefulWidget {
  const ContributePage({super.key});

  @override
  State<ContributePage> createState() => _ContributePageState();
}

class _ContributePageState extends State<ContributePage> {
  var _filter = ContribFilter.all;

  Future<void> _add(VoidCallback reload) async {
    await openRoute(context, Routes.contributeAdd, () => const AddPage());
    reload();
  }

  PageHeader _header([VoidCallback? reload, bool add = true]) => PageHeader(
    eyebrow: 'CONTRIBUTE',
    title: 'Your links',
    actions: [
      if (add)
        CircleIconButton(
        icon: Icons.add_rounded,
        tooltip: 'Add a link',
        size: 44,
        onPressed: () => _add(reload ?? () {}),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final campus = viewCampus();
    final store = resourceStore;
    if (store == null || campus == null) {
      return PageFrame(
        header: _header(),
        children: [
          if (store == null)
            const Note('Sign in with your BITS account to contribute.')
          else
            campusPrompt(context),
        ],
      );
    }
    final direct = contributesDirectly;
    if (!direct) {
      return Loaded<MyContrib>(
        cacheKey: 'contrib-me|$campus|${roleStore!.me}',
        load: loadMyContrib,
        peek: peekMyContrib,
        builder: (context, mine, _) {
          return switch (contribStateOf(mine)) {
            ContribState.approved => _links(campus, mine, direct),
            ContribState.applied => const PendingPage(),
            _ => const ApplyPage(),
          };
        },
      );
    }
    return _links(campus, null, direct);
  }

  Widget _links(String campus, MyContrib? mine, bool direct) {
    final p = AppPalette.of(context);
    final store = resourceStore!;
    return Loaded<List<Resource>>(
      cacheKey: mineKey(campus),
      load: () => store.mine(campus),
      peek: () => store.peekMine(campus),
      builder: (context, all, reload) {
        final now = DateTime.now();
        final rows = [
          for (final r in all)
            if (linkStateOf(r, now) case final s?)
              if (direct || _matches(_filter, s)) (r, s),
        ];
        // Nothing added yet: the board shows the card and its button only.
        final first = !direct && all.isEmpty;
        return PageFrame(
          header: _header(reload, !first),
          children: [
            if (first) ...[
              _PointsCard(mine?.me.username, mine?.me.points ?? 0, campus),
              const SizedBox(height: Space.sm),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add your first link',
                      style: TypeScale.body.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: p.text,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Links go live at once. After an approver confirms one, '
                      'you get 4 points. Ranked across the whole campus.',
                      style: TypeScale.caption.copyWith(
                        fontSize: 10.5,
                        height: 1.45,
                        color: p.textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    PrimaryButton(
                      label: 'Add a link',
                      onPressed: () => _add(reload),
                    ),
                  ],
                ),
              ),
            ] else ...[
            if (!direct) ...[
              _PointsCard(mine?.me.username, mine?.me.points ?? 0, campus),
              const SizedBox(height: Space.sm),
              ChoicePills<ContribFilter>(
                small: true,
                values: ContribFilter.values,
                selected: _filter,
                label:
                    (f) => switch (f) {
                      ContribFilter.all => 'All',
                      ContribFilter.awaiting => 'Waiting',
                      ContribFilter.approved => 'Approved',
                      ContribFilter.rejected => 'Rejected',
                    },
                onSelected: (f) => setState(() => _filter = f),
              ),
              const SizedBox(height: Space.sm),
            ],
            if (rows.isEmpty)
              Note(
                all.isEmpty || direct
                    ? 'No links yet'
                    : 'No ${_filter.name} links.',
              )
            else
              SliverRowGroup(
                count: rows.length,
                radius: 20,
                row: (context, i) {
                  final (r, s) = rows[i];
                  return _MyLink(r, s, direct: direct, onChanged: reload);
                },
              ),
            Note(
              direct
                  ? 'Staff links publish at once, so there are no Waiting or '
                      'Rejected rows and no points.'
                  : 'Points only count after approval. Removing a published '
                      'link never takes points back.',
            ),
            ],
          ],
        );
      },
    );
  }
}

/// The mint card on top: my points, my place and my username.
class _PointsCard extends StatelessWidget {
  const _PointsCard(this.username, this.points, this.campus);
  final String? username;
  final int points;
  final String campus;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final lead = peekLeader(campus);
    final rank = lead == null ? null : rankOf(lead);
    final note = [
      if (rank != null) 'Rank $rank of ${lead!.board.length} on campus',
      if (username != null) username!,
      if (rank == null && (points == 0 || lead != null)) 'not ranked yet',
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: p.hero,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 44,
            child: Icon(Icons.emoji_events_outlined, size: 20, color: p.onHero),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$points points',
                  style: TypeScale.title.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: p.onHero,
                  ),
                ),
                if (note.isNotEmpty)
                  Text(
                    note,
                    style: TypeScale.caption.copyWith(color: p.onHeroMuted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MyLink extends StatelessWidget {
  const _MyLink(this.r, this.state, {required this.direct, this.onChanged});
  final Resource r;
  final LinkState state;
  final bool direct;
  final VoidCallback? onChanged;

  String get _extra {
    switch (state) {
      case LinkState.awaiting:
        final start = r.publishedAt ?? r.addedAt;
        final used = DateTime.now().millisecondsSinceEpoch - start;
        final left = ((contributorWindow.inMilliseconds - used) /
                Duration.millisecondsPerDay)
            .ceil()
            .clamp(1, 15);
        return '$left ${left == 1 ? 'day' : 'days'} left to be approved. '
            '+4 after approval.';
      case LinkState.rejected:
        final why = r.rejectedReason.trim().replaceFirst(RegExp(r'\.$'), '');
        return 'Reason: $why.';
      case LinkState.expired:
        return 'Not approved within 15 days. Hidden from everyone.';
      case LinkState.approved:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final scope =
        r.isCourse
            ? ((r.fromCourse ?? '').isEmpty ? 'Course' : 'Course ${r.fromCourse}')
            : 'Department: ${r.department}';
    final day = shortDay(DateTime.fromMillisecondsSinceEpoch(r.addedAt));
    final extra = direct ? '' : _extra;
    final tone = switch (state) {
      LinkState.approved => GradeTone(p.hero, p.onHero),
      LinkState.awaiting => p.waitingTone,
      LinkState.rejected => p.rejectedTone,
      LinkState.expired => GradeTone(p.chipFill, p.icon),
    };
    final extraColor =
        state == LinkState.rejected ? p.rejectedTone.text : p.textMuted;
    return Semantics(
      button: true,
      label: '${r.title}, $scope, ${state.name}',
      excludeSemantics: true,
      child: Opacity(
        opacity: state == LinkState.expired ? .6 : 1,
        child: InkWell(
          // A removed (rejected) link is not edited: the rules refuse it.
          onTap:
              r.removed
                  ? null
                  : () async {
                    await openRoute(
                      context,
                      Routes.contributeEdit(r.id),
                      () => EditPage(id: r.id),
                    );
                    onChanged?.call();
                  },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TypeScale.body.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: p.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$scope · ${direct ? 'published' : 'added'} $day',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TypeScale.caption.copyWith(
                              fontSize: 10.5,
                              color: p.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!direct) ...[
                      const SizedBox(width: 8),
                      Container(
                        height: 20,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: tone.fill,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          switch (state) {
                            LinkState.awaiting => 'WAITING',
                            LinkState.approved => 'APPROVED',
                            LinkState.rejected => 'REJECTED',
                            LinkState.expired => 'HIDDEN',
                          },
                          style: TypeScale.label.copyWith(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .3,
                            color: tone.text,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (extra.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    extra,
                    style: TypeScale.caption.copyWith(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: extraColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
