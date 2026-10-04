import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/platform/browser.dart';
import 'package:cgpa_calculator/core/resources/resource.dart';
import 'package:cgpa_calculator/core/roles/activity_store.dart';
import 'package:cgpa_calculator/core/roles/capabilities.dart';
import 'package:cgpa_calculator/core/roles/contacts.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/features/resources/link_sheet.dart';
import 'package:cgpa_calculator/features/resources/resources_page.dart';
import 'package:cgpa_calculator/features/roles/rep_profile.dart';
import 'package:cgpa_calculator/features/setup/campus_pick_page.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/bottom_action.dart';
import 'package:cgpa_calculator/shared/widgets/outlined_pill.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:flutter/material.dart';

typedef _Data = ({List<Resource> links, DirectoryEntry? cr, int? updated});

DirectoryEntry? _crOf(List<DirectoryEntry> people, String courseId) {
  final now = DateTime.now();
  for (final e in people) {
    if (e
        .liveAt(now)
        .any((r) => r.role == GrantRole.course && r.scope == courseId)) {
      return e;
    }
  }
  return null;
}

/// Board `ResourceCourse`: one course's links, its CR's contact pills and
/// Add a link for staff.
class ResourceCoursePage extends StatefulWidget {
  const ResourceCoursePage({super.key, required this.courseId});
  final String courseId;

  @override
  State<ResourceCoursePage> createState() => _ResourceCoursePageState();
}

class _ResourceCoursePageState extends State<ResourceCoursePage> {
  int _loads = 0;

  String get _dept => deptOf(widget.courseId);

  Future<_Data> _load(String campus) async => (
    links: await resourceStore!.department(campus, _dept),
    cr: _crOf(await contactStore!.directory(campus), widget.courseId),
    // Last updated is a courtesy: a failed read leaves the text out.
    updated:
        (await ActivityStore(roleStore!.db)
                .of(campus)
                .catchError((_) => const Activity()))
            .ofCourse(widget.courseId),
  );

  _Data? _peek(String campus) {
    final links = resourceStore?.peekDepartment(campus, _dept);
    final people = contactStore?.peekDirectory(campus);
    return links == null || people == null
        ? null
        : (
          links: links,
          cr: _crOf(people, widget.courseId),
          updated:
              ActivityStore(roleStore!.db).peekOf(campus)?.ofCourse(widget.courseId),
        );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final campus = viewCampus();
    final id = widget.courseId;
    final header = PageHeader(
      eyebrow: id.toUpperCase(),
      title: courseTitle(id).isEmpty ? id : courseTitle(id),
    );
    if (resourceStore == null || campus == null) {
      return PageFrame(
        header: header,
        children: [
          if (roleStore == null)
            const Note('Sign in with your BITS account to see resources.')
          else
            campusPrompt(context),
        ],
      );
    }
    final mayAdd = myRoles.value.may(
      Capability.courseResources,
      campus: campus,
      scope: id,
    );
    return Loaded<_Data>(
      key: ValueKey(_loads),
      cacheKey: 'rescourse|$campus|$id',
      load: () => _load(campus),
      peek: () => _peek(campus),
      gated: (context, data, _, saved) {
        final mine = courseList(data.links, id);
        return PageFrame(
          header: header,
          bottom:
              mayAdd
                  ? BottomAction(
                    child: PrimaryButton(
                      label: 'Add a link',
                      icon: Icons.add_rounded,
                      // Last list: writes wait for the fresh one.
                      onPressed:
                          saved
                              ? null
                              : () async {
                                if (await editLink(
                                      context,
                                      campus: campus,
                                      dept: _dept,
                                      department: data.links,
                                      course: id,
                                      actingFor: id,
                                    ) &&
                                    mounted) {
                                  setState(() => _loads++);
                                }
                              },
                    ),
                  )
                  : null,
          children: [
            if (data.cr case final cr?)
              _CrContact(cr: cr, updated: data.updated),
            if (mine.isEmpty)
              const Note('No links for this course yet.')
            else
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final (i, r) in mine.indexed) ...[
                      if (i > 0)
                        Divider(height: 1, indent: 15, color: p.divider),
                      LinkRow(
                        r: r,
                        tag: r.isCourse ? null : 'IN DEPT',
                        onReport: () => reportLink(context, r),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The course's CR and the contact pills they chose to show.
class _CrContact extends StatelessWidget {
  const _CrContact({required this.cr, this.updated});
  final DirectoryEntry cr;
  final int? updated;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final pills = [
      if (cr.shownEmail case final m?) ('Email', 'mailto:$m'),
      if (cr.whatsapp case final w?)
        ('WhatsApp', 'https://wa.me/${w.replaceAll(RegExp(r'[^0-9]'), '')}'),
      if (cr.phone case final t?) ('Call', 'tel:${t.replaceAll(' ', '')}'),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'CR · ${cr.name}',
                  style: TypeScale.body.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (updated case final ms?)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  spacing: 1,
                  children: [
                    Text(
                      'LAST UPDATED',
                      style: TypeScale.caption.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: p.textMuted,
                      ),
                    ),
                    Text(
                      monthYear(ms),
                      style: TypeScale.caption.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: p.text,
                      ),
                    ),
                  ],
                ),
            ],
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
