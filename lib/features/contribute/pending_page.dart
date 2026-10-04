import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/features/contribute/contribute_data.dart';
import 'package:cgpa_calculator/features/contribute/contribute_widgets.dart';
import 'package:cgpa_calculator/features/setup/campus_pick_page.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:flutter/material.dart';

/// "Application sent": what happens next, and the president to ask.
class PendingPage extends StatelessWidget {
  const PendingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final campus = viewCampus(), dept = myContribDept();
    final username = peekMyContrib()?.me.username;
    return PageFrame(
      header: const PageHeader(eyebrow: 'CONTRIBUTE', title: 'Application sent'),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          decoration: BoxDecoration(
            color: p.hero,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox.square(
                    dimension: 44,
                    child: Icon(
                      Icons.schedule_rounded,
                      size: 20,
                      color: p.onHero,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Waiting for approval',
                          style: TypeScale.body.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: p.onHero,
                          ),
                        ),
                        if (username != null)
                          Text(
                            'Username: $username',
                            style: TypeScale.caption.copyWith(
                              color: p.onHeroMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Talk to your president about approval. They can approve you '
                'from their Contributors tab.',
                style: TypeScale.caption.copyWith(
                  fontSize: 11.5,
                  height: 1.45,
                  color: p.onHeroMuted,
                ),
              ),
            ],
          ),
        ),
        if (campus != null && dept != null) ...[
          const SizedBox(height: Space.md),
          Text(
            'YOUR PRESIDENT · ${dept.toUpperCase()} · '
            '${campusName(campus).toUpperCase()}',
            style: TypeScale.label.copyWith(color: p.textMuted),
          ),
          const SizedBox(height: Space.sm),
          PresidentContact(campus: campus, dept: dept),
        ],
        const Note(
          'Admins and secretaries can approve too. You will see Contribute '
          'under More once approved.',
        ),
      ],
    );
  }
}
