import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/grading/cgpa.dart';
import 'package:cgpa_calculator/core/models/course_names.dart';
import 'package:cgpa_calculator/core/storage/courses.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/semester/add_course_controller.dart';
import 'package:cgpa_calculator/features/semester/semester_controller.dart';
import 'package:cgpa_calculator/features/semester/widgets/course_fields.dart';
import 'package:cgpa_calculator/shared/widgets/card_row.dart';
import 'package:cgpa_calculator/shared/widgets/confirm_dialog.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';

/// What the edit sheet asks for: the course to store, or its removal.
typedef CourseEdit = ({Course? saved, bool removed});

/// Opens the edit sheet for [course]. [profile] is the grade being edited;
/// null (Compare, Offshoot) leaves grades alone.
Future<CourseEdit?> showEditCourseSheet(
  BuildContext context, {
  required Course course,
  required String discipline,
  required Profile? profile,
}) {
  final p = AppPalette.of(context);
  return showModalBottomSheet<CourseEdit>(
    context: context,
    isScrollControlled: true,
    backgroundColor: p.isDark ? p.surface : p.onInverse,
    barrierColor: p.inverse.withValues(alpha: 0.34),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    constraints: const BoxConstraints(maxWidth: 640),
    builder:
        (_) => EditCourseSheet(
          course: course,
          discipline: discipline,
          profile: profile,
        ),
  );
}

/// Applies an edit to storage, under the key the course was read from.
Future<void> applyCourseEdit(Course course, CourseEdit edit) async {
  if (edit.removed) {
    if (course.isInBox) {
      await course.delete();
    } else {
      await Hive.box<Course>(coursesBoxName).delete(course.id);
    }
  } else if (edit.saved case final saved?) {
    // A category changed here is set by hand, as on the Degree page.
    if (saved.elective != course.elective) await pinCategory(course.id);
    // Under the key read (§14.6): a dual's two PS II rows share an id, so
    // matching on id and semester would overwrite the other after a move.
    if (course.isInBox) {
      await course.box!.put(course.key, saved);
    } else {
      await saveCourse(saved);
    }
  }
}

/// The sheet that edits or removes one course in a semester.
class EditCourseSheet extends StatefulWidget {
  const EditCourseSheet({
    super.key,
    required this.course,
    required this.discipline,
    required this.profile,
  });

  final Course course;
  final String discipline;
  final Profile? profile;

  @override
  State<EditCourseSheet> createState() => _EditCourseSheetState();
}

class _EditCourseSheetState extends State<EditCourseSheet> {
  late String _category = widget.course.elective;
  late int _grade = switch (widget.profile) {
    Profile.expected => widget.course.grade2,
    _ => widget.course.grade1,
  };

  Course get _edited {
    final c = widget.course.copyWith(elective: _category);
    return widget.profile == null ? c : c.withGrade(widget.profile!.id, _grade);
  }

  Future<void> _remove() async {
    final ok = await confirmDialog(
      context,
      title: 'Remove this course?',
      body:
          '${widget.course.id} leaves ${semLabel(widget.course.sem)}, '
          'with its grades.',
      cancel: 'Keep',
      action: 'Remove',
      danger: true,
    );
    if (ok && mounted) {
      Navigator.pop(context, (saved: null, removed: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final c = widget.course;
    final cr = formatCredits(c.credits);
    final profile = widget.profile;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          10,
          20,
          Space.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  Text(
                    displayTitle(c.id, c.title),
                    style: TypeScale.sheetTitle.copyWith(color: p.text),
                  ),
                  Text(
                    '${c.id} · $cr credit${cr == '1' ? '' : 's'} · '
                    '${semLabel(c.sem)}',
                    style: TypeScale.caption.copyWith(color: p.textMuted),
                  ),
                  const SizedBox(height: Space.lg),
                  FieldSection(
                    label: 'COUNTS AS',
                    child: Material(
                      color: p.surface,
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.antiAlias,
                      child: CardRow(
                        title: categoryLabel(_category, widget.discipline),
                        onTap: () async {
                          final t = await pickCategory(
                            context,
                            value: _category,
                            discipline: widget.discipline,
                          );
                          if (t != null) setState(() => _category = t);
                        },
                      ),
                    ),
                  ),
                  if (profile != null)
                    FieldSection(
                      label:
                          profile == Profile.actual
                              ? 'GRADE · ACTUAL'
                              : 'GRADE · EXPECTED',
                      note: 'Tap the selected grade again to clear it',
                      child: GradeGrid(
                        value: _grade,
                        onChanged: (g) => setState(() => _grade = g),
                      ),
                    )
                  else
                    FieldSection(
                      label: 'GRADE',
                      child: Text(
                        'Switch to Actual or Expected to change a grade.',
                        style: TypeScale.caption.copyWith(color: p.text),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Space.sm),
            Row(
              spacing: Space.sm,
              children: [
                _Pill(
                  label: 'Remove',
                  onTap: _remove,
                  fill: Colors.transparent,
                  text: p.behind,
                  border: p.outline,
                ),
                Expanded(
                  child: _Pill(
                    label: 'Save',
                    onTap:
                        () => Navigator.pop(context, (
                          saved: _edited,
                          removed: false,
                        )),
                    fill: p.inverse,
                    text: p.onInverse,
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

/// A 54 px stadium: ink Save, or outlined Remove in the `behind` colour.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.onTap,
    required this.fill,
    required this.text,
    this.border,
  });

  final String label;
  final VoidCallback onTap;
  final Color fill, text;
  final Color? border;

  @override
  Widget build(BuildContext context) => Material(
    color: fill,
    shape: StadiumBorder(
      side: border == null ? BorderSide.none : BorderSide(color: border!),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 54),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Center(
            widthFactor: 1,
            child: Text(label, style: TypeScale.button.copyWith(color: text)),
          ),
        ),
      ),
    ),
  );
}
