import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/catalog/catalog.dart';
import 'package:cgpa_calculator/core/models/programmes.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:flutter/material.dart';

/// What the form opens with, e.g. from Roster › Volunteers: Appoint as CR.
typedef GrantPrefill = ({GrantRole? role, String? email, String? scope});

/// Board `AdminGrant`: appoint by address. Only someone who has signed in
/// can be appointed; campus is read from the address, never picked; one
/// scope per grant (§4, §16.3 fix 12).
class AdminGrant extends StatefulWidget {
  const AdminGrant({super.key, this.prefill});
  final GrantPrefill? prefill;

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
  late GrantRole? _role = widget.prefill?.role ?? _tiers.lastOrNull;
  late String? _dept =
      widget.prefill?.role == GrantRole.dept ? widget.prefill?.scope : null;
  String? _programme;
  String? _found; // the person's name
  bool _looked = false, _busy = false, _early = false;
  DateTime? _earlier;
  GrantTerms _terms = defaultTerms;

  final _roles = myRoles.value;

  /// Admin is offered to owners only; a president sees Course manager alone.
  List<GrantRole> get _tiers => [
    if (_roles.owner) GrantRole.admin,
    if (_roles.owner || _roles.admin) GrantRole.dept,
    if (_roles.owner || _roles.admin || _roles.presidencies.isNotEmpty)
      GrantRole.course,
  ];

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
    _email.dispose();
    _course.dispose();
    super.dispose();
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
  String? get _refusal {
    final a = _address;
    if (a.isEmpty || _role == null) return null;
    if (_role == GrantRole.admin) {
      return isBitsAddress(a) ? null : 'Admins hold a BITS address.';
    }
    if (!isStudentAddress(a)) {
      return 'Refused: presidents and CRs are students. Faculty addresses, '
          'alumni addresses and non-BITS accounts cannot hold either.';
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
    null => null,
  };

  /// Catalogue codes starting with what is typed, until one is exact.
  List<String> get _suggestions {
    final q = _course.text.trim().toUpperCase().replaceAll(' ', '');
    if (q.length < 2) return const [];
    final ids = catalog.master.map((m) => m.id);
    if (ids.any((id) => id.replaceAll(' ', '') == q)) return const [];
    return ids
        .where((id) => id.replaceAll(' ', '').startsWith(q))
        .take(6)
        .toList();
  }

  DateTime get _fullTerm =>
      DateTime.now().add(Duration(days: termDays(_terms, _role!)));

  bool get _ready =>
      !_busy &&
      _found != null &&
      _refusal == null &&
      _campus != null &&
      _scope != null &&
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
        expiresAt: _early && _earlier != null ? _earlier! : _fullTerm,
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

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final batch = batchOfAddress(_address);
    final refusal = _refusal;
    final role = _role;
    final label = switch (role) {
      GrantRole.admin => 'admin',
      GrantRole.dept =>
        'president, ${_dept ?? '…'} ${campusName(_campus ?? '')}',
      GrantRole.course => 'CR, ${_scope ?? '…'} ${campusName(_campus ?? '')}',
      null => '…',
    };

    return PageFrame(
      header: const PageHeader(eyebrow: 'NEW GRANT', title: 'Appoint someone'),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('BITS student address'),
              AppTextField(
                controller: _email,
                label: 'Email',
                hint: 'f20230802@goa.bits-pilani.ac.in',
                onChanged:
                    (_) => setState(() {
                      _looked = false;
                      _found = null;
                    }),
              ),
              const SizedBox(height: Space.sm),
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (campusOfAddress(_address) case final c?)
                          ScopeChip(campusName(c), icon: Icons.lock_outline),
                        if (batch != null)
                          ScopeChip('Student · $batch', muted: true),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _address.isEmpty ? null : _lookUp,
                    child: const Text('Look up'),
                  ),
                ],
              ),
              if (_looked)
                Container(
                  margin: const EdgeInsets.only(top: Space.sm),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color:
                        _found == null
                            ? p.behind.withValues(alpha: 0.12)
                            : p.accent.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _found == null
                        ? 'Can not be found'
                        : '$_found · uses Pointer',
                    style: TypeScale.body.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _found == null ? p.behind : p.text,
                    ),
                  ),
                ),
              if (refusal != null)
                Container(
                  margin: const EdgeInsets.only(top: Space.sm),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: p.noticeTone.fill,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    refusal,
                    style: TypeScale.caption.copyWith(
                      color: p.noticeTone.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const Note(
                'Only someone who has signed in to Pointer can be appointed; '
                'any other address shows Can not be found. Campus is read from '
                'the address and cannot be picked. On their next sign-in they '
                'fill in their name and contact details before anything else.',
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.sm),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('Tier'),
              ChoicePills<GrantRole>(
                values: _tiers,
                selected: role,
                label: (r) => r.label,
                onSelected: (r) => setState(() => _role = r),
              ),
              const Note(
                'Admin is offered to owners only. A president sees Course '
                'manager alone, for their own department.',
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
                  DropdownButtonFormField<String>(
                    initialValue: _dept,
                    isExpanded: true,
                    hint: const Text('Department'),
                    items: [
                      for (final e in departments.entries)
                        DropdownMenuItem(
                          value: e.key,
                          child: Text('${e.key} · ${e.value.name}'),
                        ),
                    ],
                    onChanged:
                        (v) => setState(() {
                          _dept = v;
                          _programme =
                              departments[v]?.programmes.length == 1
                                  ? departments[v]!.programmes.single
                                  : null;
                        }),
                  ),
                  if (_dept != null) ...[
                    const SectionLabel('Appointed for'),
                    ChoicePills<String>(
                      values: departments[_dept]!.programmes,
                      selected: _programme,
                      label: (c) => c,
                      onSelected: (c) => setState(() => _programme = c),
                    ),
                    Note(
                      _dept == 'ELEC'
                          ? 'Every electronics president controls all of ELEC, '
                              'as equals. The programme is kept for the '
                              'roster and for handover.'
                          : '${programmeName(_programme ?? '')} — kept for the '
                              'roster and for handover.',
                    ),
                  ],
                ] else ...[
                  AppTextField(
                    controller: _course,
                    label: 'Course code',
                    hint: 'EEE F211',
                    onChanged: (_) => setState(() {}),
                  ),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final id in _suggestions)
                        ActionChip(
                          label: Text(id),
                          onPressed: () => setState(() => _course.text = id),
                        ),
                    ],
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
                  label: (e) => e ? 'Earlier date' : 'Full term',
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
                Note(
                  'Ends ${shortDay(_early && _earlier != null ? _earlier! : _fullTerm, year: true)}: '
                  'counted from today (Grant terms). A grant can end sooner, '
                  'never later.',
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: Space.lg),
        PrimaryButton(
          label: _busy ? 'Granting…' : 'Grant — $label',
          onPressed: _ready ? _grant : null,
        ),
      ],
    );
  }
}
