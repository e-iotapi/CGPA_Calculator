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
import 'package:cgpa_calculator/features/settings/install_guide.dart';
import 'package:cgpa_calculator/script.dart';
import 'package:cgpa_calculator/shared/widgets/bottom_action.dart';
import 'package:cgpa_calculator/shared/widgets/circle_icon_button.dart';
import 'package:cgpa_calculator/shared/widgets/dashed_outline.dart';
import 'package:cgpa_calculator/shared/widgets/outlined_pill.dart';
import 'package:cgpa_calculator/shared/widgets/pointer_mark.dart';
import 'package:flutter/foundation.dart';
import 'package:cgpa_calculator/shared/widgets/confirm_dialog.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';

/// ERP → My Academics. A component link rather than a report, so a
/// signed-out user goes through SSO and still lands in the right place.
final erpMyAcademics = Uri.parse(
  'https://sis.erp.bits-pilani.ac.in/psc/sisprd/EMPLOYEE/SA/c/'
  'BITS_STD_CNT_LNK.BITS_STD_CNT_LNK.GBL',
);

/// Import from the ERP performance sheet: step 2 of setup, and the page the
/// Settings row opens. One implementation for both.
class ErpImportPage extends StatefulWidget {
  const ErpImportPage({super.key, this.onDone, this.installable});

  /// Set during setup: called once grades are in, or skipped. Without it
  /// the page is Settings' and pops when done.
  final VoidCallback? onDone;

  /// Whether to offer installing; by default, in a browser tab that is not
  /// the installed app already.
  final bool? installable;

  @override
  State<ErpImportPage> createState() => _ErpImportPageState();
}

/// A marked line per import stage, so a failure on a phone can be read off
/// chrome://inspect rather than guessed at.
void importLog(String stage) => debugPrint('[Pointer import] $stage');

class _ErpImportPageState extends State<ErpImportPage> {
  var _busy = false;

  /// What went wrong last time, shown on the page itself.
  String? _error;

  bool get _setup => widget.onDone != null;

  /// At the end of setup, after it has done something, never at first
  /// launch; and never inside the installed app.
  bool get _offerInstall =>
      _setup && (widget.installable ?? (kIsWeb && !isStandalone()));

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(behavior: SnackBarBehavior.floating, content: Text(msg)),
    );
  }

  void _finish() =>
      _setup ? widget.onDone!() : Navigator.of(context).maybePop();

  Future<void> _choose() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (await _import() && mounted) {
        importLog('saved');
        _toast('Imported from your ERP sheet');
        _finish();
      }
    } catch (e, st) {
      // No failure may leave a blank screen: the page stays, and says so.
      importLog('failed: $e\n$st');
      if (mounted) {
        setState(
          () =>
              _error =
                  'Something went wrong reading that sheet, and nothing was '
                  'changed. Try again, or enter grades by hand. ($e)',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// True once the sheet's grades are saved.
  Future<bool> _import() async {
    importLog('picking');
    String? json;
    try {
      json = await pickPdfText();
    } catch (e) {
      importLog('pdf unreadable: $e');
      if (mounted) _toast('Could not read that PDF. Is it the one from ERP?');
      return false;
    }
    if (json == null || !mounted) return false;
    importLog('read ${json.length} chars');
    final (:width, :items) = pdfTextFromJson(json);
    // The text is parsed from here on; let the raw copy go.
    json = null;
    importLog('parsing ${items.length} items');
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
    importLog('parsed ${sheet.rows.length} rows; planning');
    final box = Hive.box<Course>(coursesBoxName);
    final plan = planImport(sheet, box.toMap(), discipline: selecteddiscipline);
    importLog('previewing');
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
    importLog('applying');
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
    final body =
        'This sheet is for $names, 20$b batch. ${_setup ? 'Pointer will set '
                'that up instead, then import.' : 'Change your degree and batch '
                'in Settings, then import again. Changing them clears your '
                'grades.'}';
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (c) => AppDialog(
            title:
                _setup ? 'Use your sheet\'s degree?' : 'Set your degree first',
            body: body,
            actions: [
              DialogAction(
                _setup ? 'Cancel' : 'OK',
                onTap: () => Navigator.pop(c, false),
                ink: !_setup,
              ),
              if (_setup)
                DialogAction(
                  'Use it',
                  onTap: () => Navigator.pop(c, true),
                  ink: true,
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
            child: Stack(
              children: [
                ListView(
                  padding: EdgeInsets.fromLTRB(
                    Space.gutter,
                    Space.xxl,
                    Space.gutter,
                    _setup
                        ? BottomAction.heightOf(context, hasCaption: true)
                        : Space.xxl,
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
                                'done.',
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
                      OutlinedPill(
                        label: 'Open ERP',
                        trailing: Icons.open_in_new_rounded,
                        // A new tab: a half-finished setup is never lost.
                        onPressed: () => openUrl('$erpMyAcademics'),
                      ),
                    ]),
                    const SizedBox(height: Space.md),
                    if (_error != null) ...[
                      Semantics(
                        liveRegion: true,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                          decoration: BoxDecoration(
                            color: p.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: p.behind),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                size: 17,
                                color: p.behind,
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: body.copyWith(
                                    fontSize: 11.5,
                                    color: p.text,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: Space.md),
                    ],
                    _ChooseZone(
                      busy: _busy,
                      onTap: kIsWeb && !_busy ? _choose : null,
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
                    if (_offerInstall) ...[
                      const SizedBox(height: Space.md),
                      _InstallStrip(onInstall: () => offerInstall(context)),
                    ],
                  ],
                ),
                if (_setup)
                  BottomAction(
                    caption:
                        'You can import any time from Settings → Your data.',
                    // A plain link: most first-years have nothing to import.
                    child: TextButton(
                      onPressed: widget.onDone,
                      style: TextButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                      ),
                      child: Text(
                        'Skip — I will enter grades myself',
                        style: TypeScale.button.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: p.icon,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Keep Pointer on the home screen: one tap where the browser can prompt,
/// its own steps where it cannot. A dark card in either theme, so its text
/// colours are fixed.
class _InstallStrip extends StatefulWidget {
  const _InstallStrip({required this.onInstall});

  final VoidCallback onInstall;

  @override
  State<_InstallStrip> createState() => _InstallStripState();
}

class _InstallStripState extends State<_InstallStrip>
    with SingleTickerProviderStateMixin {
  late final _nudge = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4500),
  );

  static final _scale = TweenSequence<double>([
    TweenSequenceItem(tween: ConstantTween(1), weight: 76),
    TweenSequenceItem(tween: Tween(begin: 1, end: 1.035), weight: 7),
    TweenSequenceItem(tween: Tween(begin: 1.035, end: 1), weight: 7),
    TweenSequenceItem(tween: ConstantTween(1), weight: 10),
  ]);

  // In turns, for RotationTransition: 6 degrees.
  static const _deg = 6 / 360;
  static final _turn = TweenSequence<double>([
    TweenSequenceItem(tween: ConstantTween(0), weight: 80),
    TweenSequenceItem(tween: Tween(begin: 0, end: _deg), weight: 3),
    TweenSequenceItem(tween: Tween(begin: _deg, end: -_deg), weight: 6),
    TweenSequenceItem(tween: Tween(begin: -_deg, end: 0), weight: 6),
    TweenSequenceItem(tween: ConstantTween(0), weight: 5),
  ]);

  late final _scaled = _scale.animate(_nudge);
  late final _turned = _turn.animate(_nudge);

  /// Runs only while motion is allowed and the page is on top (UI_OPT O6.2).
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.disableAnimationsOf(context);
    final shown = ModalRoute.isCurrentOf(context) ?? true;
    if (still || !shown) {
      _nudge.stop();
      if (still) _nudge.value = 0;
    } else if (!_nudge.isAnimating) {
      _nudge.repeat();
    }
  }

  @override
  void dispose() {
    _nudge.dispose();
    super.dispose();
  }

  // Built once: the nudge scales and turns layers through transitions, so
  // nothing rebuilds per frame (UI_OPT O6.2).
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final card = Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 11, 11),
      decoration: BoxDecoration(
        color: p.navBackground,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: p.hero,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: PointerMark(color: p.onHero, size: 18),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Install Pointer',
                  style: TypeScale.body.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFF4F4EF),
                  ),
                ),
                Text(
                  'Own icon, full screen, works offline',
                  style: TypeScale.caption.copyWith(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFFB0B0A4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Space.sm),
          RotationTransition(
            turns: _turned,
            child: FilledButton(
              onPressed: widget.onInstall,
              style: FilledButton.styleFrom(
                backgroundColor: p.hero,
                foregroundColor: p.onHero,
                minimumSize: const Size(64, 36),
                fixedSize: const Size.fromHeight(36),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: const StadiumBorder(),
              ),
              child: Text(
                'Install',
                style: TypeScale.button.copyWith(fontSize: 12.5),
              ),
            ),
          ),
        ],
      ),
    );
    return RepaintBoundary(child: ScaleTransition(scale: _scaled, child: card));
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
        color: const Color(0xFF9CC9BA),
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
                        : kIsWeb
                        ? 'Drop your performance sheet'
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
                    kIsWeb ? 'or choose a file · PDF' : 'PDF',
                    style: TypeScale.caption.copyWith(
                      fontSize: 11.5,
                      color: p.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 12,
                        color: p.accent,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'Read on your device · never uploaded',
                          style: TypeScale.caption.copyWith(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: p.accent,
                          ),
                        ),
                      ),
                    ],
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
