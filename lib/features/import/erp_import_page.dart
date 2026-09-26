import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/models/programmes.dart';
import 'package:cgpa_calculator/core/platform/browser.dart';
import 'package:cgpa_calculator/core/storage/courses.dart';
import 'package:cgpa_calculator/core/storage/stats.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/import/import_plan.dart';
import 'package:cgpa_calculator/features/import/import_preview.dart';
import 'package:cgpa_calculator/features/import/performance_sheet.dart';
import 'package:cgpa_calculator/script.dart';
import 'package:cgpa_calculator/shared/widgets/circle_icon_button.dart';
import 'package:cgpa_calculator/shared/widgets/dashed_outline.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:url_launcher/url_launcher.dart';

/// ERP → My Academics. A navigation collection rather than a report, so a
/// signed-out user goes through SSO and still lands in the right place.
final erpMyAcademics = Uri.parse(
  'https://sis.erp.bits-pilani.ac.in/psc/sisprd/EMPLOYEE/SA/c/'
  'NUI_FRAMEWORK.PT_AGSTARTPAGE_NUI.GBL'
  '?CONTEXTIDPARAMS=TEMPLATE_ID%3aPTPPNAVCOL'
  '&scname=ADMN_MY_ACADEMICS&PTPPB_GROUPLET_ID=MY_ACADEMICS'
  '&CRefName=ADMN_NAVCOLL_2',
);

/// Import from the ERP performance sheet: step 2 of setup, and the page the
/// Settings row opens. One implementation for both.
class ErpImportPage extends StatefulWidget {
  const ErpImportPage({super.key, this.onDone});

  /// Set during setup: called once grades are in, or skipped. Without it
  /// the page is Settings' and pops when done.
  final VoidCallback? onDone;

  @override
  State<ErpImportPage> createState() => _ErpImportPageState();
}

class _ErpImportPageState extends State<ErpImportPage> {
  var _busy = false;

  bool get _setup => widget.onDone != null;

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(behavior: SnackBarBehavior.floating, content: Text(msg)),
    );
  }

  void _finish() =>
      _setup ? widget.onDone!() : Navigator.of(context).maybePop();

  Future<void> _choose() async {
    setState(() => _busy = true);
    try {
      if (await _import() && mounted) {
        _toast('Imported from your ERP sheet');
        _finish();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// True once the sheet's grades are saved.
  Future<bool> _import() async {
    final String? json;
    try {
      json = await pickPdfText();
    } catch (_) {
      if (mounted) _toast('Could not read that PDF. Is it the one from ERP?');
      return false;
    }
    if (json == null || !mounted) return false;
    final (:width, :items) = pdfTextFromJson(json);
    var sheet = parsePerformanceSheet(
      items,
      pageWidth: width,
      batch: batch,
      discipline: selecteddiscipline,
    );
    if (sheet.rows.isEmpty) {
      _toast('No courses found. Use the Performance Sheet from ERP.');
      return false;
    }
    final d = sheet.discipline, b = sheet.batch;
    if ((d != null && d != selecteddiscipline) || (b != null && b != batch)) {
      if (!await _adoptSheetDegree(d ?? selecteddiscipline, b ?? batch)) {
        return false;
      }
      sheet = parsePerformanceSheet(
        items,
        pageWidth: width,
        batch: batch,
        discipline: selecteddiscipline,
      );
    }
    if (!mounted) return false;
    final box = Hive.box<Course>(coursesBoxName);
    final plan = planImport(sheet, box.toMap(), discipline: selecteddiscipline);
    final needs = sheet.degreeNeeds(selecteddiscipline);
    final newNeeds = needs != null && needs != degreeNeeds;
    if (!await showImportPreview(
      context,
      sheet: sheet,
      plan: plan,
      newNeeds: newNeeds,
    )) {
      return false;
    }
    if (newNeeds) await setDegreeNeeds(needs);
    await box.deleteAll(plan.remove);
    await box.putAll(plan.put);
    for (final c in plan.add) {
      await box.add(c);
    }
    await box.flush();
    return true;
  }

  /// The sheet is for another degree or batch. During setup nothing is lost
  /// by switching to it; from Settings it would clear grades, so the student
  /// changes it there on purpose.
  Future<bool> _adoptSheetDegree(String d, int b) async {
    final names = [
      d.substring(0, 2),
      d.substring(2, 4),
    ].where((h) => h != '--').map(programmeName).join(' + ');
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: Text(
              _setup ? 'Use your sheet\'s degree?' : 'Set your degree first',
            ),
            content: Text(
              _setup
                  ? 'This sheet is for $names, 20$b batch. Pointer will set '
                      'that up instead, then import.'
                  : 'This sheet is for $names, 20$b batch. Change your degree '
                      'and batch in Settings, then import again. Changing '
                      'them clears your grades.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(_setup ? 'Cancel' : 'OK'),
              ),
              if (_setup)
                TextButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('Use it'),
                ),
            ],
          ),
    );
    if (ok != true) return false;
    selecteddiscipline = d;
    batch = b;
    erase = 1;
    await setdis();
    await initializeCourses();
    erase = 0;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final body = TypeScale.body.copyWith(
      fontSize: 12.5,
      fontWeight: FontWeight.w500,
      height: 1.45,
      color: p.textMuted,
    );
    final label = TypeScale.label.copyWith(color: p.textMuted);
    final strong = body.copyWith(fontWeight: FontWeight.w700, color: p.text);

    Widget step(int n, List<InlineSpan> text) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.only(top: 1),
          decoration: BoxDecoration(color: p.inverse, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(
            '$n',
            style: TypeScale.caption.copyWith(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: p.onInverse,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text.rich(TextSpan(children: text), style: body)),
      ],
    );

    Widget card(List<Widget> children) => Container(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );

    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                Space.xxl,
                Space.gutter,
                Space.xxl,
              ),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _setup ? 'SETUP · 2 OF 2' : 'YOUR DATA',
                            style: label,
                          ),
                          const SizedBox(height: 3),
                          Semantics(
                            header: true,
                            child: Text(
                              'Bring your grades in',
                              style: TypeScale.title.copyWith(
                                fontSize: 27,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1,
                                height: 1.05,
                                color: p.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: Space.md),
                    CircleIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Back',
                      size: 44,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
                const SizedBox(height: Space.md),
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Pointer reads your ERP '),
                      TextSpan(text: 'performance sheet', style: strong),
                      const TextSpan(
                        text:
                            ' and fills in every semester you have already '
                            'done. It is the one with pending courses at the '
                            'bottom, not the grade card.',
                      ),
                    ],
                  ),
                  style: body,
                ),
                const SizedBox(height: Space.md),
                card([
                  Text('HOW TO GET IT', style: label),
                  const SizedBox(height: 11),
                  step(1, [
                    const TextSpan(text: 'In ERP: '),
                    TextSpan(text: 'My Academics', style: strong),
                    const TextSpan(text: ' → '),
                    TextSpan(text: 'Academic Reports', style: strong),
                    const TextSpan(text: ' → '),
                    TextSpan(text: 'Performance Reports', style: strong),
                    const TextSpan(text: '.'),
                  ]),
                  const SizedBox(height: 11),
                  step(2, [
                    const TextSpan(
                      text:
                          'Save it as a PDF — Print → Save as PDF if there is '
                          'no download button.',
                    ),
                  ]),
                  const SizedBox(height: 11),
                  step(3, [
                    const TextSpan(
                      text:
                          'Choose it below. Nothing is saved until you have '
                          'seen what changes.',
                    ),
                  ]),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    // A new tab: a half-finished setup is never lost.
                    onPressed:
                        () => launchUrl(
                          erpMyAcademics,
                          mode: LaunchMode.externalApplication,
                          webOnlyWindowName: '_blank',
                        ),
                    iconAlignment: IconAlignment.end,
                    icon: Icon(
                      Icons.open_in_new_rounded,
                      size: 15,
                      color: p.text,
                    ),
                    label: Text(
                      'Open My Academics in ERP',
                      style: TypeScale.button.copyWith(
                        fontSize: 12.5,
                        color: p.text,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      side: BorderSide(color: p.text, width: 1.5),
                      shape: const StadiumBorder(),
                    ),
                  ),
                ]),
                const SizedBox(height: Space.md),
                _ChooseZone(
                  busy: _busy,
                  onTap: kIsWeb && !_busy ? _choose : null,
                ),
                const SizedBox(height: Space.md),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 15,
                        color: p.accent,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Read in your browser. The file is never uploaded, '
                          'and your ID number is not stored or shared.',
                          style: body.copyWith(fontSize: 11, color: p.text),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Space.md),
                card([
                  Text('WHAT IT FILLS IN', style: label),
                  const SizedBox(height: 7),
                  for (final line in const [
                    'Grades for every completed course, semester by semester',
                    'Courses still running, placed in the right semester',
                    'Elective counts, and a CGPA check against your sheet',
                  ]) ...[
                    Text(
                      line,
                      style: body.copyWith(fontSize: 12, color: p.text),
                    ),
                    const SizedBox(height: 5),
                  ],
                ]),
                if (_setup) ...[
                  const SizedBox(height: Space.lg),
                  // A plain link: most first-years have nothing to import.
                  Center(
                    child: TextButton(
                      onPressed: widget.onDone,
                      child: Text(
                        'Skip — I will enter grades myself',
                        style: TypeScale.button.copyWith(
                          fontSize: 13,
                          color: p.text,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    'You can import any time from Settings → Your data.',
                    textAlign: TextAlign.center,
                    style: TypeScale.caption.copyWith(
                      fontSize: 10.5,
                      color: p.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The dashed area that opens the file picker.
class _ChooseZone extends StatelessWidget {
  const _ChooseZone({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Semantics(
      button: true,
      label: 'Choose your performance sheet, PDF',
      excludeSemantics: true,
      child: DashedOutline(
        color: p.accent,
        radius: 22,
        width: 2,
        child: Material(
          color: p.hero.withValues(alpha: 0.34),
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    alignment: Alignment.center,
                    child:
                        busy
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : Icon(
                              Icons.upload_rounded,
                              size: 21,
                              color: p.text,
                            ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    busy
                        ? 'Reading your sheet…'
                        : 'Choose your performance sheet',
                    textAlign: TextAlign.center,
                    style: TypeScale.body.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: p.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    onTap == null && !busy
                        ? 'Works in the web app'
                        : 'PDF · read on this device',
                    style: TypeScale.caption.copyWith(
                      fontSize: 11.5,
                      color: p.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
