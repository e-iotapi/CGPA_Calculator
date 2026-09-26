import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/auth_util.dart';
import 'package:cgpa_calculator/core/models/elective.dart';
import 'package:cgpa_calculator/core/models/programmes.dart';
import 'package:cgpa_calculator/core/storage/seed.dart';
import 'package:cgpa_calculator/features/import/erp_import_page.dart';
import 'package:cgpa_calculator/features/setup/programme_pick_page.dart';
import 'package:cgpa_calculator/script.dart' as app;
import 'package:cgpa_calculator/shared/widgets/dashed_outline.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

/// First run, step 1 of 2: campus and batch from the sign-in address, then
/// the one question the address cannot answer: what the student reads.
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

  /// Change was pressed, or the address left something out.
  late bool _editing = _campus == null || _address.year == null;

  var _dual = false;
  String? _first, _second;
  var _busy = false;

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
      !_dual ? 'YOUR PROGRAMME' : (first ? 'FIRST DEGREE' : 'SECOND DEGREE'),
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
                return n == 0 ? '' : '$n sem';
              },
              note:
                  _campus == null || elsewhere.isEmpty
                      ? null
                      : '${_count(options.length)} run at ${_campus!.label}. '
                          '${elsewhere.map((p) => '${p.code} ${p.name}').join(', ')} '
                          '${elsewhere.length == 1 ? 'is' : 'are'} elsewhere — '
                          'change campus to see ${elsewhere.length == 1 ? 'it' : 'them'}.',
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
    app.selecteddiscipline = d;
    app.batch = y % 100;
    app.campus = _campus;
    // A fresh profile has nothing to lose: seed from clean.
    app.erase = 1;
    await app.setdis();
    await app.initializeCourses();
    app.erase = 0;
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
    final ready = d != null && y != null && _campus != null;
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
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                Space.xxl,
                Space.gutter,
                Space.xxl,
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.email == null
                              ? 'CAMPUS AND BATCH'
                              : 'FROM YOUR SIGN-IN',
                          style: label,
                        ),
                      ),
                      if (!_editing)
                        TextButton(
                          onPressed: () => setState(() => _editing = true),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(44, 32),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: Text(
                            'Change',
                            style: TypeScale.button.copyWith(
                              fontSize: 12,
                              color: p.text,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (widget.email != null)
                    Text(
                      widget.email!,
                      overflow: TextOverflow.ellipsis,
                      style: body.copyWith(color: p.text),
                    ),
                  const SizedBox(height: Space.sm),
                  if (!_editing)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _Chip(_campus!.label),
                        _Chip('${_yearValue ?? _year.text} batch'),
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
                                  if (!here.contains(_first)) _first = null;
                                  if (!here.contains(_second)) _second = null;
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
                        _Pill(
                          'Single degree',
                          selected: !_dual,
                          onTap:
                              () => setState(() {
                                _dual = false;
                                _second = null;
                              }),
                        ),
                        _Pill(
                          'Dual degree',
                          selected: _dual,
                          onTap:
                              () => setState(() {
                                _dual = true;
                                if (!(programmeFor(_first ?? '')?.isMsc ??
                                    true)) {
                                  _first = null;
                                }
                              }),
                        ),
                        const _Pill('2+2', selected: false, onTap: null),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Text(
                      '2+2 programmes are still being built. Pick the degree '
                      'you are reading and add your courses by hand for now — '
                      'nothing else about the app changes.',
                      style: body.copyWith(fontSize: 11, color: p.behind),
                    ),
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
                          heading: _dual ? 'FIRST DEGREE' : 'YOUR PROGRAMME',
                          code: _first,
                          tint: true,
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
                            heading: 'SECOND DEGREE',
                            code: _second,
                            onTap: () => _pick(first: false),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
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
                const SizedBox(height: Space.lg),
                FilledButton(
                  onPressed: ready && !_busy ? _setUp : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: p.inverse,
                    foregroundColor: p.onInverse,
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    ready ? 'Set up $setupName' : 'Pick what you are reading',
                    style: TypeScale.button.copyWith(fontSize: 14),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Changing your first degree later clears your grades.',
                  textAlign: TextAlign.center,
                  style: TypeScale.caption.copyWith(
                    fontSize: 10.5,
                    color: p.textMuted,
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

class _Chip extends StatelessWidget {
  const _Chip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: p.hero,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: TypeScale.caption.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: p.onHero,
        ),
      ),
    );
  }
}

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

class _ProgrammeRow extends StatelessWidget {
  const _ProgrammeRow({
    required this.heading,
    required this.code,
    required this.onTap,
    this.tint = false,
  });

  final String heading;
  final String? code;
  final bool tint;
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
              if (code != null) ...[
                CodeBadge(code!, tint: tint),
                const SizedBox(width: 11),
              ],
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
