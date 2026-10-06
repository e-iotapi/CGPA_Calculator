import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/contrib/contributor_store.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/features/contribute/contribute_data.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:flutter/material.dart';

/// Staff links earn +4 too, but the leaderboard lists usernames only: until
/// they claim one, Controls and Your department offer it (owner,
/// 2026-10-06). Hidden for a non-BITS account and once a name is held.
class LeaderboardNameCard extends StatefulWidget {
  const LeaderboardNameCard({super.key});

  @override
  State<LeaderboardNameCard> createState() => _LeaderboardNameCardState();
}

class _LeaderboardNameCardState extends State<LeaderboardNameCard> {
  final _name = TextEditingController();
  final _store = contributorStore;
  late final _campus = _store == null ? null : campusOfAddress(_store.roles.me);
  MyContributor? _me;
  String? _claimed, _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final s = _store, c = _campus;
    if (s == null || c == null) return;
    _me = s.peekMe(s.roles.me);
    s.me(c).then((m) {
      if (mounted) setState(() => _me = m);
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _claim() async {
    final n = _name.text.trim().toLowerCase();
    if (!validUsername(n)) {
      return setState(
        () => _error = 'Use 3 to 20 letters, numbers or underscores.',
      );
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _store!.claimUsername(_campus!, n);
      if (mounted) setState(() => _claimed = n);
    } on UsernameTaken {
      if (mounted) setState(() => _error = 'That username is taken. Try another.');
    } on ContribError catch (e) {
      if (mounted) {
        setState(
          () =>
              _error = switch (e.code) {
                'campus' => 'Usernames are claimed on your own campus.',
                'hasName' => 'You already have a username.',
                _ => 'Use 3 to 20 letters, numbers or underscores.',
              },
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = problem(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final me = _me;
    if (_claimed case final n?) {
      return Padding(
        padding: const EdgeInsets.only(top: Space.sm),
        child: Note('You are on the leaderboard as $n.'),
      );
    }
    if (me == null || me.username != null) return const SizedBox.shrink();
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: Space.sm),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Show up on the leaderboard',
              style: TypeScale.body.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: p.text,
              ),
            ),
            const SizedBox(height: Space.xs),
            Text(
              'Your links earn 4 points each'
              '${me.points > 0 ? ', ${me.points} so far' : ''}. The board '
              'shows usernames only: pick one to be ranked. You can\'t '
              'change it later.',
              style: TypeScale.caption.copyWith(height: 1.45, color: p.textMuted),
            ),
            const SizedBox(height: Space.sm),
            AppTextField(
              controller: _name,
              label: 'Username',
              hint: 'quiet_owl',
              fill: p.background,
              error: _error,
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: Space.sm),
            PrimaryButton(
              label: _busy ? 'Claiming…' : 'Claim username',
              onPressed: _busy ? null : _claim,
            ),
          ],
        ),
      ),
    );
  }
}
