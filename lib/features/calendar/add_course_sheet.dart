import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/timetable/calendar_store.dart';
import 'package:cgpa_calculator/core/timetable/timetable.dart';
import 'package:cgpa_calculator/features/calendar/calendar_time.dart';
import 'package:cgpa_calculator/features/calendar/class_sheet.dart' show typeWord;
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/card_row.dart';
import 'package:cgpa_calculator/shared/widgets/search_box.dart';
import 'package:cgpa_calculator/shared/widgets/segmented.dart';
import 'package:flutter/material.dart';

/// A course and the section of each type the student attends.
typedef CoursePick = ({TtCourse course, List<String> keys});

/// A catalogue course: its code and name.
typedef CatalogCourse = ({String id, String title});

/// Add a course (published, or any catalogue course whose times the student
/// types: its pick has no sections) or an event of the student's own. Pops a
/// [CoursePick] or a [CalendarCustom].
class AddSheet extends StatefulWidget {
  const AddSheet({
    super.key,
    required this.timetable,
    required this.state,
    this.suggested = const {},
    this.catalogue = const [],
    this.today,
  });

  final Timetable timetable;
  final CalendarState state;

  /// The whole catalogue: search covers it, not just the published courses.
  final List<CatalogCourse> catalogue;

  /// Course ids to offer before anything is typed (this semester's).
  final Set<String> suggested;
  final String? today;

  @override
  State<AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<AddSheet> {
  bool _event = false;
  final _q = TextEditingController();
  TtCourse? _course;
  final _keys = <String>{};

  final _title = TextEditingController(), _room = TextEditingController();
  final _start = TextEditingController(text: '9:00 AM'), _end = TextEditingController(text: '10:00 AM');
  late String _date = widget.today ?? widget.timetable.semStart();
  bool _weekly = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_q, _title, _room, _start, _end]) {
      c.dispose();
    }
    super.dispose();
  }

  /// The published courses, then each catalogue course the timetable lacks
  /// (no sections: the student types its times).
  late final List<TtCourse> _all = [
    ...widget.timetable.courses.values,
    for (final m in {for (final m in widget.catalogue) m.id: m}.values)
      if (!widget.timetable.courses.containsKey(m.id)) TtCourse(id: m.id, title: m.title),
  ];

  void _pick(TtCourse c) {
    if (c.sections.isEmpty) return Navigator.pop<Object>(context, (course: c, keys: <String>[]));
    _pickSections(c);
  }

  void _pickSections(TtCourse c) => setState(() {
    _course = c;
    _keys
      ..clear()
      ..addAll(widget.state.picks[c.id] ?? const []);
    final types = {for (final s in c.sections) s.ty};
    for (final ty in types) {
      final of = c.sections.where((s) => s.ty == ty).toList();
      if (of.length == 1) _keys.add(of.first.key(c.id));
    }
  });

  List<TtCourse> get _results {
    final t = widget.timetable;
    if (_q.text.trim().isNotEmpty) return searchCourses(_all, _q.text);
    return [for (final id in widget.suggested.toList()..sort()) if (t.courses[id] != null) t.courses[id]!];
  }

  Future<void> _pickDate() async {
    final now = parseDate(_date);
    final d = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 730)),
    );
    if (d != null) setState(() => _date = dayStr(d));
  }

  void _saveEvent() {
    final s = parseClock(_start.text), e = parseClock(_end.text);
    final title = _title.text.trim();
    final err = title.isEmpty
        ? 'Give it a name'
        : (s == null || e == null)
        ? 'Use a time like 9:00 AM'
        : e <= s
        ? 'End must be after start'
        : null;
    if (err != null) return setState(() => _error = err);
    Navigator.pop<Object>(
      context,
      CalendarCustom(
        id: 'c${DateTime.now().microsecondsSinceEpoch}',
        title: title,
        d: parseDate(_date).weekday,
        s: s!,
        e: e!,
        from: _date,
        room: _room.text.trim(),
        once: !_weekly,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 10, 20, Space.lg + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add to calendar', style: TypeScale.sheetTitle.copyWith(color: p.text)),
            const SizedBox(height: Space.md),
            SegmentedPair<bool>(
              a: (false, 'Course'),
              b: (true, 'My event'),
              value: _event,
              onChanged: (v) => setState(() => _event = v),
            ),
            const SizedBox(height: Space.md),
            Flexible(child: _event ? _eventForm(p) : _courseForm(p)),
          ],
        ),
      ),
    );
  }

  Widget _courseForm(AppPalette p) {
    final c = _course;
    if (c != null) return _sections(p, c);
    final res = _results;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SearchBox(controller: _q, hint: 'Search by code or name', onChanged: (_) => setState(() {})),
        const SizedBox(height: Space.sm),
        Flexible(
          child: res.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(Space.lg),
                  child: Text(
                    _q.text.trim().isEmpty ? 'Search for a course.' : 'No course matches.',
                    textAlign: TextAlign.center,
                    style: TypeScale.caption.copyWith(color: p.textMuted),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: res.length,
                  itemBuilder: (_, i) => CardRow(
                    title: res[i].title.isEmpty ? res[i].id : res[i].title,
                    subtitle: res[i].sections.isEmpty ? '${res[i].id} · you add the times' : res[i].id,
                    trailing: widget.state.picks.containsKey(res[i].id) ||
                            widget.state.custom.any((e) => e.course == res[i].id)
                        ? Icon(Icons.check_rounded, size: 18, color: p.text)
                        : null,
                    onTap: () => _pick(res[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _sections(AppPalette p, TtCourse c) {
    final types = [...{for (final s in c.sections) s.ty}];
    final ready = types.every((ty) => c.sections.any((s) => s.ty == ty && _keys.contains(s.key(c.id))));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Semantics(
              button: true,
              label: 'Back to search',
              child: InkWell(
                onTap: () => setState(() => _course = null),
                child: const SizedBox(
                  width: Sizes.minTouch,
                  height: Sizes.minTouch,
                  child: Icon(Icons.arrow_back_rounded, size: 20),
                ),
              ),
            ),
            Expanded(
              child: Text(
                '${c.id}  ${c.title}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TypeScale.body.copyWith(fontWeight: FontWeight.w700, color: p.text),
              ),
            ),
          ],
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final ty in types) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, Space.md, 4, Space.xs),
                  child: Text(
                    'Your ${typeWord(ty).toLowerCase()}',
                    style: TypeScale.label.copyWith(color: p.textMuted),
                  ),
                ),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final s in c.sections.where((s) => s.ty == ty))
                        CardRow(
                          title: '${typeWord(ty)} ${s.no}${s.prof.isEmpty ? '' : ' · ${s.prof.join(', ')}'}',
                          subtitle: [
                            for (final sl in s.slots) '${dayShort(sl.d)} ${clockShort(sl.s)}-${clockShort(sl.e)}',
                            if (s.room != null && s.room!.isNotEmpty) s.room!,
                          ].join(' · '),
                          titleLines: 2,
                          trailing: Icon(
                            _keys.contains(s.key(c.id)) ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                            size: 20,
                            color: p.text,
                          ),
                          onTap: () => setState(() {
                            _keys.removeWhere((k) => c.sections.any((o) => o.ty == ty && o.key(c.id) == k));
                            _keys.add(s.key(c.id));
                          }),
                        ),
                    ],
                  ),
                ),
              ],
              if (c.mid != null || c.compre != null)
                Padding(
                  padding: const EdgeInsets.only(top: Space.md),
                  child: Text(
                    [
                      if (c.mid != null) 'Midsem ${dateLabel(c.mid!.d)}',
                      if (c.compre != null) 'Compre ${dateLabel(c.compre!.d)}',
                    ].join(' · '),
                    style: TypeScale.caption.copyWith(color: p.textMuted),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: Space.md),
        PrimaryButton(
          label: widget.state.picks.containsKey(c.id) ? 'Update course' : 'Add course',
          onPressed: ready ? () => Navigator.pop<Object>(context, (course: c, keys: _keys.toList())) : null,
        ),
      ],
    );
  }

  Widget _eventForm(AppPalette p) => ListView(
    shrinkWrap: true,
    children: [
      AppTextField(controller: _title, label: 'Name', dense: true),
      const SizedBox(height: Space.sm),
      Semantics(
        button: true,
        child: InkWell(
          onTap: _pickDate,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Sizes.minTouch),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Date: ${dateLabel(_date)}', style: TypeScale.button.copyWith(color: p.text)),
            ),
          ),
        ),
      ),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: AppTextField(controller: _start, label: 'Start', dense: true)),
          const SizedBox(width: Space.sm),
          Expanded(child: AppTextField(controller: _end, label: 'End', dense: true)),
        ],
      ),
      const SizedBox(height: Space.sm),
      AppTextField(controller: _room, label: 'Room (optional)', dense: true),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('Repeats every week', style: TypeScale.body.copyWith(color: p.text)),
        value: _weekly,
        onChanged: (v) => setState(() => _weekly = v),
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(bottom: Space.sm),
          child: Text(_error!, style: TypeScale.caption.copyWith(color: p.behind)),
        ),
      PrimaryButton(label: 'Add event', onPressed: _saveEvent),
    ],
  );
}
