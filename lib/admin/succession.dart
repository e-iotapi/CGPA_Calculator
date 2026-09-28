import 'dart:async';

import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/routes.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:cgpa_calculator/shared/widgets/bottom_action.dart';
import 'package:cgpa_calculator/shared/widgets/notice.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

RoleStore get _roles => roleStore!;

/// The signed-in president's grant for [dept], read fresh: a handover in
/// progress lives only on the document.
Future<Grant?> _myGrant(String campus, String dept) async {
  final d =
      await _roles.db
          .collection('grants')
          .doc(grantId(GrantRole.dept, campus, dept, _roles.me))
          .get();
  final m = d.data();
  if (m == null) return null;
  final g = Grant.fromMap(m);
  return g.liveAt(DateTime.now()) ? g : null;
}

PageHeader _header(String campus, String dept, String title, {String? step}) =>
    PageHeader(
      eyebrow:
          '${step == null ? '' : '$step · '}'
          '${campusName(campus).toUpperCase()} · $dept',
      title: title,
    );

/// The address's local part: "f20240001".
String _id(String address) => address.split('@').first;

/// One step of a timeline: a numbered disc (mint, or ink for the last), a
/// bold lead and the rest.
class _Step extends StatelessWidget {
  const _Step(this.n, this.lead, this.rest, {this.ink = false});
  final int n;
  final String lead, rest;
  final bool ink;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ink ? p.inverse : p.hero,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$n',
              style: TypeScale.caption.copyWith(
                fontWeight: FontWeight.w800,
                color: ink ? p.onInverse : p.onHero,
              ),
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$lead ',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(text: rest),
                ],
              ),
              style: TypeScale.body.copyWith(fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Board `Succession` (§13.4), steps one and two: name the next president,
/// then read what happens on which date. A handover already running shows
/// here instead, cancellable until the overlap ends.
class Succession extends StatefulWidget {
  const Succession({super.key, required this.campus, required this.dept});
  final String campus, dept;

  @override
  State<Succession> createState() => _SuccessionState();
}

class _SuccessionState extends State<Succession> {
  final _email = TextEditingController();
  String? _name;
  bool _looked = false, _busy = false;
  int _loads = 0;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _email.dispose();
    super.dispose();
  }

  /// Looks the address up once typing pauses.
  void _typed(Grant mine) {
    _debounce?.cancel();
    setState(() {
      _looked = false;
      _name = null;
    });
    if (_email.text.trim().isEmpty) return;
    _debounce = Timer(const Duration(milliseconds: 400), () => _lookUp(mine));
  }

  Future<void> _lookUp(Grant mine) async {
    final typed = _email.text;
    final problem = RoleStore.successorProblem(mine, typed);
    if (problem != null) {
      setState(() {
        _looked = true;
        _name = null;
      });
      return;
    }
    final n = await _roles.personName(typed.trim().toLowerCase());
    if (!mounted || typed != _email.text) return;
    setState(() {
      _looked = true;
      _name = n;
    });
  }

  Future<void> _cancel(Grant mine) async {
    setState(() => _busy = true);
    try {
      await _roles.cancelHandover(mine);
      await refreshMyRoles();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cancelled. The department is yours.')),
      );
      setState(() => _loads++);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(problem(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final caption = TypeScale.caption.copyWith(
      height: 1.45,
      color: p.textMuted,
    );
    return Loaded<Grant?>(
      key: ValueKey(_loads),
      load: () => _myGrant(widget.campus, widget.dept),
      builder: (context, mine, _) {
        if (mine == null) {
          return PageFrame(
            header: _header(widget.campus, widget.dept, 'Hand over'),
            children: [
              Note('Only a president of ${widget.dept} can hand it over.'),
            ],
          );
        }
        final scope = mine.programme ?? widget.dept;
        if (mine.handedTo case final to?) {
          return PageFrame(
            header: _header(widget.campus, scope, 'Hand over'),
            bottom: BottomAction(
              child: PrimaryButton(
                label: _busy ? 'Cancelling…' : 'Cancel the handover',
                onPressed: _busy ? null : () => _cancel(mine),
              ),
            ),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Handing over to $to',
                      style: TypeScale.body.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Both of you hold ${widget.dept} until '
                      '${shortDay(mine.expiresAt, year: true)}. Then your '
                      'access ends.',
                      style: caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.sm),
              Notice(
                text: TextSpan(
                  text:
                      'You can cancel until then: their access ends at once '
                      'and yours runs to '
                      '${shortDay(mine.expiresBefore ?? mine.expiresAt, year: true)} '
                      'again. After the overlap only an admin can give the '
                      'department back.',
                ),
              ),
            ],
          );
        }
        final address = _email.text.trim().toLowerCase();
        final problem = RoleStore.successorProblem(mine, address);
        final now = DateTime.now();
        final ends = RoleStore.outgoingExpiry(mine, now);
        final days = ends.difference(now).inDays;
        final ready = _looked && problem == null && _name != null;
        final who = ready ? _name! : 'They';
        return PageFrame(
          header: _header(
            widget.campus,
            scope,
            'Hand over',
            step: 'STEP 1 OF 3',
          ),
          bottom: BottomAction(
            child: PrimaryButton(
              label: 'Review the handover',
              onPressed:
                  ready
                      ? () => context.push(
                        Routes.deptSuccessionConfirm(
                          widget.campus,
                          widget.dept,
                          address,
                        ),
                      )
                      : null,
            ),
          ),
          children: [
            Text(
              'Name the next president of ${widget.dept} on '
              '${campusName(widget.campus)}. They start today; you keep '
              'access while you show them round.',
              style: TypeScale.body.copyWith(height: 1.45),
            ),
            const SizedBox(height: Space.md),
            AppTextField(
              controller: _email,
              label: 'Their BITS address',
              hint: 'f2024…@${widget.campus}.bits-pilani.ac.in',
              labelAbove: true,
              onChanged: (_) => _typed(mine),
            ),
            const SizedBox(height: Space.xs),
            if (!_looked)
              Text(
                'A successor must be on ${campusName(widget.campus)}, and '
                'must have signed in to Pointer once.',
                style: caption,
              )
            else if (problem != null)
              Text(problem, style: caption.copyWith(color: p.behind))
            else if (_name == null)
              Text(
                'Can not be found. They need to sign in to Pointer once first.',
                style: caption.copyWith(color: p.behind),
              )
            else
              Text(
                '✓ $_name · ${campusName(campusOfAddress(address)!)} address'
                ' — ${batchOfAddress(address)} batch',
                style: caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: p.text,
                ),
              ),
            const SectionLabel('What happens'),
            AppCard(
              child: Column(
                children: [
                  _Step(
                    1,
                    'Today.',
                    '$who ${ready ? 'becomes' : 'become'} president of '
                        '${widget.dept} on ${campusName(widget.campus)}.',
                  ),
                  _Step(
                    2,
                    'For $days days.',
                    'You both have full access. CRs, resources and course '
                        'structures stay with the department.',
                  ),
                  _Step(
                    3,
                    '${shortDay(ends, year: true)}.',
                    'Your access ends. The overlap never extends your own '
                        'term.',
                    ink: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.sm),
            const Notice(
              text: TextSpan(
                text:
                    'You can cancel while the overlap runs. After it, only an '
                    'admin can give the department back.',
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Board `SuccessionConfirm` (§13.4), step three: the department code is
/// typed, not tapped — it cannot be undone from inside the app once the
/// overlap ends.
class SuccessionConfirm extends StatefulWidget {
  const SuccessionConfirm({
    super.key,
    required this.campus,
    required this.dept,
    required this.to,
  });
  final String campus, dept, to;

  @override
  State<SuccessionConfirm> createState() => _SuccessionConfirmState();
}

class _SuccessionConfirmState extends State<SuccessionConfirm> {
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    setState(() => _busy = true);
    try {
      final mine = await _myGrant(widget.campus, widget.dept);
      if (mine == null) throw StateError('You no longer hold ${widget.dept}.');
      final ok = await _roles.handOver(mine, widget.to);
      if (!ok) throw StateError('${widget.to} has not signed in yet.');
      await refreshMyRoles();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Handed over to ${widget.to}.')));
      context.go(Routes.dept(widget.campus, widget.dept));
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is StateError ? e.message : problem(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final caption = TypeScale.caption.copyWith(
      height: 1.45,
      color: p.textMuted,
    );
    final typed = _code.text.trim().toUpperCase() == widget.dept;
    final campus = campusName(widget.campus);
    return Loaded<(Grant?, int?)>(
      load: () async {
        final mine = await _myGrant(widget.campus, widget.dept);
        int? crs;
        try {
          crs =
              (await _roles.roster(campus: widget.campus))
                  .where(
                    (g) =>
                        g.active &&
                        g.role == GrantRole.course &&
                        g.campus == widget.campus &&
                        deptOf(g.scope) == widget.dept,
                  )
                  .length;
        } catch (_) {}
        return (mine, crs);
      },
      builder: (context, data, _) {
        final (mine, crs) = data;
        final ends =
            mine == null
                ? null
                : RoleStore.outgoingExpiry(mine, DateTime.now());
        Widget side(String label, String name, String email) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TypeScale.label.copyWith(
                  color: p.hero,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TypeScale.body.copyWith(
                  fontWeight: FontWeight.w800,
                  color: p.isDark ? p.text : p.onInverse,
                ),
              ),
              Text(
                shortEmail(email),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TypeScale.caption.copyWith(color: p.navIcon),
              ),
            ],
          ),
        );
        return PageFrame(
          header: PageHeader(eyebrow: 'STEP 3 OF 3', title: 'Confirm'),
          bottom: BottomAction(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PrimaryButton(
                  label:
                      _busy
                          ? 'Handing over…'
                          : 'Hand ${widget.dept} to ${_id(widget.to)}',
                  onPressed: typed && !_busy ? _go : null,
                ),
                Center(child: TextLink('Not yet', onTap: () => context.pop())),
              ],
            ),
          ),
          children: [
            AppCard(
              color: p.navBackground,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HANDING OVER',
                    style: TypeScale.label.copyWith(
                      color: p.hero,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: Space.sm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      side('FROM', _roles.myName, _roles.me),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Space.sm,
                          vertical: 14,
                        ),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: p.hero,
                          size: 18,
                        ),
                      ),
                      side('TO', _id(widget.to), widget.to),
                    ],
                  ),
                  const SizedBox(height: Space.sm),
                  Text(
                    '${mine?.programme ?? widget.dept} '
                    '${departmentName(widget.dept)} · $campus'
                    '${crs == null ? '' : ' · $crs CR${crs == 1 ? ' moves' : 's move'} too'}',
                    style: TypeScale.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: p.navIcon,
                    ),
                  ),
                ],
              ),
            ),
            const SectionLabel('Type the department code to confirm'),
            AppTextField(
              controller: _code,
              label: 'Department code',
              hint: widget.dept,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: Space.xs),
            Text(
              'Typed, not tapped: once the overlap ends only an admin can undo '
              'it. Written to the audit log.',
              style: caption,
            ),
            const SectionLabel('After you confirm'),
            AppCard(
              child: Column(
                children: [
                  _Step(
                    1,
                    'Now.',
                    '${_id(widget.to)} is president of ${widget.dept} on '
                        '$campus.',
                  ),
                  _Step(
                    2,
                    'Until ${ends == null ? 'the overlap ends' : shortDay(ends, year: true)}.',
                    'You both hold the department, and you can cancel.',
                  ),
                  const _Step(
                    3,
                    'Then.',
                    'Your access ends; CRs, resources and course structures '
                        'stay.',
                    ink: true,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
