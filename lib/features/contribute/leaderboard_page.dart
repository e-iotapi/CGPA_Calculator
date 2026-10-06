import 'dart:math' as math;

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

/// 1st, 2nd, 3rd, 4th ... 11th, 12th, 13th, 21st.
String ordinal(int n) {
  final teen = n % 100 >= 11 && n % 100 <= 13;
  return '$n${teen ? 'th' : const ['th', 'st', 'nd', 'rd'][n % 10 < 4 ? n % 10 : 0]}';
}

String _pts(LeaderEntry e) => '${e.points} pts';

String _label(int rank, LeaderEntry e, bool me) =>
    'Number $rank, ${e.username}${me ? ', you' : ''}, ${e.points} points';

/// A four-point star, as the boards draw on the top places.
class _Star extends CustomPainter {
  const _Star(this.opacity);
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    final path =
        Path()
          ..moveTo(12 * k, k)
          ..lineTo(14.2 * k, 9.8 * k)
          ..lineTo(23 * k, 12 * k)
          ..lineTo(14.2 * k, 14.2 * k)
          ..lineTo(12 * k, 23 * k)
          ..lineTo(9.8 * k, 14.2 * k)
          ..lineTo(k, 12 * k)
          ..lineTo(9.8 * k, 9.8 * k)
          ..close();
    canvas.drawPath(
      path,
      Paint()..color = Colors.white.withValues(alpha: opacity),
    );
  }

  @override
  bool shouldRepaint(_Star old) => old.opacity != opacity;
}

// (left, top, size, opacity) of each place's stars, from the board.
const _sparkles = [
  [(250.0, 8.0, 12.0, .9), (214.0, 50.0, 9.0, .7), (300.0, 44.0, 14.0, .85)],
  [(250.0, 8.0, 12.0, .9), (214.0, 44.0, 9.0, .7), (300.0, 38.0, 14.0, .85)],
  [(250.0, 8.0, 12.0, .9), (214.0, 44.0, 9.0, .7), (300.0, 38.0, 14.0, .85)],
  [(262.0, 8.0, 10.0, .9), (300.0, 36.0, 9.0, .8)],
  [(262.0, 8.0, 10.0, .9), (300.0, 36.0, 9.0, .8)],
];

/// A top-five row of the leaderboard page: the medal's gradient and stars.
class MedalRow extends StatelessWidget {
  const MedalRow({
    super.key,
    required this.place,
    required this.entry,
    this.me = false,
  });

  /// 0 for first.
  final int place;
  final LeaderEntry entry;
  final bool me;

  @override
  Widget build(BuildContext context) {
    final m = pageMedals[place];
    final ink = m.ink;
    final style = TypeScale.body.copyWith(
      color: ink,
      fontWeight: FontWeight.w800,
    );
    return Semantics(
      label: _label(place + 1, entry, me),
      excludeSemantics: true,
      child: Container(
        constraints: BoxConstraints(minHeight: place == 0 ? 70 : place < 3 ? 64 : 58),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: m.colors,
            stops: m.stops,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            for (final (l, t, size, o) in _sparkles[place])
              Positioned(
                left: l,
                top: t,
                child: CustomPaint(
                  size: Size.square(size),
                  painter: _Star(o),
                ),
              ),
            Row(
              children: [
                Container(
                  constraints: const BoxConstraints(minWidth: 42),
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .62),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    ordinal(place + 1),
                    style: style.copyWith(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    me ? '${entry.username} (you)' : entry.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: style.copyWith(fontSize: place == 0 ? 15 : 13.5),
                  ),
                ),
                if (entry.tag != null) ...[
                  const SizedBox(width: 11),
                  _Tag(
                    entry.tag!,
                    fill: ink.withValues(alpha: .13),
                    ink: ink,
                  ),
                ],
                const SizedBox(width: 11),
                SizedBox(
                  width: 48,
                  child: Text(
                    _pts(entry),
                    textAlign: TextAlign.right,
                    style: style.copyWith(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The branch beside a name.
class _Tag extends StatelessWidget {
  const _Tag(this.text, {required this.fill, required this.ink, this.small = false});
  final String text;
  final Color fill, ink;

  /// The More card's smaller chip.
  final bool small;

  @override
  Widget build(BuildContext context) => Container(
    height: small ? null : 20,
    padding: EdgeInsets.symmetric(horizontal: small ? 6 : 8, vertical: small ? 2 : 0),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: fill,
      borderRadius: BorderRadius.circular(small ? 8 : 10),
    ),
    child: Text(
      text,
      style: TypeScale.caption.copyWith(
        fontSize: small ? 9 : 9.5,
        fontWeight: FontWeight.w800,
        letterSpacing: small ? 0 : .3,
        color: ink,
      ),
    ),
  );
}

/// A row from 6th down on the leaderboard page; mine is filled.
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
    final ink = me ? p.onHero : p.text;
    final style = TypeScale.body.copyWith(fontSize: 13, color: ink);
    return Semantics(
      label: _label(rank, entry, me),
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 50),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
        decoration:
            me
                ? BoxDecoration(
                  color: p.hero,
                  borderRadius: BorderRadius.circular(20),
                )
                : null,
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Text(
                ordinal(rank),
                style: style.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            Expanded(
              child: Text(
                me ? '${entry.username} (you)' : entry.username,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (entry.tag != null) ...[
              const SizedBox(width: 10),
              _Tag(
                entry.tag!,
                fill: p.chipFill,
                ink: p.icon,
              ),
            ],
            const SizedBox(width: 10),
            SizedBox(
              width: 48,
              child: Text(
                _pts(entry),
                textAlign: TextAlign.right,
                style: style.copyWith(fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
          ],
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
    const header = PageHeader(eyebrow: 'CONTRIBUTE', title: 'Leaderboard');
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
    final p = AppPalette.of(context);
    return Loaded<LeaderData>(
      cacheKey: leaderKey(campus),
      load: () => loadLeader(campus),
      peek: () => peekLeader(campus),
      builder: (context, d, _) {
        if (d.board.isEmpty) {
          return PageFrame(
            header: header,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 31, horizontal: 15),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: p.hero,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        Icons.emoji_events_outlined,
                        size: 21,
                        color: p.onHero,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No one has points yet',
                      style: TypeScale.body.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: p.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Points start when an approver confirms a link. '
                      'Be the first on ${campusName(campus)}.',
                      textAlign: TextAlign.center,
                      style: TypeScale.caption.copyWith(
                        fontSize: 10.5,
                        height: 1.45,
                        color: p.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }
        final top = d.board.take(5).toList();
        return PageFrame(
          header: header,
          children: [
            Note(
              '${campusName(campus)} campus. Usernames only; admins, '
              'presidents and secretaries show their branch beside their name.',
            ),
            const SizedBox(height: Space.md),
            Column(
              spacing: 7,
              children: [
                for (final (i, e) in top.indexed)
                  MedalRow(place: i, entry: e, me: e.username == d.mine),
              ],
            ),
            if (d.board.length > 5) ...[
              const SizedBox(height: Space.md),
              SliverRowGroup(
                count: d.board.length - 5,
                radius: 20,
                row:
                    (_, i) => LeaderRow(
                      rank: i + 6,
                      entry: d.board[i + 5],
                      me: d.board[i + 5].username == d.mine,
                    ),
              ),
            ],
            const Note(
              '4 points for each approved link. Admins, presidents and '
              'secretaries show their branch beside the name.',
            ),
          ],
        );
      },
    );
  }
}

/// One compact row of More's card: a medal for the top five, mine in green.
class _CardRow extends StatelessWidget {
  const _CardRow({
    required this.rank,
    required this.entry,
    required this.me,
    required this.palette,
  });
  final int rank;
  final LeaderEntry entry;
  final bool me;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final medal = rank <= 5 ? cardMedals[rank - 1] : null;
    final ink = medal?.ink ?? palette.onHero;
    final style = TypeScale.body.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: ink,
    );
    return Semantics(
      label: _label(rank, entry, me),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: medal == null ? palette.hero : null,
          gradient:
              medal == null
                  ? null
                  : LinearGradient(colors: medal.colors, stops: medal.stops),
        ),
        child: _FlyingSparkles(seed: rank, color: ink, child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Text(
                ordinal(rank),
                style: style.copyWith(fontSize: 10.5, fontWeight: FontWeight.w800),
              ),
            ),
            Expanded(
              child: Text(
                me ? '${entry.username} (you)' : entry.username,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
            if (entry.tag != null) ...[
              const SizedBox(width: 8),
              _Tag(entry.tag!, fill: ink.withValues(alpha: .12), ink: ink, small: true),
            ],
            const SizedBox(width: 8),
            SizedBox(
              width: 58,
              child: Text(
                _pts(entry),
                textAlign: TextAlign.right,
                style: style.copyWith(fontSize: 11.5, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        )),
      ),
    );
  }
}

/// Off in widget tests (flutter_test_config.dart): an endless animation
/// never lets pumpAndSettle settle.
bool sparklesFly = true;

/// Small stars drifting behind a More card row's name and twinkling (owner,
/// 2026-10-06). Still under reduced motion.
class _FlyingSparkles extends StatefulWidget {
  const _FlyingSparkles({
    required this.seed,
    required this.color,
    required this.child,
  });
  final int seed;
  final Color color;
  final Widget child;

  @override
  State<_FlyingSparkles> createState() => _FlyingSparklesState();
}

class _FlyingSparklesState extends State<_FlyingSparkles>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (sparklesFly && !MediaQuery.disableAnimationsOf(context)) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: IgnorePointer(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _SparklePainter(_c, widget.seed, widget.color),
            ),
          ),
        ),
      ),
      widget.child,
    ],
  );
}

class _SparklePainter extends CustomPainter {
  _SparklePainter(this.t, this.seed, this.color) : super(repaint: t);
  final Animation<double> t;
  final int seed;
  final Color color;

  static const _count = 7;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < _count; i++) {
      // Fixed per star, varied by row: start, lane, speed, size, twinkle.
      final h = ((seed * 7 + i) * 2654435761) & 0xFFFF;
      final start = (h & 0xFF) / 255;
      final lane = ((h >> 8) & 0xF) / 15;
      final speed = 0.6 + ((h >> 12) & 0x3) * 0.25;
      final r = 1.6 + (i % 3) * 0.9;
      final phase = (start + t.value * speed) % 1;
      final x = phase * (size.width + 2 * r) - r;
      final y =
          r +
          lane * (size.height - 2 * r) +
          math.sin((phase + start) * 2 * math.pi) * 2;
      final glow = 0.5 + 0.5 * math.sin((t.value * 3 + start) * 2 * math.pi);
      _star(
        canvas,
        Offset(x, y),
        r,
        color.withValues(alpha: 0.12 + 0.3 * glow),
      );
    }
  }

  void _star(Canvas canvas, Offset c, double r, Color color) {
    final k = r * 0.28;
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy - r)
        ..lineTo(c.dx + k, c.dy - k)
        ..lineTo(c.dx + r, c.dy)
        ..lineTo(c.dx + k, c.dy + k)
        ..lineTo(c.dx, c.dy + r)
        ..lineTo(c.dx - k, c.dy + k)
        ..lineTo(c.dx - r, c.dy)
        ..lineTo(c.dx - k, c.dy - k)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_SparklePainter old) =>
      old.seed != seed || old.color != color;
}

/// More's bigger card: the top five and where I stand.
class LeaderboardCard extends StatelessWidget {
  const LeaderboardCard({super.key});

  @override
  Widget build(BuildContext context) {
    final campus = viewCampus();
    if (roleStore == null || campus == null) return const SizedBox.shrink();
    final p = AppPalette.of(context);
    // The board's midnight card, the same in both modes (owner, 2026-10-06).
    const fg = Colors.white;
    final sub = TypeScale.caption.copyWith(
      fontSize: 10.5,
      color: fg.withValues(alpha: .8),
    );
    return Material(
      color: const Color(0xFF272757),
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap:
            () => openRoute(
              context,
              Routes.leaderboard,
              () => const LeaderboardPage(),
            ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 15, 15, 13),
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
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0C648),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.emoji_events_outlined,
                          size: 20,
                          color: Color(0xFF17170F),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Contributor Leaderboard',
                              style: TypeScale.body.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: fg,
                              ),
                            ),
                            if (rank != null)
                              Text(
                                'You are ${ordinal(rank)} of ${d.board.length} '
                                'on ${campusName(campus)}',
                                style: sub,
                              ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: fg.withValues(alpha: .8)),
                    ],
                  ),
                  const SizedBox(height: 9),
                  if (d.board.isEmpty)
                    Text('No contributors yet', style: sub)
                  else
                    Column(
                      spacing: 4,
                      children: [
                        for (final (i, e) in d.board.take(5).indexed)
                          _CardRow(
                            rank: i + 1,
                            entry: e,
                            me: e.username == d.mine,
                            palette: p,
                          ),
                        if (mine != null && rank! > 5)
                          _CardRow(rank: rank, entry: mine, me: true, palette: p),
                      ],
                    ),
                  if (mine == null && d.board.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('You are not on the board yet', style: sub),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
