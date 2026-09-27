import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/routes.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/roles/capabilities.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Board `RolePick`: an owner opens Pointer as any role (§16.3 fix 1). It
/// changes what they see, not what they can do: the database still sees the
/// owner, and every save is theirs.
class OpenAsPage extends StatefulWidget {
  const OpenAsPage({super.key});

  @override
  State<OpenAsPage> createState() => _OpenAsPageState();
}

class _OpenAsPageState extends State<OpenAsPage> {
  Role? _picking;
  String _campus = 'goa';
  String? _dept;
  final _course = TextEditingController();

  @override
  void dispose() {
    _course.dispose();
    super.dispose();
  }

  void _open(ViewAs? v, String to) {
    viewAs.value = v;
    context.go(to);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    Widget option(Role r, String tag, String title, String line) => NavRow(
      icon: switch (r) {
        Role.owner => Icons.shield_outlined,
        Role.admin => Icons.admin_panel_settings_outlined,
        Role.president => Icons.account_balance_outlined,
        Role.cr => Icons.class_outlined,
        Role.student => Icons.school_outlined,
      },
      title: title,
      subtitle: line,
      accent: _picking == r,
      onTap:
          () => switch (r) {
            Role.owner => _open(null, Routes.admin),
            Role.admin => _open(const ViewAs(Role.admin), Routes.admin),
            Role.student => _open(const ViewAs(Role.student), Routes.home),
            _ => setState(() => _picking = r),
          },
    );

    return PageFrame(
      header: const PageHeader(
        eyebrow: 'OWNER · TESTING AND DEVELOPMENT',
        title: 'Open Pointer as',
      ),
      children: [
        RowGroup(
          children: [
            option(Role.owner, 'OWNER', 'Owner', 'Everything, every campus'),
            option(Role.admin, 'ADMIN', 'Admin', 'Controls without Owner only'),
            option(
              Role.president,
              'PRES',
              'Department president',
              'Pick a department and campus',
            ),
            option(Role.cr, 'CR', 'Course manager', 'Pick a course and campus'),
            option(
              Role.student,
              'STUDENT',
              'Student',
              'Your own grades, as any student sees them',
            ),
          ],
        ),
        if (_picking == Role.president || _picking == Role.cr) ...[
          const SizedBox(height: Space.sm),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Campus'),
                ChoicePills<String>(
                  values: const ['goa', 'hyderabad', 'pilani', 'dubai'],
                  selected: _campus,
                  label: campusName,
                  onSelected: (c) => setState(() => _campus = c),
                ),
                const SizedBox(height: Space.sm),
                if (_picking == Role.president)
                  DropdownButtonFormField<String>(
                    initialValue: _dept,
                    isExpanded: true,
                    hint: const Text('Department'),
                    items: [
                      for (final e in departments.entries)
                        DropdownMenuItem(
                          value: e.key,
                          child: Text('${e.key} · ${e.value.name}'),
                        ),
                    ],
                    onChanged: (v) => setState(() => _dept = v),
                  )
                else
                  AppTextField(
                    controller: _course,
                    label: 'Course code',
                    hint: 'CS F301',
                    onChanged: (_) => setState(() {}),
                  ),
                const SizedBox(height: Space.md),
                PrimaryButton(
                  label: 'Open',
                  onPressed:
                      _picking == Role.president
                          ? _dept == null
                              ? null
                              : () => _open(
                                ViewAs(
                                  Role.president,
                                  campus: _campus,
                                  scope: _dept,
                                ),
                                Routes.dept(_campus, _dept!),
                              )
                          : _course.text.trim().isEmpty
                          ? null
                          : () {
                            final id = _course.text.trim().toUpperCase();
                            _open(
                              ViewAs(Role.cr, campus: _campus, scope: id),
                              Routes.crCourse(_campus, id),
                            );
                          },
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: Space.md),
        Text(
          'This changes what you see, not what you can do. The database still '
          'sees your owner account: anything you save is saved as you and '
          'logged with your name. A strip at the top says which role you are '
          'viewing as, with a button back here.',
          style: TypeScale.caption.copyWith(height: 1.45, color: p.textMuted),
        ),
        const Note(
          'Testing what a role may actually do uses the emulator and test '
          'accounts, never this screen.',
        ),
      ],
    );
  }
}
