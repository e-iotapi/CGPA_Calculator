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
    return PageFrame(
      header: const PageHeader(eyebrow: 'CONTRIBUTE', title: 'Application sent'),
      children: [
        Note(
          'Your department president decides within 15 days. Add links opens '
          'here once you are approved.',
        ),
        const SizedBox(height: Space.md),
        if (campus != null && dept != null) ...[
          Text(
            'Waiting? Ask your president',
            style: TypeScale.body.copyWith(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: p.text,
            ),
          ),
          const SizedBox(height: Space.sm),
          PresidentContact(campus: campus, dept: dept),
          Text(
            departmentName(dept),
            style: TypeScale.caption.copyWith(color: p.textMuted),
          ),
        ],
      ],
    );
  }
}
