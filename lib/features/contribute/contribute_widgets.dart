import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/routes.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/features/setup/campus_pick_page.dart';
import 'package:cgpa_calculator/shared/widgets/confirm_dialog.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/platform/browser.dart';
import 'package:cgpa_calculator/core/roles/contacts.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/features/contribute/apply_page.dart';
import 'package:cgpa_calculator/features/contribute/contribute_data.dart';
import 'package:cgpa_calculator/features/roles/rep_profile.dart';
import 'package:cgpa_calculator/shared/widgets/outlined_pill.dart';
import 'package:cgpa_calculator/shared/widgets/tag_badge.dart';
import 'package:flutter/material.dart';

/// The chip on one of my links.
class LinkStateChip extends StatelessWidget {
  const LinkStateChip(this.state, {super.key});
  final LinkState state;

  @override
  Widget build(BuildContext context) => switch (state) {
    LinkState.awaiting => const TagBadge('Awaiting', tone: TagTone.yours),
    LinkState.approved => const TagBadge('Approved'),
    LinkState.rejected => const TagBadge('Rejected', tone: TagTone.dropped),
    LinkState.expired => const TagBadge('Hidden', tone: TagTone.dropped),
  };
}

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
    final pills = [
      if (person.shownEmail case final m?) ('Email', 'mailto:$m'),
      if (person.whatsapp case final w?)
        ('WhatsApp', 'https://wa.me/${w.replaceAll(RegExp(r'[^0-9]'), '')}'),
      if (person.phone case final t?) ('Call', 'tel:${t.replaceAll(' ', '')}'),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'President · ${person.name}',
            style: TypeScale.body.copyWith(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (pills.isEmpty)
            Text(
              'Shares no contact details.',
              style: TypeScale.caption.copyWith(color: p.textMuted),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (label, uri) in pills)
                    OutlinedPill(label: label, onPressed: () => openUrl(uri)),
                ],
              ),
            ),
        ],
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
  final apply = await confirmDialog(
    context,
    title: 'Contribute to the Community Now',
    body: 'Become a contributor and add links for your department.',
    action: 'Apply now',
    cancel: 'Not now',
  );
  if (apply && context.mounted) {
    openRoute(context, Routes.contributeApply, () => const ApplyPage());
  }
}
