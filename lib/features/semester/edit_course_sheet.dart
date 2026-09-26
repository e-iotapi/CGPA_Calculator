import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/grading/cgpa.dart';
import 'package:cgpa_calculator/core/models/course_names.dart';
import 'package:cgpa_calculator/core/storage/courses.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/semester/add_course_controller.dart';
import 'package:cgpa_calculator/features/semester/semester_controller.dart';
import 'package:cgpa_calculator/features/semester/widgets/course_fields.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

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
  return showModalBottomSheet<CourseEdit>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppPalette.of(context).background,
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
  } else if (edit.saved != null) {
    await saveCourse(edit.saved!);
  }
}

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
    final p = AppPalette.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: const Text('Remove this course?'),
            content: Text(
              '${widget.course.id} leaves ${semLabel(widget.course.sem)}, '
              'with its grades.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Keep'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text('Remove', style: TextStyle(color: p.behind)),
              ),
            ],
          ),
    );
    if (ok == true && mounted) {
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
          Space.gutter,
          0,
          Space.gutter,
          Space.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  Text(
                    displayTitle(c.id, c.title),
                    style: TypeScale.title.copyWith(color: p.text),
                  ),
                  Text(
                    '${c.id} · $cr credit${cr == '1' ? '' : 's'} · '
                    '${semLabel(c.sem)}',
                    style: TypeScale.caption.copyWith(color: p.textMuted),
                  ),
                  const SizedBox(height: Space.lg),
                  FieldSection(
                    label: 'COUNTS AS',
                    child: CategoryDropdown(
                      value: _category,
                      discipline: widget.discipline,
                      onChanged: (t) => setState(() => _category = t),
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
              children: [
                SizedBox(
                  height: 54,
                  child: OutlinedButton.icon(
                    onPressed: _remove,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Remove'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: p.behind,
                      textStyle: TypeScale.button,
                      side: BorderSide(color: p.behind),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(19),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: SizedBox(
                    height: 54,
                    child: FilledButton(
                      onPressed:
                          () => Navigator.pop(context, (
                            saved: _edited,
                            removed: false,
                          )),
                      style: FilledButton.styleFrom(
                        backgroundColor: p.inverse,
                        foregroundColor: p.onInverse,
                        textStyle: TypeScale.button,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(19),
                        ),
                      ),
                      child: const Text('Save'),
                    ),
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
