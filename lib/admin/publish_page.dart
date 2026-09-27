import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/catalog/catalog.dart';
import 'package:cgpa_calculator/core/catalog/publish.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:flutter/material.dart';

CatalogStore get _store => CatalogStore(roleStore!);

String _n(double d) =>
    d == d.roundToDouble() ? '${d.toInt()}' : d.toStringAsFixed(1);

/// Board `Publish`: the drafts as a diff in CGPA terms — credit changes
/// first, with a second confirm — then Publish (§11). It names courses,
/// never a headcount.
class PublishPage extends StatefulWidget {
  const PublishPage({super.key});

  @override
  State<PublishPage> createState() => _PublishPageState();
}

class _PublishPageState extends State<PublishPage> {
  bool _read = false;
  bool _showCosmetic = false;
  bool _busy = false;
  int _loads = 0;

  Future<void> _publish(
    Catalog next,
    CatalogDiff diff,
    List<CourseEdit> drafts,
  ) async {
    setState(() => _busy = true);
    final m = ScaffoldMessenger.of(context);
    try {
      await _store.publish(next, diff, drafts);
      useCatalog(next);
      m
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Published v${next.version}. Everyone gets it on their next '
              'open.',
            ),
          ),
        );
      setState(() {
        _read = false;
        _loads++;
      });
    } catch (e) {
      m
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(problem(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _draft() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _DraftSheet(),
    );
    if (saved == true) setState(() => _loads++);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Loaded<List<CourseEdit>>(
      key: ValueKey(_loads),
      load: _store.drafts,
      builder: (context, drafts, reload) {
        final live = catalog;
        final next = applyEdits(live, drafts);
        final diff = diffCatalog(live, next);
        final title = {for (final m in next.master) m.id: m.title};

        Widget line(String head, String body, {Color? tone}) => Padding(
          padding: const EdgeInsets.only(bottom: Space.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                head,
                style: TypeScale.body.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                body,
                style: TypeScale.caption.copyWith(
                  height: 1.4,
                  color: tone ?? p.textMuted,
                ),
              ),
            ],
          ),
        );

        return PageFrame(
          header: PageHeader(
            eyebrow:
                'DRAFT → LIVE · ${diff.count} CHANGE${diff.count == 1 ? '' : 'S'}',
            title: 'Publish catalogue',
          ),
          children: [
            Text(
              'Live is v${live.version}.',
              style: TypeScale.caption.copyWith(color: p.textMuted),
            ),
            const SizedBox(height: Space.sm),
            if (diff.credits.isNotEmpty) ...[
              Row(
                children: [
                  Expanded(
                    child: SectionLabel('Moves CGPAs · ${diff.credits.length}'),
                  ),
                  const TierTag('CONFIRM', strong: true),
                ],
              ),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final c in diff.credits)
                      line(
                        '${c.id} · ${c.title}',
                        'Credits ${_n(c.from)} → ${_n(c.to)}. The CGPA of '
                            'everyone holding a grade in it changes.',
                        tone: p.noticeTone.text,
                      ),
                  ],
                ),
              ),
            ],
            if (diff.retired.isNotEmpty) ...[
              SectionLabel('Retired · ${diff.retired.length}'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final c in diff.retired)
                      line(
                        '${c.id} · ${c.title}',
                        'Hidden from Add a course. Grades already held keep '
                            'counting, marked Retired.',
                      ),
                  ],
                ),
              ),
            ],
            if (diff.cosmetic.isNotEmpty) ...[
              const SizedBox(height: Space.sm),
              AppCard(
                onTap: () => setState(() => _showCosmetic = !_showCosmetic),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    line(
                      'Titles and default tags · ${diff.cosmetic.length}',
                      'Cosmetic. A category someone set by hand still wins.',
                    ),
                    if (_showCosmetic)
                      for (final c in diff.cosmetic)
                        Text('${c.id} · ${c.what}', style: TypeScale.caption),
                  ],
                ),
              ),
            ],
            if (diff.isEmpty)
              const Note('Nothing waiting. Draft a change to a course below.'),
            const Note(
              'Pointer names the courses, never a headcount: counting who is '
              'affected would mean reading everyone\'s grades.',
            ),
            if (diff.credits.isNotEmpty)
              CheckboxListTile(
                value: _read,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (v) => setState(() => _read = v ?? false),
                title: Text(
                  'I have read the ${diff.credits.length} credit '
                  'change${diff.credits.length == 1 ? '' : 's'}. They move '
                  'CGPAs.',
                  style: TypeScale.body,
                ),
              ),
            const SizedBox(height: Space.sm),
            PrimaryButton(
              label:
                  _busy
                      ? 'Publishing…'
                      : 'Publish ${diff.count} change${diff.count == 1 ? '' : 's'}',
              onPressed:
                  _busy || diff.isEmpty || (diff.credits.isNotEmpty && !_read)
                      ? null
                      : () => _publish(next, diff, drafts),
            ),
            const SizedBox(height: Space.sm),
            TextButton.icon(
              onPressed: _draft,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Draft a change to a course'),
            ),
            if (drafts.isNotEmpty) ...[
              const SectionLabel('Drafts'),
              for (final d in drafts)
                Text(
                  '${d.id} · ${title[d.id] ?? ''}',
                  style: TypeScale.caption.copyWith(color: p.textMuted),
                ),
            ],
          ],
        );
      },
    );
  }
}

/// One course's identity edit. Ids never change (§2): a corrected code is a
/// new course plus a retirement.
class _DraftSheet extends StatefulWidget {
  const _DraftSheet();

  @override
  State<_DraftSheet> createState() => _DraftSheetState();
}

class _DraftSheetState extends State<_DraftSheet> {
  final _id = TextEditingController();
  final _title = TextEditingController();
  final _credits = TextEditingController();
  bool? _retired;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _id.dispose();
    _title.dispose();
    _credits.dispose();
    super.dispose();
  }

  String get _code =>
      _id.text.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');

  void _lookup() {
    final m = catalog.master.where((m) => m.id == _code).firstOrNull;
    setState(() {
      _title.text = m?.title ?? '';
      _credits.text = m == null ? '' : _n(m.credits);
      _retired = m == null ? null : catalog.retired.contains(m.id);
    });
  }

  Future<void> _save() async {
    final m = catalog.master.where((m) => m.id == _code).firstOrNull;
    final title = _title.text.trim();
    final credits = double.tryParse(_credits.text.trim());
    if (_code.isEmpty) return setState(() => _error = 'Type a course code.');
    if (m == null && (title.isEmpty || credits == null)) {
      return setState(() => _error = 'A new course needs a title and credits.');
    }
    final e = CourseEdit(
      id: _code,
      title: title.isEmpty || title == m?.title ? null : title,
      credits: credits == null || credits == m?.credits ? null : credits,
      retired:
          m == null || _retired == catalog.retired.contains(m.id)
              ? null
              : _retired,
    );
    if (m != null && e.toMap().length == 1) {
      return setState(() => _error = 'Nothing changed.');
    }
    setState(() => _busy = true);
    try {
      await _store.saveDraft(
        e,
        campus: campusOfAddress(roleStore!.me) ?? 'all',
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (err) {
      if (mounted) setState(() => _error = problem(err));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final known = catalog.master.any((m) => m.id == _code);
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
          Text('Draft a change', style: TypeScale.title),
          const SizedBox(height: Space.sm),
          AppTextField(
            controller: _id,
            label: 'Course code',
            hint: 'CS F211',
            onChanged: (_) => _lookup(),
          ),
          const SizedBox(height: Space.sm),
          AppTextField(controller: _title, label: 'Title'),
          const SizedBox(height: Space.sm),
          AppTextField(controller: _credits, label: 'Credits', number: true),
          if (known)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _retired ?? false,
              onChanged: (v) => setState(() => _retired = v),
              title: const Text('Retired'),
              subtitle: const Text(
                'Hidden from Add a course; grades held keep counting.',
              ),
            ),
          Text(
            known
                ? 'Codes never change. To correct one, add the right code as '
                    'a new course and retire this one.'
                : _code.isEmpty
                ? ''
                : 'Not in the catalogue: this adds it.',
            style: TypeScale.caption.copyWith(color: p.textMuted),
          ),
          if (_error != null)
            Text(_error!, style: TypeScale.caption.copyWith(color: p.behind)),
          const SizedBox(height: Space.md),
          PrimaryButton(
            label: _busy ? 'Saving…' : 'Save draft',
            onPressed: _busy ? null : _save,
          ),
        ],
      ),
    );
  }
}
