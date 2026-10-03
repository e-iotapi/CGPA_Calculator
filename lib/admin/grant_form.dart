import 'dart:async';

import 'package:cgpa_calculator/admin/admin_home.dart' show termSpan;
import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/admin/dept_list.dart';
import 'package:cgpa_calculator/app/routes.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/catalog/catalog.dart';
import 'package:cgpa_calculator/core/models/programmes.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/core/timings.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/bottom_action.dart';
import 'package:cgpa_calculator/shared/widgets/card_row.dart';
import 'package:cgpa_calculator/shared/widgets/pill_button.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The bottom action's words: "Grant" until an address resolves, then the
/// grant it will make, e.g. "Grant — president, ELEC Goa" (N18).
String grantLabel(
  GrantRole? role,
  String? scope,
  String? campus, {
  bool secretary = false,
}) {
  if (role == null || campus == null) return 'Grant';
  final where = campus == 'all' ? '' : ' ${campusName(campus)}';
  final dept = secretary ? 'secretary' : 'president';
  return switch (role) {
    GrantRole.admin => 'Grant — admin',
    GrantRole.dept =>
      scope == null ? 'Grant — $dept' : 'Grant — $dept, $scope$where',
    GrantRole.course =>
      scope == null
          ? 'Grant — course manager'
          : 'Grant — course manager, $scope$where',
    GrantRole.contributor => 'Grant — contributor',
  };
}

/// The tier pills. A secretary is a department grant with every president
/// right but handing over; appointed by owners, admins and presidents.
enum _Tier {
  admin('Admin'),
  president('President'),
  secretary('Secretary'),
  course('CR');

  const _Tier(this.label);
  final String label;

  GrantRole get role => switch (this) {
    admin => GrantRole.admin,
    president || secretary => GrantRole.dept,
    course => GrantRole.course,
  };
}

/// What the form opens with, e.g. from Roster › Volunteers: Appoint as CR.
typedef GrantPrefill = ({GrantRole? role, String? email, String? scope});

/// Board `AdminGrant`: appoint by address. Only someone who has signed in
/// can be appointed; campus is read from the address, never picked; one
/// scope per grant (§4, §16.3 fix 12).
class AdminGrant extends StatefulWidget {
  const AdminGrant({super.key, this.prefill, this.closeOffers = const []});
  final GrantPrefill? prefill;

  /// Volunteer offers the appointment closes, in its batch (§16.3 fix 16).
  final List<String> closeOffers;

  @override
  State<AdminGrant> createState() => _AdminGrantState();
}

class _AdminGrantState extends State<AdminGrant> {
  late final _email = TextEditingController(text: widget.prefill?.email ?? '');
  late final _course = TextEditingController(
    text:
        widget.prefill?.role == GrantRole.course
            ? widget.prefill?.scope ?? ''
            : '',
  );
  late GrantRole? _role = widget.prefill?.role ?? _tiers.lastOrNull?.role;
  bool _secretary = false;
  late String? _dept =
      widget.prefill?.role == GrantRole.dept ? widget.prefill?.scope : null;
  String? _programme;

  /// The picked row of the shared department list, for its label and tick.
  Branch? get _branch => switch (_dept) {
    null => null,
    final d => (
      dept: d,
      programme:
          (departments[d]?.programmes.length ?? 0) > 1 ? _programme : null,
    ),
  };
  String? _found; // the person's name
  bool _looked = false, _busy = false, _early = false;
  DateTime? _earlier;
  GrantTerms _terms = defaultTerms;
  Timer? _debounce;

  final _roles = myRoles.value;

  /// Admin is offered to owners only; a president sees Secretary and
  /// Course manager.
  List<_Tier> get _tiers => [
    if (_roles.owner) _Tier.admin,
    if (_roles.owner || _roles.admin) _Tier.president,
    if (_roles.owner || _roles.admin || _roles.presidencies.isNotEmpty) ...[
      _Tier.secretary,
      _Tier.course,
    ],
  ];

  _Tier? get _tier => switch (_role) {
    GrantRole.admin => _Tier.admin,
    GrantRole.dept => _secretary ? _Tier.secretary : _Tier.president,
    GrantRole.course => _Tier.course,
    // Contributors are approved from requests, never granted by form.
    GrantRole.contributor || null => null,
  };

  String get _address => _email.text.trim().toLowerCase();
  String? get _campus =>
      _role == GrantRole.admin ? 'all' : campusOfAddress(_address);

  @override
  void initState() {
    super.initState();
    roleStore?.terms().then((t) {
      if (mounted) setState(() => _terms = t);
    });
    if (_address.isNotEmpty) _lookUp();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _email.dispose();
    _course.dispose();
    super.dispose();
  }

  /// Looks the address up 400 ms after typing stops; no button (N18).
  void _typed(String _) {
    _debounce?.cancel();
    setState(() {
      _looked = false;
      _found = null;
    });
    _debounce = Timer(const Duration(milliseconds: 400), _lookUp);
  }

  Future<void> _pickDept() async {
    final v = await showModalBottomSheet<Branch>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DeptSheet(campus: _campus, selected: _branch),
    );
    if (v == null || !mounted) return;
    setState(() {
      _dept = v.dept;
      _programme = v.programme ?? departments[v.dept]?.programmes.single;
    });
  }

  Future<void> _lookUp() async {
    final a = _address;
    if (a.isEmpty) return;
    final name = await roleStore?.personName(a);
    if (!mounted || a != _address) return;
    setState(() {
      _found = name;
      _looked = true;
    });
  }

  /// Why this cannot be granted, in words; null when it can.
  String? get _refusal => _addressRefusal ?? _courseRefusal;

  /// Why this address cannot hold the role; shown under the address.
  String? get _addressRefusal {
    final a = _address;
    if (a.isEmpty || _role == null) return null;
    if (_role == GrantRole.admin) {
      return isBitsAddress(a) ? null : 'Admins hold a BITS address.';
    }
    if (!isStudentAddress(a)) {
      return 'Refused: this is not a student address. Presidents and CRs '
          'are students.';
    }
    return null;
  }

  /// Why this course cannot be granted; shown under the course field, where
  /// it was typed, not off screen under the address.
  String? get _courseRefusal {
    if (_address.isEmpty || _addressRefusal != null) return null;
    final code = _course.text.trim().toUpperCase();
    // Only once no course starts with it: "C" is a code still being typed.
    if (_role == GrantRole.course &&
        code.isNotEmpty &&
        catalogLoaded &&
        !catalog.master.any((m) => _bare(m.id).startsWith(_bare(code)))) {
      return '$code is not in the catalogue.';
    }
    if (_role == GrantRole.course && !_roles.owner && !_roles.admin) {
      final course = _course.text.trim();
      final ok = _roles.presidencies.any(
        (p) =>
            p.campus == _campus &&
            (course.isEmpty || deptOf(course) == p.scope),
      );
      if (!ok) {
        return 'You appoint CRs for your own department, on your own campus.';
      }
    }
    return null;
  }

  String? get _scope => switch (_role) {
    GrantRole.admin => 'all',
    GrantRole.dept => _dept,
    GrantRole.course =>
      _course.text.trim().isEmpty ? null : _course.text.trim().toUpperCase(),
    GrantRole.contributor || null => null,
  };

  /// Catalogue codes starting with what is typed, until one is exact.
  List<String> get _suggestions {
    final q = _bare(_course.text);
    if (q.length < 2 || _exactCourse) return const [];
    // A course listed under several programmes appears once.
    return {
      for (final m in catalog.master)
        if (_bare(m.id).startsWith(q)) m.id,
    }.take(6).toList();
  }

  /// Whether the typed code is a catalogue course, spacing aside.
  bool get _exactCourse =>
      catalog.master.any((m) => _bare(m.id) == _bare(_course.text));

  static String _bare(String code) =>
      code.trim().toUpperCase().replaceAll(' ', '');

  /// A secretary ends with the appointing president's own term.
  DateTime? get _secretaryEnds {
    if (!_secretary) return null;
    final mine =
        _roles.presidencies
            .where((g) => g.campus == _campus && g.scope == _scope)
            .firstOrNull;
    return mine == null || mine.expiresAt.isAfter(_fullTerm)
        ? null
        : mine.expiresAt;
  }

  DateTime get _fullTerm => DateTime.now()
      .add(Duration(days: termDays(_terms, _role!)))
      .subtract(clockSlack);

  bool get _ready =>
      !_busy &&
      _found != null &&
      _refusal == null &&
      _campus != null &&
      _scope != null &&
      (_role != GrantRole.course || !catalogLoaded || _exactCourse) &&
      (_role != GrantRole.dept || _programme != null);

  Future<void> _grant() async {
    setState(() => _busy = true);
    try {
      final ok = await roleStore!.appoint(
        role: _role!,
        email: _address,
        campus: _campus!,
        scope: _scope!,
        programme: _role == GrantRole.dept ? _programme : null,
        secretary: _role == GrantRole.dept && _secretary,
        expiresAt:
            _early && _earlier != null
                ? _earlier!
                : _secretaryEnds ?? _fullTerm,
        closeOffers: widget.closeOffers,
      );
      if (!mounted) return;
      if (!ok) {
        setState(() => _found = null);
        return;
      }
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text('Appointed $_found.')));
      Navigator.of(context).maybePop();
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(problem(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// A refusal, in the red box.
  Widget _refused(AppPalette p, String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: p.behind.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: p.behind.withValues(alpha: 0.6)),
    ),
    child: Text(
      text,
      style: TypeScale.caption.copyWith(
        fontSize: 11,
        height: 1.45,
        color: p.behind,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final batch = batchOfAddress(_address);
    final refusal = _addressRefusal;
    final role = _role;
    final canTerms = _roles.owner || _roles.admin;
    final ends = _early && _earlier != null ? _earlier! : null;
    final muted = TypeScale.caption.copyWith(
      fontSize: 11,
      height: 1.45,
      color: p.textMuted,
    );

    return PageFrame(
      header: const PageHeader(eyebrow: 'NEW GRANT', title: 'Appoint someone'),
      bottom: BottomAction(
        child: PrimaryButton(
          label:
              _busy
                  ? 'Granting…'
                  : grantLabel(
                    role,
                    _scope,
                    _found == null ? null : _campus,
                    secretary: _secretary,
                  ),
          onPressed: _ready ? _grant : null,
        ),
      ),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(
                controller: _email,
                label: 'BITS student address',
                hint: 'f20230802@goa.bits-pilani.ac.in',
                labelAbove: true,
                onChanged: _typed,
              ),
              if (campusOfAddress(_address) != null || batch != null) ...[
                const SizedBox(height: Space.sm),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (campusOfAddress(_address) case final c?)
                      ScopeChip(campusName(c), icon: Icons.lock_outline),
                    if (batch != null)
                      ScopeChip('Student · $batch', muted: true),
                  ],
                ),
              ],
              if (_looked) ...[
                const SizedBox(height: Space.sm),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color:
                        _found == null
                            ? p.behind.withValues(alpha: 0.12)
                            : p.hero.withValues(alpha: p.isDark ? 0.22 : 0.45),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _found == null
                            ? Icons.close_rounded
                            : Icons.check_rounded,
                        size: 15,
                        color: _found == null ? p.behind : p.text,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _found == null
                              ? 'Can not be found'
                              : '$_found uses Pointer',
                          style: TypeScale.body.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _found == null ? p.behind : p.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(4, Space.sm, 4, 0),
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text:
                            'Only someone who has signed in to Pointer can be '
                            'appointed; any other address shows ',
                      ),
                      TextSpan(
                        text: 'Can not be found',
                        style: TextStyle(
                          color: p.behind,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const TextSpan(
                        text:
                            '. Campus is read from the address and cannot be '
                            'picked.',
                      ),
                    ],
                  ),
                  style: muted,
                ),
              ),
              if (refusal != null) ...[
                const SizedBox(height: Space.sm),
                _refused(p, refusal),
              ],
            ],
          ),
        ),
        const SizedBox(height: Space.sm),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('Tier'),
              ChoicePills<_Tier>(
                values: _tiers,
                selected: _tier,
                // "President" keeps the pills short (N18, G2).
                label: (t) => t.label,
                onSelected:
                    (t) => setState(() {
                      _role = t.role;
                      _secretary = t == _Tier.secretary;
                    }),
              ),
              const Note(
                'Admin is offered to owners only. A secretary holds every '
                'president right but handing over. A president sees Secretary '
                'and CR, for their own department.',
              ),
            ],
          ),
        ),
        if (role == GrantRole.dept || role == GrantRole.course) ...[
          const SizedBox(height: Space.sm),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Scope · one per grant'),
                if (role == GrantRole.dept) ...[
                  SelectRow(
                    text:
                        _dept == null
                            ? 'Choose a department'
                            : '${branchName(_branch!)} · '
                                '${branchCodes(_branch!)}',
                    placeholder: _dept == null,
                    onTap: _pickDept,
                  ),
                  if (_dept != null) ...[
                    const SectionLabel('Appointed for'),
                    ChoicePills<String>(
                      values: departments[_dept]!.programmes,
                      selected: _programme,
                      label: (c) => c,
                      onSelected: (c) => setState(() => _programme = c),
                      equal: true,
                    ),
                    Note(
                      departments[_dept]!.programmes.length > 1
                          ? 'Every ${departmentName(_dept!).toLowerCase()} '
                              'president controls all its branches, as '
                              'equals. The branch is kept for the roster and '
                              'for handover.'
                          : '${programmeName(_programme ?? '')} — kept for the '
                              'roster and for handover.',
                    ),
                  ],
                ] else ...[
                  AppTextField(
                    controller: _course,
                    label: 'Course code',
                    hint: 'EEE F211',
                    labelAbove: true,
                    onChanged: (_) => setState(() {}),
                  ),
                  if (_courseRefusal case final r?) ...[
                    const SizedBox(height: Space.sm),
                    _refused(p, r),
                  ],
                  // Always there, so the pills come and go inside it: a
                  // sibling appearing beside the field changed its
                  // semantics parent, and Flutter web then emptied the
                  // field mid-typing.
                  Semantics(
                    container: true,
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: _suggestions.isEmpty ? 0 : Space.sm,
                      ),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final id in _suggestions)
                            PillButton(
                              label: id,
                              onPressed:
                                  () => setState(() => _course.text = id),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const Note(
                    'A CR\'s scope is the course, never a section. A CR of '
                    'three courses holds three grants.',
                  ),
                ],
              ],
            ),
          ),
        ],
        if (role != null) ...[
          const SizedBox(height: Space.sm),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Expires'),
                ChoicePills<bool>(
                  values: const [false, true],
                  selected: _early,
                  label:
                      (e) =>
                          e
                              ? 'Earlier date'
                              : 'Full term · ${termSpan(termDays(_terms, role))}',
                  onSelected: (e) async {
                    if (!e) return setState(() => _early = false);
                    final d = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now().add(const Duration(days: 1)),
                      lastDate: _fullTerm,
                      initialDate: _fullTerm,
                    );
                    if (d != null) {
                      setState(() {
                        _early = true;
                        _earlier = d;
                      });
                    }
                  },
                ),
                if (_secretary && ends == null)
                  const Note(
                    'Ends with the department president\'s term, so both are '
                    'chosen together. A grant can end sooner, never later.',
                  )
                else
                  Note(
                    'Ends ${shortDay(ends ?? _fullTerm, year: true)}'
                    '${ends == null ? ', counted from today' : ''}. A grant can '
                    'end sooner than its term, never later.',
                  ),
                if (canTerms)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => context.push(Routes.adminTerms),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 44),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Grant terms',
                                style: TypeScale.caption.copyWith(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: p.text,
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 16,
                                color: p.text,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Every department, the chosen one ticked.
/// The shared department list ([deptBranches]) as a sheet: a row per
/// branch, so ELEC shows as its four branches. Pops the [Branch].
class DeptSheet extends StatelessWidget {
  const DeptSheet({super.key, required this.campus, this.selected, this.only});

  /// Whose departments to list ([campusBranches]); null lists them all.
  final String? campus;
  final Branch? selected;

  /// Of those, the departments to offer; every one when null.
  final List<String>? only;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      builder:
          (context, scroll) => ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: p.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 11),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Department',
                  style: TypeScale.title.copyWith(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: Space.sm),
              FutureBuilder<List<Branch>>(
                future: campusBranches(campus),
                initialData: campusBranchesNow(campus),
                builder: (context, snap) {
                  final rows = [
                    for (final b in snap.data ?? const <Branch>[])
                      if (only == null || only!.contains(b.dept)) b,
                  ];
                  if (!snap.hasData) return const SizedBox(height: 120);
                  if (rows.isEmpty) {
                    return const Note('No departments on this campus yet.');
                  }
                  return AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (final (i, b) in rows.indexed) ...[
                          if (i > 0) const CardDivider(),
                          CardRow(
                            title: branchName(b),
                            subtitle: branchCodes(b),
                            titleLines: 2,
                            trailing:
                                b == selected
                                    ? Icon(Icons.check_rounded, color: p.text)
                                    : const SizedBox.shrink(),
                            onTap: () => Navigator.of(context).pop(b),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
    );
  }
}
