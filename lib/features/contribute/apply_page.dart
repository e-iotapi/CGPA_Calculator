import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/contrib/contributor_store.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/features/contribute/contribute_data.dart';
import 'package:cgpa_calculator/features/contribute/pending_page.dart';
import 'package:cgpa_calculator/features/setup/campus_pick_page.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/bottom_action.dart';
import 'package:cgpa_calculator/shared/widgets/notice.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:flutter/material.dart';

/// Board `ContributorApply`: the rules up front, a username, Apply. On
/// success the same screen turns into [PendingPage].
class ApplyPage extends StatefulWidget {
  const ApplyPage({super.key});

  @override
  State<ApplyPage> createState() => _ApplyPageState();
}

class _ApplyPageState extends State<ApplyPage> {
  final _name = TextEditingController();
  bool _busy = false, _sent = false, _failed = false, _ack = false;
  String? _nameError, _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _apply(MyContrib mine, String campus, String dept) async {
    final name = _name.text.trim().toLowerCase();
    final have = mine.me.username;
    if (have == null && !validUsername(name)) {
      return setState(
        () => _nameError = 'Use 3 to 20 letters, numbers or underscores.',
      );
    }
    setState(() {
      _busy = true;
      _failed = false;
      _nameError = _error = null;
    });
    final store = contributorStore!;
    try {
      if (have == null) {
        await store.claimUsername(campus, name, applyTo: dept);
      } else {
        await store.apply(campus, dept);
      }
      await refreshContribState();
      if (mounted) setState(() => _sent = true);
    } on UsernameTaken {
      if (mounted) {
        setState(() {
          _busy = false;
          _nameError = 'That username is taken. Try another.';
        });
      }
    } on ContribError catch (e) {
      if (e.code == 'exists') {
        await refreshContribState();
        if (mounted) setState(() => _sent = true);
      } else if (mounted) {
        setState(() {
          _busy = false;
          _nameError = switch (e.code) {
            'notBits' =>
              'Sign in with your BITS student email to choose a username.',
            'campus' => 'Usernames are claimed on your own campus.',
            'hasName' =>
              'You already have a username. Reopen this page to use it.',
            _ => 'Use 3 to 20 letters, numbers or underscores.',
          };
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _failed = true;
          _error = problem(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) return const PendingPage();
    final p = AppPalette.of(context);
    final campus = viewCampus(), dept = myContribDept();
    const header = PageHeader(eyebrow: 'CONTRIBUTE', title: 'Apply');
    if (roleStore == null || campus == null || dept == null) {
      return PageFrame(
        header: header,
        children: [
          if (roleStore == null)
            const Note('Sign in with your BITS account to apply.')
          else
            const Note('Pick your campus and degree in Settings to apply.'),
        ],
      );
    }
    return Loaded<MyContrib>(
      cacheKey: 'contrib-me|$campus|${roleStore!.me}',
      load: loadMyContrib,
      peek: peekMyContrib,
      builder: (context, mine, _) {
        final state = contribStateOf(mine);
        if (state == ContribState.applied) return const PendingPage();
        if (state == ContribState.approved) {
          return const PageFrame(
            header: header,
            children: [Note('You are already a contributor.')],
          );
        }
        final have = mine.me.username;
        if (have != null && _name.text.isEmpty) _name.text = have;
        final reason = mine.request?.reason ?? '';
        return PageFrame(
          header: header,
          bottom: BottomAction(
            child: PrimaryButton(
              label:
                  _busy
                      ? 'Sending…'
                      : _failed
                      ? 'Try again'
                      : 'Send application',
              onPressed:
                  _busy || !_ack ? null : () => _apply(mine, campus, dept),
            ),
          ),
          children: [
            if (state == ContribState.declined) ...[
              Notice(
                warning: true,
                text: TextSpan(
                  text:
                      'Your last application was declined'
                      '${reason.isEmpty ? '.' : ': $reason'} You can apply '
                      'again.',
                ),
              ),
              const SizedBox(height: Space.sm),
            ],
            const _HowItWorks(),
            const SizedBox(height: Space.md),
            AppTextField(
              controller: _name,
              label: 'Contributor username',
              labelAbove: true,
              fill: AppPalette.of(context).surface,
              hint: 'quiet_owl',
              error: _nameError,
              onChanged: (_) => setState(() => _nameError = null),
            ),
            Padding(
              padding: const EdgeInsets.only(top: Space.xs),
              child: Text(
                have == null
                    ? 'This is the name other students see. It appears on the '
                        'leaderboard and beside every link you add, instead of '
                        'your real name or email. Use 3-20 letters or numbers, '
                        'no spaces. You can\'t change it later.'
                    : 'Your username on the leaderboard.',
                style: TypeScale.caption.copyWith(color: p.textMuted),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: Space.sm),
              Notice(warning: true, text: TextSpan(text: _error)),
            ],
            Semantics(
              checked: _ack,
              label: 'I understand how approval and points work',
              excludeSemantics: true,
              child: InkWell(
                onTap: () => setState(() => _ack = !_ack),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: _ack ? p.inverse : Colors.transparent,
                          borderRadius: BorderRadius.circular(7),
                          border:
                              _ack
                                  ? null
                                  : Border.all(color: p.outline, width: 1.5),
                        ),
                        child:
                            _ack
                                ? Icon(
                                  Icons.check_rounded,
                                  size: 15,
                                  color: p.onInverse,
                                )
                                : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'I understand how approval and points work',
                          style: TypeScale.body.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: p.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The rules card: what a contributor signs up for.
class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final base = TypeScale.body.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 1.45,
      color: p.text,
    );
    final bold = base.copyWith(fontWeight: FontWeight.w800);
    final lines = <List<InlineSpan>>[
      [const TextSpan(text: 'Your links go live at once.')],
      [
        const TextSpan(text: 'An approver confirms each link within '),
        TextSpan(text: '15 days', style: bold),
        const TextSpan(text: '.'),
      ],
      [
        const TextSpan(text: 'Points (+4 per link) count only '),
        TextSpan(text: 'after approval', style: bold),
        const TextSpan(text: '.'),
      ],
      [
        const TextSpan(
          text:
              'Not approved in 15 days: the link is hidden from everyone, '
              'and earns nothing.',
        ),
      ],
      [const TextSpan(text: 'You can edit your links; you can\'t delete them.')],
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HOW IT WORKS',
            style: TypeScale.label.copyWith(color: p.textMuted),
          ),
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(Icons.check_rounded, size: 15, color: p.accent),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text.rich(TextSpan(style: base, children: l)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
