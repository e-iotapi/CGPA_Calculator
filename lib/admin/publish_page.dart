import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/cache/cache_first.dart';
import 'package:cgpa_calculator/core/catalog/catalog.dart';
import 'package:cgpa_calculator/core/catalog/publish.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/bottom_action.dart';
import 'package:cgpa_calculator/shared/widgets/card_row.dart';
import 'package:cgpa_calculator/shared/widgets/confirm_dialog.dart';
import 'package:cgpa_calculator/shared/widgets/outlined_pill.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:cgpa_calculator/shared/widgets/tag_badge.dart';
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

  /// A confirm step before every publish (BUG-48: it used to run at once).
  Future<void> _confirmAndPublish(
    Catalog next,
    CatalogDiff diff,
    List<CourseEdit> drafts,
  ) async {
    final ok = await confirmDialog(
      context,
      title: 'Publish v${next.version}?',
      body:
          '${diff.count} change${diff.count == 1 ? '' : 's'} go live for '
          'everyone on their next open.',
      action: 'Publish',
    );
    if (ok && mounted) await _publish(next, diff, drafts);
  }

  Future<void> _draft() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _DraftSheet(),
    );
    if (saved == true) setState(() => _loads++);
  }

  String get _draftsKey => 'last|drafts|${roleStore!.me}';

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Loaded<List<CourseEdit>>(
      cacheKey: 'publish-drafts',
      key: ValueKey(_loads),
      load: remembered(
        _draftsKey,
        _store.drafts,
        (v) => [for (final e in v) e.toMap()],
      ),
      peek:
          () => peekCache<List<CourseEdit>>(
            _draftsKey,
            (o) => [for (final m in o as List) CourseEdit.fromMap(m as Map)],
          ),
      // Last list: actions wait for the fresh one.
      gated: (context, drafts, reload, saved) {
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

        final label = TypeScale.label.copyWith(color: p.textMuted);
        final n = diff.credits.length;
        return PageFrame(
          header: PageHeader(
            eyebrow:
                'DRAFT → LIVE · ${diff.count} CHANGE${diff.count == 1 ? '' : 'S'}',
            title: 'Publish catalogue',
          ),
          bottom: BottomAction(
            child: PrimaryButton(
              label:
                  _busy
                      ? 'Publishing…'
                      : 'Publish ${diff.count} change${diff.count == 1 ? '' : 's'}',
              onPressed:
                  saved || _busy || diff.isEmpty || (n > 0 && !_read)
                      ? null
                      : () => _confirmAndPublish(next, diff, drafts),
            ),
          ),
          children: [
            Text(
              'Live is v${live.version}.',
              style: TypeScale.caption.copyWith(color: p.textMuted),
            ),
            const SizedBox(height: Space.sm),
            if (n > 0) ...[
              AppCard(
                color: p.noticeTone.fill,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'MOVES CGPAs · $n',
                            style: label.copyWith(color: p.noticeTone.text),
                          ),
                        ),
                        const TagBadge('CONFIRM', tone: TagTone.confirm),
                      ],
                    ),
                    const SizedBox(height: Space.sm),
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
              const SizedBox(height: Space.sm),
            ],
            if (diff.retired.isNotEmpty) ...[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('RETIRED · ${diff.retired.length}', style: label),
                    const SizedBox(height: Space.sm),
                    for (final c in diff.retired)
                      line(
                        '${c.id} · ${c.title}',
                        'Hidden from Add a course. Grades already held keep '
                            'counting, marked Retired.',
                      ),
                  ],
                ),
              ),
              const SizedBox(height: Space.sm),
            ],
            if (diff.added.isNotEmpty) ...[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('NEW COURSES · ${diff.added.length}', style: label),
                    const SizedBox(height: Space.sm),
                    for (final c in diff.added)
                      line(
                        '${c.id} · ${c.title}',
                        'Joins Add a course and the catalogue Pointer knows.',
                      ),
                  ],
                ),
              ),
              const SizedBox(height: Space.sm),
            ],
            if (diff.cosmetic.isNotEmpty) ...[
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CardRow(
                      title:
                          'Titles and default tags · ${diff.cosmetic.length}',
                      subtitle:
                          'Cosmetic. A category someone set by hand still '
                          'wins.',
                      trailing: Icon(
                        _showCosmetic
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: p.textMuted,
                      ),
                      onTap:
                          () => setState(() => _showCosmetic = !_showCosmetic),
                    ),
                    if (_showCosmetic)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(15, 0, 15, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final c in diff.cosmetic)
                              Text(
                                '${c.id} · ${c.what}',
                                style: TypeScale.caption,
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: Space.sm),
            ],
            if (diff.isEmpty)
              const Note('Nothing waiting. Draft a change below.'),
            const Note(
              'Pointer names the courses, never a headcount: counting who is '
              'affected would mean reading everyone\'s grades.',
            ),
            if (n > 0)
              _ReadRow(
                value: _read,
                text:
                    'I have read the $n credit change${n == 1 ? '' : 's'}. '
                    'They move CGPAs.',
                onChanged: (v) => setState(() => _read = v),
              ),
            const SizedBox(height: Space.sm),
            // Hugs its label; OutlinedPill itself fills the width it gets.
            Align(
              alignment: Alignment.centerLeft,
              child: IntrinsicWidth(
                child: OutlinedPill(
                  label: 'Draft a change',
                  onPressed: saved ? null : _draft,
                ),
              ),
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

/// The confirm row: a 22 px box and the sentence, 44 tall to tap.
class _ReadRow extends StatelessWidget {
  const _ReadRow({
    required this.value,
    required this.text,
    required this.onChanged,
  });
  final bool value;
  final String text;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Semantics(
      checked: value,
      label: text,
      excludeSemantics: true,
      onTap: () => onChanged(!value),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(Radii.check),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: value ? p.inverse : null,
                  borderRadius: BorderRadius.circular(Radii.check),
                  border:
                      value ? null : Border.all(color: p.textMuted, width: 1.5),
                ),
                child:
                    value
                        ? Icon(
                          Icons.check_rounded,
                          size: 15,
                          color: p.onInverse,
                        )
                        : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: TypeScale.body.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
    if (m == null) {
      final err = newCourseError(_code, credits!, catalog);
      if (err != null) return setState(() => _error = err);
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
