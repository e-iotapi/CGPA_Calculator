import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/routes.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/features/setup/campus_pick_page.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/platform/browser.dart';
import 'package:cgpa_calculator/core/roles/contacts.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/features/contribute/apply_page.dart';
import 'package:cgpa_calculator/features/contribute/contribute_data.dart';
import 'package:cgpa_calculator/features/roles/rep_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The department president (and secretary) of [dept] on [campus], with the
/// Email / WhatsApp / Call pills each chose to show.
class PresidentContact extends StatelessWidget {
  const PresidentContact({super.key, required this.campus, required this.dept});
  final String campus, dept;

  @override
  Widget build(BuildContext context) {
    final store = contactStore;
    if (store == null) return const SizedBox.shrink();
    return Loaded<List<DirectoryEntry>>(
      cacheKey: 'reps-ui|$campus',
      load: () => store.directory(campus),
      peek: () => store.peekDirectory(campus),
      builder: (context, people, _) {
        final now = DateTime.now();
        final heads = [
          for (final p in people)
            if (p
                .liveAt(now)
                .any((r) => r.role == GrantRole.dept && r.scope == dept))
              p,
        ];
        if (heads.isEmpty) {
          return const Note('No president is listed for this department yet.');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final h in heads) _Head(h)],
        );
      },
    );
  }
}

class _Head extends StatelessWidget {
  const _Head(this.person);
  final DirectoryEntry person;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final mail = person.shownEmail;
    final pills = [
      if (person.whatsapp case final w?)
        ('WhatsApp', 'https://wa.me/${w.replaceAll(RegExp(r'[^0-9]'), '')}'),
      if (person.phone case final t?) ('Call', 'tel:${t.replaceAll(' ', '')}'),
    ];
    final note = TypeScale.caption.copyWith(fontSize: 10.5, color: p.textMuted);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: Space.sm),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            person.name,
            style: TypeScale.body.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: p.text,
            ),
          ),
          if (mail != null) ...[
            const SizedBox(height: 10),
            Text(mail, style: note),
          ],
          if (mail == null && pills.isEmpty) ...[
            const SizedBox(height: 10),
            Text('Shares no contact details.', style: note),
          ],
          if (mail != null || pills.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  if (mail != null)
                    _CardButton(
                      'Copy email',
                      () async {
                        await Clipboard.setData(ClipboardData(text: mail));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Email copied')),
                          );
                        }
                      },
                    ),
                  for (final (label, uri) in pills) ...[
                    if (mail != null || label != pills.first.$1)
                      const SizedBox(width: 8),
                    _CardButton(label, () => openUrl(uri)),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The 44 tall outlined pill on a card ("Copy email").
class _CardButton extends StatelessWidget {
  const _CardButton(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Expanded(
      child: Material(
        color: p.surface,
        shape: StadiumBorder(side: BorderSide(color: p.outline)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: SizedBox(
            height: 44,
            child: Center(
              child: Text(
                label,
                style: TypeScale.body.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: p.text,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The first Resources open of a session offers to become a contributor, to
/// anyone who has not applied (or was declined). In-memory flag, no print.
Future<void> maybeShowContributePrompt(BuildContext context) async {
  if (contributePromptShown || roleStore == null || viewCampus() == null) {
    return;
  }
  if (myRoles.value.privileged) return;
  contributePromptShown = true;
  await refreshContribState();
  if (!context.mounted) return;
  final s = contribState.value;
  if (s != ContribState.none && s != ContribState.declined) return;
  final apply = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    barrierColor: Colors.black.withValues(alpha: .34),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    builder: (_) => const _PromptSheet(),
  );
  if (apply == true && context.mounted) {
    openRoute(context, Routes.contributeApply, () => const ApplyPage());
  }
}

/// Board `PfContribPrompt`: the offer, with Not now and Apply now.
class _PromptSheet extends StatelessWidget {
  const _PromptSheet();

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: p.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Contribute to the Community Now',
                        style: TypeScale.title.copyWith(
                          fontSize: 21,
                          letterSpacing: -0.5,
                          color: p.text,
                        ),
                      ),
                      Text(
                        'Become a Contributor',
                        style: TypeScale.caption.copyWith(
                          fontSize: 11.5,
                          color: p.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Material(
                  color: p.chipFill,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.pop(context, false),
                    child: SizedBox.square(
                      dimension: 44,
                      child: Icon(Icons.close_rounded, size: 20, color: p.text),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Share links to notes, papers and handouts for any course on '
                'your campus. Approvers confirm each link within 15 days. You '
                'earn 4 points for each approved link.',
                style: TypeScale.caption.copyWith(
                  fontSize: 12,
                  height: 1.45,
                  color: p.textMuted,
                ),
              ),
            ),
            const Note('Shown once each time you open the app.'),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: _SheetButton(
                    'Not now',
                    onTap: () => Navigator.pop(context, false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SheetButton(
                    'Apply now',
                    ink: true,
                    onTap: () => Navigator.pop(context, true),
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

class _SheetButton extends StatelessWidget {
  const _SheetButton(this.label, {required this.onTap, this.ink = false});
  final String label;
  final VoidCallback onTap;
  final bool ink;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Material(
      color: ink ? p.inverse : p.surface,
      shape: StadiumBorder(
        side: ink ? BorderSide.none : BorderSide(color: p.outline),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Center(
            child: Text(
              label,
              style: TypeScale.body.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: ink ? p.onInverse : p.text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
