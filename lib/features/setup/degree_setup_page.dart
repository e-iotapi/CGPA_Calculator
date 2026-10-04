import 'package:cgpa_calculator/admin/widgets.dart' show ScopeChip;
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/auth_util.dart';
import 'package:cgpa_calculator/core/models/elective.dart';
import 'package:cgpa_calculator/core/models/programmes.dart';
import 'package:cgpa_calculator/core/storage/seed.dart';
import 'package:cgpa_calculator/features/import/erp_import_page.dart';
import 'package:cgpa_calculator/features/setup/programme_pick_page.dart'
    hide CodeBadge;
import 'package:cgpa_calculator/script.dart' as app;
import 'package:cgpa_calculator/sync.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart'
    show PrimaryButton;
import 'package:cgpa_calculator/shared/widgets/bottom_action.dart';
import 'package:cgpa_calculator/shared/widgets/code_badge.dart';
import 'package:cgpa_calculator/shared/widgets/dashed_outline.dart';
import 'package:cgpa_calculator/shared/widgets/notice.dart';
import 'package:cgpa_calculator/shared/widgets/pill_button.dart';
import 'package:cgpa_calculator/shared/short_email.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce/hive.dart';

/// What a discipline seeds: core courses, the semesters they span, and
/// their credits.
({int courses, int semesters, double credits}) seedSummary(
  String discipline,
  int year,
) {
  final seeded = [
    for (final c in seedCourses(discipline, chartRows(year % 100)))
      if (c.elective == Elective.cdc1.tag || c.elective == Elective.cdc2.tag) c,
  ];
  return (
    courses: seeded.length,
    semesters: {for (final c in seeded) c.sem}.length,
    credits: seeded.fold(0.0, (s, c) => s + c.credits),
  );
}

/// Whether [code]'s own core has no chart rows for [year] — a programme
/// with no catalogue yet for this batch (BUG-08).
bool _hasNoChart(String code, int year) {
  final msc = programmeFor(code)?.isMsc ?? false;
  return seedSummary(msc ? '$code--' : '--$code', year).courses == 0;
}

/// First run, step 1 of 2: campus and batch from the sign-in address, then
/// the one question the address cannot answer: what the student reads.
/// Campus and batch are final once set: shared by owner setup.
Future<void> saveCampusAndBatch(Campus campus, int year) async {
  app.campus = campus;
  app.batch = year % 100;
  final box = await Hive.openBox('settingsBox');
  await box.put('campus', campus.name);
  await box.put('batch', app.batch);
}

/// The one-time setup: campus, batch and degree, then the starting courses.
class DegreeSetupPage extends StatefulWidget {
  const DegreeSetupPage({super.key, required this.email, required this.onDone});

  final String? email;

  /// Once the degree is seeded and the import is done or skipped.
  final VoidCallback onDone;

  @override
  State<DegreeSetupPage> createState() => _DegreeSetupPageState();
}

class _DegreeSetupPageState extends State<DegreeSetupPage> {
  late final BitsAddress _address = parseBitsAddress(widget.email);
  late Campus? _campus = _address.campus;
  late final _year = TextEditingController(
    text: _address.year?.toString() ?? '',
  );

  /// Campus and batch are final once read from the address (ARCHITECTURE.md
  /// §11); they are asked only when the address has neither, as an owner's
  /// non-BITS account does.
  late final bool _asks = _campus == null || _address.year == null;

  var _dual = false;
  String? _first, _second;
  var _busy = false;
  var _show2p2Notice = false;

  /// Higher degrees and PhDs are never dual.
  bool get _asksDual =>
      _address.level != DegreeLevel.higher && _address.level != DegreeLevel.phd;

  int? get _yearValue {
    final y = int.tryParse(_year.text);
    return y != null && yearInRange(y) ? y : null;
  }

  /// "B3A7", "--A7", "B3--"; null until every pick is made.
  String? get _discipline {
    if (_dual) {
      return _first == null || _second == null ? null : '$_first$_second';
    }
    final p = _first;
    if (p == null) return null;
    return programmeFor(p)?.isMsc ?? false ? '$p--' : '--$p';
  }

  @override
  void dispose() {
    _year.dispose();
    super.dispose();
  }

  Future<void> _pick({required bool first}) async {
    final all = programmesAt(_campus);
    final options = [
      for (final p in all)
        if (!_dual || (first ? p.isMsc : !p.isMsc && p.code != 'A5')) p,
    ];
    final where = _campus?.label.toUpperCase();
    final heading = [
      // Matches Settings' own "Discipline"/"Dual degree" terms (BUG-08: the
      // old "FIRST"/"SECOND DEGREE" headings read as if whichever was
      // picked first is stored first, when the M.Sc. half always is).
      !_dual ? 'YOUR PROGRAMME' : (first ? 'DUAL DEGREE' : 'DISCIPLINE'),
      if (where != null) where,
    ].join(' · ');
    final elsewhere = [
      for (final p in programmes)
        if (!all.contains(p) && (p.campuses?.isNotEmpty ?? false)) p,
    ];
    final year = _yearValue ?? 2000 + app.batch;
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder:
            (_) => ProgrammePickPage(
              heading: heading,
              options: options,
              selected: first ? _first : _second,
              trailing: (p) {
                final n =
                    seedSummary(
                      p.isMsc ? '${p.code}--' : '--${p.code}',
                      year,
                    ).semesters;
                return n == 0 ? 'No catalogue yet' : '$n sem listed';
              },
              note:
                  _campus == null || elsewhere.isEmpty
                      ? null
                      : '${_count(options.length)} run at ${_campus!.label}. '
                          '${elsewhere.map((p) => '${p.code} ${p.name}').join(', ')} '
                          '${elsewhere.length == 1 ? 'runs' : 'run'} elsewhere.',
            ),
      ),
    );
    if (code == null || !mounted) return;
    setState(() => first ? _first = code : _second = code);
  }

  Future<void> _setUp() async {
    final d = _discipline, y = _yearValue;
    if (d == null || y == null || _campus == null) return;
    setState(() => _busy = true);
    await saveCampusAndBatch(_campus!, y);
    app.selecteddiscipline = d;
    // A fresh profile has nothing to lose: seed from clean.
    app.erase = 1;
    await app.setdis();
    await app.initializeCourses();
    app.erase = 0;
    // Push now rather than trust the debounced watcher: Skip finishes in
    // one tap, and a reload straight after can tear the page down before an
    // unload-time push completes, losing the whole setup (BUG-43).
    await Sync.push();
    if (!mounted) return;
    setState(() => _busy = false);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (c) => ErpImportPage(
              onDone: () {
                Navigator.of(c).pop();
                widget.onDone();
              },
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final label = TypeScale.label.copyWith(color: p.textMuted);
    final body = TypeScale.body.copyWith(
      fontSize: 12.5,
      fontWeight: FontWeight.w500,
      height: 1.45,
      color: p.textMuted,
    );

    Widget card(List<Widget> children, {Color? color}) => Container(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
      decoration: BoxDecoration(
        color: color ?? p.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );

    final d = _discipline, y = _yearValue;
    final picked = d != null && y != null && _campus != null;
    // A picked programme with nothing charted for this batch: setting up
    // would silently add nothing for it (BUG-08), so warn; setup still runs.
    final noChart = [
      if (picked) ...[
        if (_first != null && _hasNoChart(_first!, y)) _first!,
        if (_second != null && _hasNoChart(_second!, y)) _second!,
      ],
    ];
    final ready = picked;
    final adds = ready ? seedSummary(d, y) : null;
    final setupName = [
      if (d != null) ...[d.substring(0, 2), d.substring(2)],
    ].where((h) => h != '--').join(' ');

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
                    BottomAction.heightOf(context, hasCaption: true),
                  ),
                  children: [
                    Text('ONE-TIME SETUP', style: label),
                    const SizedBox(height: 3),
                    Semantics(
                      header: true,
                      child: Text(
                        'Your degree',
                        style: TypeScale.title.copyWith(
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                          height: 1.05,
                          color: p.text,
                        ),
                      ),
                    ),
                    const SizedBox(height: Space.sm),
                    Text(
                      _asksDual
                          ? 'Campus and batch come from your BITS address. One '
                              'question left: what you are reading.'
                          : 'Campus and batch come from your BITS address. Pick '
                              'what you are reading.',
                      style: body,
                    ),
                    const SizedBox(height: Space.md),
                    card([
                      Text(
                        _asks ? 'CAMPUS AND BATCH' : 'FROM YOUR SIGN-IN',
                        style: label,
                      ),
                      if (widget.email != null)
                        Text(
                          shortEmail(widget.email!),
                          overflow: TextOverflow.ellipsis,
                          style: body.copyWith(color: p.text),
                        ),
                      const SizedBox(height: Space.sm),
                      if (!_asks)
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            ScopeChip(
                              _campus!.label,
                              icon: Icons.place_outlined,
                              height: 32,
                            ),
                            ScopeChip(
                              '${_yearValue ?? _year.text} batch',
                              icon: Icons.calendar_today_rounded,
                              height: 32,
                            ),
                          ],
                        )
                      else ...[
                        if (_campus == null && widget.email != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Pointer could not tell your campus from this '
                              'address. Which is it?',
                              style: body.copyWith(fontSize: 11.5),
                            ),
                          ),
                        Wrap(
                          spacing: 5,
                          runSpacing: 5,
                          children: [
                            for (final c in Campus.values)
                              _Pill(
                                c.label,
                                selected: c == _campus,
                                onTap:
                                    () => setState(() {
                                      _campus = c;
                                      // A programme not run here is not kept.
                                      final here = programmesAt(
                                        c,
                                      ).map((p) => p.code);
                                      if (!here.contains(_first)) {
                                        _first = null;
                                      }
                                      if (!here.contains(_second)) {
                                        _second = null;
                                      }
                                    }),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: 150,
                          child: TextField(
                            controller: _year,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                            onChanged: (_) => setState(() {}),
                            style: body.copyWith(color: p.text, fontSize: 13),
                            decoration: InputDecoration(
                              labelText: 'Batch year',
                              hintText: '2023',
                              isDense: true,
                              errorText:
                                  _year.text.length == 4 && _yearValue == null
                                      ? 'Not a batch year'
                                      : null,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ]),
                    if (_asksDual) ...[
                      const SizedBox(height: Space.md),
                      card([
                        Text('PROGRAMME', style: label),
                        const SizedBox(height: 9),
                        Wrap(
                          spacing: 5,
                          runSpacing: 5,
                          children: [
                            PillButton(
                              label: 'Single degree',
                              selected: !_dual,
                              height: 38,
                              onPressed:
                                  () => setState(() {
                                    _dual = false;
                                    _second = null;
                                  }),
                            ),
                            PillButton(
                              label: 'Dual degree',
                              selected: _dual,
                              height: 38,
                              onPressed:
                                  () => setState(() {
                                    _dual = true;
                                    if (!(programmeFor(_first ?? '')?.isMsc ??
                                        true)) {
                                      _first = null;
                                    }
                                  }),
                            ),
                            _TwoTwoPill(
                              onTap:
                                  () => setState(() => _show2p2Notice = true),
                            ),
                          ],
                        ),
                        if (_show2p2Notice) ...[
                          const SizedBox(height: 9),
                          Notice(
                            warning: true,
                            text: const TextSpan(
                              text:
                                  '2+2 programmes are still being built. Pick '
                                  'the degree you are reading and add your '
                                  'courses by hand for now — nothing else '
                                  'about the app changes.',
                            ),
                          ),
                        ],
                      ]),
                    ],
                    const SizedBox(height: Space.md),
                    Text('WHAT YOU ARE READING', style: label),
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Material(
                        color: p.surface,
                        child: Column(
                          children: [
                            _ProgrammeRow(
                              heading: _dual ? 'DUAL DEGREE' : 'YOUR PROGRAMME',
                              code: _first,
                              first: true,
                              onTap: () => _pick(first: true),
                            ),
                            if (_dual) ...[
                              Divider(
                                height: 1,
                                indent: 13,
                                endIndent: 13,
                                color: p.divider,
                              ),
                              _ProgrammeRow(
                                heading: 'DISCIPLINE',
                                code: _second,
                                first: false,
                                onTap: () => _pick(first: false),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (noChart.isNotEmpty) ...[
                      const SizedBox(height: Space.md),
                      Notice(
                        warning: true,
                        text: TextSpan(
                          text:
                              '${noChart.join(' and ')} has no course list '
                              'for the ${_yearValue ?? 0} batch yet, so '
                              'nothing would be added for it. Add your '
                              'courses by hand for now.',
                        ),
                      ),
                    ],
                    if (adds != null && adds.courses > 0) ...[
                      const SizedBox(height: Space.md),
                      card(color: p.hero, [
                        Text(
                          'THIS ADDS',
                          style: label.copyWith(color: p.onHeroMuted),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${adds.courses} core courses across '
                                '${adds.semesters} semesters',
                                style: body.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: p.onHero,
                                ),
                              ),
                            ),
                            Text(
                              '${_credits(adds.credits)} cr',
                              style: TypeScale.title.copyWith(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: p.onHero,
                              ),
                            ),
                          ],
                        ),
                      ]),
                    ],
                  ],
                ),
                BottomAction(
                  caption:
                      'Changing your first degree later clears your grades.',
                  child: PrimaryButton(
                    tall: true,
                    label: ready ? 'Set up $setupName' : 'Pick your degree',
                    onPressed: ready && !_busy ? _setUp : null,
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

const _numbers = [
  'No programme',
  'One programme',
  'Two programmes',
  'Three programmes',
  'Four programmes',
  'Five programmes',
  'Six programmes',
  'Seven programmes',
  'Eight programmes',
  'Nine programmes',
];

String _count(int n) => n < _numbers.length ? _numbers[n] : '$n programmes';

String _credits(double c) =>
    c == c.roundToDouble() ? c.toInt().toString() : c.toStringAsFixed(1);

/// A choice pill; [onTap] null draws it dashed and disabled.
class _Pill extends StatelessWidget {
  const _Pill(this.text, {required this.selected, required this.onTap});

  final String text;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final style = TypeScale.caption.copyWith(
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
      color:
          onTap == null
              ? p.textMuted
              : selected
              ? p.onInverse
              : p.text,
    );
    final inner = Container(
      constraints: const BoxConstraints(minHeight: 36),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Center(widthFactor: 1, child: Text(text, style: style)),
    );
    if (onTap == null) {
      return Semantics(
        enabled: false,
        button: true,
        label: '$text, not available yet',
        excludeSemantics: true,
        child: DashedOutline(color: p.textMuted, radius: 99, child: inner),
      );
    }
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? p.inverse : p.background,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: inner,
        ),
      ),
    );
  }
}

/// The "2+2" pill: dashed, always tappable, never selectable — tapping it
/// only reveals the notice that it is still being built.
class _TwoTwoPill extends StatelessWidget {
  const _TwoTwoPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Semantics(
      button: true,
      label: '2+2, not available yet',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(19),
        ),
        child: DashedOutline(
          color: p.outline,
          radius: 19,
          child: SizedBox(
            width: 62,
            height: 38,
            child: Center(
              child: Text(
                '2+2',
                style: TypeScale.caption.copyWith(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: p.textMuted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgrammeRow extends StatelessWidget {
  const _ProgrammeRow({
    required this.heading,
    required this.code,
    required this.onTap,
    required this.first,
  });

  final String heading;
  final String? code;
  final bool first;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final name = code == null ? 'Choose a programme' : programmeName(code!);
    return Semantics(
      button: true,
      label: '$heading: $name',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          child: Row(
            children: [
              CodeBadge(
                code ?? '',
                tone:
                    code == null
                        ? CodeTone.empty
                        : (first ? CodeTone.first : CodeTone.second),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      heading,
                      style: TypeScale.label.copyWith(color: p.textMuted),
                    ),
                    Text(
                      name,
                      style: TypeScale.body.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: code == null ? p.textMuted : p.text,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: p.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
