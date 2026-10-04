import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/resources/resource.dart';
import 'package:cgpa_calculator/features/contribute/contribute_page.dart';
import 'package:cgpa_calculator/features/resources/link_sheet.dart';
import 'package:cgpa_calculator/features/resources/resources_page.dart';
import 'package:cgpa_calculator/features/setup/campus_pick_page.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/bottom_action.dart';
import 'package:cgpa_calculator/shared/widgets/notice.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:flutter/material.dart';

/// Board `ContributeEdit`: change the name or the link of one of my links.
/// No delete: a president removes a link.
class EditPage extends StatefulWidget {
  const EditPage({super.key, required this.id});
  final String id;

  @override
  State<EditPage> createState() => _EditPageState();
}

class _EditPageState extends State<EditPage> {
  final _title = TextEditingController(), _url = TextEditingController();
  bool _filled = false, _busy = false;
  String? _titleError, _urlError, _error;

  @override
  void dispose() {
    _title.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _save(Resource r) async {
    final title = _title.text.trim(), url = _url.text.trim();
    setState(() {
      _titleError = title.isEmpty ? 'Give the link a name.' : null;
      _urlError = isWebLink(url) ? null : 'Paste a full web address.';
      _error = null;
    });
    if (_titleError != null || _urlError != null) return;
    setState(() => _busy = true);
    try {
      await resourceStore!.updateOwn(r.copyWith(title: title, url: url));
      if (mounted) Navigator.of(context).maybePop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = problem(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final campus = viewCampus();
    const header = PageHeader(eyebrow: 'CONTRIBUTE', title: 'Edit link');
    final store = resourceStore;
    if (store == null || campus == null) {
      return const PageFrame(header: header, children: [Note('Sign in to edit.')]);
    }
    return Loaded<List<Resource>>(
      cacheKey: mineKey(campus),
      load: () => store.mine(campus),
      peek: () => store.peekMine(campus),
      builder: (context, all, _) {
        final r = all.where((x) => x.id == widget.id).firstOrNull;
        if (r == null || r.removed) {
          return const PageFrame(
            header: header,
            children: [Note('This link is no longer yours to edit.')],
          );
        }
        if (!_filled) {
          _filled = true;
          _title.text = r.title;
          _url.text = r.url;
        }
        return PageFrame(
          header: header,
          bottom: BottomAction(
            child: PrimaryButton(
              label: _busy ? 'Saving…' : 'Save',
              onPressed: _busy ? null : () => _save(r),
            ),
          ),
          children: [
            AppTextField(
              controller: _title,
              label: 'Title',
              labelAbove: true,
              fill: AppPalette.of(context).surface,
              error: _titleError,
            ),
            const SizedBox(height: Space.sm),
            AppTextField(
              controller: _url,
              label: 'URL',
              hint: 'https://',
              labelAbove: true,
              fill: AppPalette.of(context).surface,
              error: _urlError,
            ),
            if (_error != null) ...[
              const SizedBox(height: Space.sm),
              Notice(warning: true, text: TextSpan(text: _error)),
            ],
            const Note(
              'You can edit your links but not delete them. To remove one, '
              'ask an approver.',
            ),
          ],
        );
      },
    );
  }
}
