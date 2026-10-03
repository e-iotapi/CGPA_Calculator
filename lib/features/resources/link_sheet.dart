import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/resources/resource.dart';
import 'package:cgpa_calculator/features/resources/resources_page.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:flutter/material.dart';

/// Adds or edits a link. [course] makes it a course link (a CR's, or a
/// president adding for a course); [existing] edits in place. [department]
/// is what the rollup is checked against.
Future<bool> editLink(
  BuildContext context, {
  required String campus,
  required String dept,
  required List<Resource> department,
  String? course,
  String? actingFor,
  Resource? existing,
  bool fixing = false,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder:
        (_) => LinkSheet(
          campus: campus,
          dept: dept,
          department: department,
          course: course,
          actingFor: actingFor,
          existing: existing,
          fixing: fixing,
        ),
  );
  return saved == true;
}

/// An http or https address with a host: any website, not a fixed list.
bool isWebLink(String url) {
  final u = Uri.tryParse(url.trim());
  return u != null &&
      (u.scheme == 'https' || u.scheme == 'http') &&
      u.host.contains('.');
}

class LinkSheet extends StatefulWidget {
  const LinkSheet({
    super.key,
    required this.campus,
    required this.dept,
    required this.department,
    this.course,
    this.actingFor,
    this.existing,
    this.fixing = false,
  });

  final String campus, dept;
  final List<Resource> department;
  final String? course, actingFor;
  final Resource? existing;
  final bool fixing;

  @override
  State<LinkSheet> createState() => LinkSheetState();
}

class LinkSheetState extends State<LinkSheet> {
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _url = TextEditingController(text: widget.existing?.url);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final url = _url.text.trim();
    if (title.isEmpty) return setState(() => _error = 'Give it a name.');
    // Any website: an article is as good as a Drive folder. A bad link is
    // what the Reported tab is for.
    if (!isWebLink(url)) {
      return setState(() => _error = 'Paste a web link, starting https://.');
    }
    setState(() => _busy = true);
    try {
      final e = widget.existing;
      if (e == null) {
        final c = widget.course;
        await resourceStore!.add(
          Resource(
            id: '',
            title: title,
            url: url,
            campus: widget.campus,
            department: widget.dept,
            scope: c == null ? 'department' : 'course',
            courseIds: c == null ? const [] : [c],
            pinnedToDepartment:
                c != null && shouldRollUp(widget.department, url),
          ),
          actingFor: widget.actingFor,
        );
      } else {
        await resourceStore!.update(
          e,
          e.copyWith(title: title, url: url),
          widget.fixing
              ? 'Fixed the reported link “$title”'
              : 'Edited “$title”',
          actingFor: widget.actingFor,
          closeFlag: widget.fixing,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (err) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = problem(err);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final head =
        widget.fixing
            ? 'Fix the link'
            : widget.existing != null
            ? 'Edit link'
            : 'Add a link${widget.course == null ? '' : ' to ${widget.course}'}';
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Space.gutter,
        Space.lg,
        Space.gutter,
        MediaQuery.viewInsetsOf(context).bottom + Space.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(head, style: TypeScale.title),
          const SizedBox(height: Space.sm),
          AppTextField(
            controller: _title,
            label: 'Name',
            hint: 'Past papers — all years',
          ),
          const SizedBox(height: Space.sm),
          AppTextField(controller: _url, label: 'Link', hint: 'https://…'),
          if (widget.existing?.rolledUp ?? false)
            Text(
              'One link, listed twice — editing it here changes it on '
              '${widget.existing!.fromCourse} as well.',
              style: TypeScale.caption.copyWith(color: p.textMuted),
            ),
          if (widget.fixing)
            Text(
              'Saving closes its reports. Both are logged.',
              style: TypeScale.caption.copyWith(color: p.textMuted),
            ),
          if (_error != null)
            Text(_error!, style: TypeScale.caption.copyWith(color: p.behind)),
          const SizedBox(height: Space.md),
          PrimaryButton(
            label: _busy ? 'Saving…' : 'Save',
            onPressed: _busy ? null : _save,
          ),
        ],
      ),
    );
  }
}
