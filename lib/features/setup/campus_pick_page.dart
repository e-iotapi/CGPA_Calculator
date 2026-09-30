import 'package:cgpa_calculator/admin/widgets.dart' show Note;
import 'package:cgpa_calculator/app/routes.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/core/storage/cache_boxes.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/card_row.dart';
import 'package:cgpa_calculator/shared/widgets/circle_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce/hive.dart';

const _previewKey = 'previewCampus';
const _campuses = ['goa', 'hyderabad', 'pilani', 'dubai'];

/// The campus More's pages show: the address's own, else the owner's preview
/// pick on this device. View only: never written to the profile or Firestore
/// (BUG-16).
String? viewCampus() {
  if (campusOfAddress(roleStore?.me ?? '') case final own?) return own;
  if (!Hive.isBoxOpen(deviceBoxName)) return null;
  final raw = Hive.box(deviceBoxName).get(_previewKey);
  return _campuses.contains(raw) ? raw as String : null;
}

/// What an empty More page shows when [viewCampus] is null: a row to pick
/// one (an owner's address names no campus). The page is rebuilt on return.
Widget campusPrompt(BuildContext context) => Column(
  children: [
    const Note('Your address names no campus. Pick one to preview.'),
    AppCard(
      padding: EdgeInsets.zero,
      child: CardRow(
        title: 'Choose a campus',
        onTap: () async {
          final router = GoRouter.of(context);
          final where = router.state.uri.toString();
          if (await router.push<String>(Routes.previewCampus) != null) {
            router.pushReplacement(where);
          }
        },
      ),
    ),
  ],
);

/// A pushed list of campuses; copy of the programme picker. Saves the pick
/// on this device and pops with it.
class CampusPickPage extends StatelessWidget {
  const CampusPickPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final selected = viewCampus();
    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                Space.xxl,
                Space.gutter,
                Space.xxl,
              ),
              children: [
                Row(
                  children: [
                    CircleIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Back',
                      size: 44,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'OWNER · PREVIEW ONLY',
                            style: TypeScale.label.copyWith(color: p.textMuted),
                          ),
                          Semantics(
                            header: true,
                            child: Text(
                              'Pick a campus',
                              style: TypeScale.title.copyWith(
                                fontSize: 19,
                                color: p.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.md),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Material(
                    color: p.surface,
                    child: Column(
                      children: [
                        for (final (i, c) in _campuses.indexed) ...[
                          if (i > 0)
                            Divider(
                              height: 1,
                              indent: 13,
                              endIndent: 13,
                              color: p.divider,
                            ),
                          CardRow(
                            title: campusName(c),
                            trailing:
                                c == selected
                                    ? Icon(Icons.check_rounded, color: p.text)
                                    : const SizedBox.shrink(),
                            onTap: () async {
                              if (Hive.isBoxOpen(deviceBoxName)) {
                                await Hive.box(
                                  deviceBoxName,
                                ).put(_previewKey, c);
                              }
                              if (context.mounted) Navigator.pop(context, c);
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Space.md),
                Text(
                  'Changes what Representatives, Course reviews and Resources '
                  'show on this device. Nothing is saved to your account.',
                  style: TypeScale.caption.copyWith(
                    fontSize: 10.5,
                    height: 1.45,
                    color: p.textMuted,
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
