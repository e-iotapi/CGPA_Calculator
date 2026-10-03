import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/routes.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/contrib/leaderboard_store.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/features/contribute/contribute_data.dart';
import 'package:cgpa_calculator/features/setup/campus_pick_page.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:cgpa_calculator/shared/widgets/sliver_row_group.dart';
import 'package:flutter/material.dart';

/// The campus board and my username on it (null when I have none).
typedef LeaderData = ({List<LeaderEntry> board, String? mine});

String leaderKey(String campus) => 'lb-ui|$campus';

Future<LeaderData> loadLeader(String campus) async {
  final board = await leaderboardStore!.of(campus);
  final me = await contributorStore!.me(campus);
  return (board: board, mine: me.username);
}

/// [loadLeader] from the saved copies; null when the board is not saved.
LeaderData? peekLeader(String campus) {
  final board = leaderboardStore?.peek(campus);
  if (board == null) return null;
  final s = contributorStore!;
  return (board: board, mine: s.peekMe(s.roles.me)?.username);
}

/// My place on [d], 1-based, or null when I am not on the board.
int? rankOf(LeaderData d) {
  final i = d.board.indexWhere((e) => e.username == d.mine);
  return d.mine == null || i < 0 ? null : i + 1;
}

/// One board row: rank, username (with the branch for staff views), points.
class LeaderRow extends StatelessWidget {
  const LeaderRow({
    super.key,
    required this.rank,
    required this.entry,
    this.me = false,
  });
  final int rank;
  final LeaderEntry entry;
  final bool me;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Semantics(
      label:
          'Number $rank, ${entry.username}${me ? ', you' : ''}, '
          '${entry.points} points',
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: Sizes.minTouch),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: 30,
                child: Text(
                  '$rank',
                  style: TypeScale.body.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: p.textMuted,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  me ? '${entry.username} (you)' : entry.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TypeScale.body.copyWith(
                    fontSize: 13,
                    fontWeight: me ? FontWeight.w800 : FontWeight.w600,
                    color: p.text,
                  ),
                ),
              ),
              if (entry.tag != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    entry.tag!,
                    style: TypeScale.caption.copyWith(color: p.textMuted),
                  ),
                ),
              Text(
                '${entry.points}',
                style: TypeScale.body.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
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

/// Board `Leaderboard`: everyone with points on the campus, highest first.
class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final campus = viewCampus();
    final header = PageHeader(
      eyebrow: campus == null ? 'More' : campusName(campus).toUpperCase(),
      title: 'Contributor Leaderboard',
    );
    if (roleStore == null || campus == null) {
      return PageFrame(
        header: header,
        children: [
          if (roleStore == null)
            const Note('Sign in with your BITS account to see the board.')
          else
            campusPrompt(context),
        ],
      );
    }
    return Loaded<LeaderData>(
      cacheKey: leaderKey(campus),
      load: () => loadLeader(campus),
      peek: () => peekLeader(campus),
      builder: (context, d, _) {
        final rank = rankOf(d);
        return PageFrame(
          header: header,
          children: [
            Note(
              rank == null
                  ? 'Four points for every approved link. Add links to join '
                      'the board.'
                  : 'You are number $rank of ${d.board.length}.',
            ),
            const SizedBox(height: Space.sm),
            if (d.board.isEmpty)
              const Note('No contributors yet')
            else
              SliverRowGroup(
                count: d.board.length,
                row:
                    (_, i) => LeaderRow(
                      rank: i + 1,
                      entry: d.board[i],
                      me: d.board[i].username == d.mine,
                    ),
              ),
          ],
        );
      },
    );
  }
}

/// More's bigger card: the top five and where I stand.
class LeaderboardCard extends StatelessWidget {
  const LeaderboardCard({super.key});

  @override
  Widget build(BuildContext context) {
    final campus = viewCampus();
    if (roleStore == null || campus == null) return const SizedBox.shrink();
    final p = AppPalette.of(context);
    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(Radii.row),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap:
            () => openRoute(
              context,
              Routes.leaderboard,
              () => const LeaderboardPage(),
            ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Loaded<LeaderData>(
            cacheKey: leaderKey(campus),
            load: () => loadLeader(campus),
            peek: () => peekLeader(campus),
            builder: (context, d, _) {
              final rank = rankOf(d);
              final mine =
                  rank == null
                      ? null
                      : d.board.firstWhere((e) => e.username == d.mine);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(Icons.emoji_events_outlined, color: p.icon),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Contributor Leaderboard',
                            style: TypeScale.body.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: p.text,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: p.textMuted),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (d.board.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Text(
                        'No contributors yet',
                        style: TypeScale.caption.copyWith(color: p.textMuted),
                      ),
                    )
                  else
                    for (final (i, e) in d.board.take(5).indexed)
                      LeaderRow(
                        rank: i + 1,
                        entry: e,
                        me: e.username == d.mine,
                      ),
                  if (mine != null && rank! > 5) ...[
                    Divider(height: 1, indent: 15, endIndent: 15, color: p.divider),
                    LeaderRow(rank: rank, entry: mine, me: true),
                  ] else if (mine == null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                      child: Text(
                        'You are not on the board yet',
                        style: TypeScale.caption.copyWith(color: p.textMuted),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
