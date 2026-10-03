import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/contrib/contributor_store.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/features/contribute/contribute_data.dart';
import 'package:cgpa_calculator/features/contribute/pending_page.dart';
import 'package:cgpa_calculator/features/setup/campus_pick_page.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
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
  bool _busy = false, _sent = false, _failed = false;
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
      if (have == null) await store.claimUsername(campus, name);
      await store.apply(campus, dept);
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
          _nameError = 'Use 3 to 20 letters, numbers or underscores.';
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
    const header = PageHeader(
      eyebrow: 'CONTRIBUTE',
      title: 'Become a contributor',
    );
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
            Text(
              'How it works',
              style: TypeScale.body.copyWith(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: p.text,
              ),
            ),
            const SizedBox(height: Space.xs),
            for (final line in const [
              'Your links go live straight away.',
              'A president approves them within 15 days, or they are hidden.',
              'Points are counted after approval: 4 for every link.',
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: Space.xs),
                child: Text(
                  '·  $line',
                  style: TypeScale.caption.copyWith(
                    fontSize: 12,
                    height: 1.4,
                    color: p.textMuted,
                  ),
                ),
              ),
            const SizedBox(height: Space.md),
            AppTextField(
              controller: _name,
              label: 'Username',
              hint: 'quiet_owl',
              error: _nameError,
              onChanged: (_) => setState(() => _nameError = null),
            ),
            Padding(
              padding: const EdgeInsets.only(top: Space.xs),
              child: Text(
                have == null
                    ? 'Shown on the leaderboard instead of your name. 3 to 20 '
                        'letters, numbers or underscores. You cannot change it '
                        'later.'
                    : 'Your username on the leaderboard.',
                style: TypeScale.caption.copyWith(color: p.textMuted),
              ),
            ),
            const SizedBox(height: Space.md),
            if (_error != null) ...[
              Notice(warning: true, text: TextSpan(text: _error)),
              const SizedBox(height: Space.sm),
            ],
            Text(
              'You apply to the ${departmentName(dept)} president.',
              style: TypeScale.caption.copyWith(color: p.textMuted),
            ),
            const SizedBox(height: Space.sm),
            PrimaryButton(
              label:
                  _busy
                      ? 'Sending…'
                      : _failed
                      ? 'Try again'
                      : 'Apply',
              onPressed: _busy ? null : () => _apply(mine, campus, dept),
            ),
          ],
        );
      },
    );
  }
}
