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
  final g = await _roles.grant(
    grantId(GrantRole.dept, campus, dept, _roles.me),
  );
  return g != null && g.liveAt(DateTime.now()) ? g : null;
}

/// The grant the pages show: the signed-in president's, or, for an owner or
/// admin previewing the department (Open as), its live president's, so the
/// preview is the real screen. Only [_myGrant] is ever handed over.
Future<Grant?> _shownGrant(String campus, String dept) async {
  final mine = await _myGrant(campus, dept);
  final r = myRoles.value;
  if (mine != null || !(r.owner || r.admin)) return mine;
  final now = DateTime.now();
  return (await _roles.roster(campus: campus))
      .where(
        (g) =>
            g.role == GrantRole.dept &&
            g.scope == dept &&
            g.campus == campus &&
            g.liveAt(now),
      )
      .firstOrNull;
}

/// Whether [g] is someone else's: the owner or an admin previewing.
bool _previewing(Grant g) => g.email != _roles.me;

/// The line atop a preview.
Widget _previewNote(Grant g) => Padding(
  padding: const EdgeInsets.only(bottom: Space.sm),
  child: Note(
    'Previewing as ${g.name.isEmpty ? g.email : g.name}. Only they can hand '
    'it over.',
  ),
);

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
  // Two of the same lookup: the next president, and an optional secretary.
  final _email = TextEditingController(), _sec = TextEditingController();
  final _name = <TextEditingController, String?>{};
  final _looked = <TextEditingController>{};
  final _debounce = <TextEditingController, Timer>{};
  bool _busy = false;
  int _loads = 0;

  @override
  void dispose() {
    for (final t in _debounce.values) {
      t.cancel();
    }
    _email.dispose();
    _sec.dispose();
    super.dispose();
  }

  /// Looks the address up once typing pauses.
  void _typed(Grant mine, TextEditingController c) {
    _debounce[c]?.cancel();
    setState(() {
      _looked.remove(c);
      _name[c] = null;
    });
    if (c.text.trim().isEmpty) return;
    _debounce[c] = Timer(
      const Duration(milliseconds: 400),
      () => _lookUp(mine, c),
    );
  }

  Future<void> _lookUp(Grant mine, TextEditingController c) async {
    final typed = c.text;
    final problem = RoleStore.successorProblem(mine, typed);
    if (problem != null) {
      setState(() {
        _looked.add(c);
        _name[c] = null;
      });
      return;
    }
    final n = await _roles.personName(typed.trim().toLowerCase());
    if (!mounted || typed != c.text) return;
    setState(() {
      _looked.add(c);
      _name[c] = n;
    });
  }

  /// The line under an address field: the rule, the problem, or who it is.
  Widget _status(Grant mine, TextEditingController c, String rule) {
    final p = AppPalette.of(context);
    final caption = TypeScale.caption.copyWith(
      height: 1.45,
      color: p.textMuted,
    );
    final address = c.text.trim().toLowerCase();
    final problem = RoleStore.successorProblem(mine, address);
    if (!_looked.contains(c)) return Text(rule, style: caption);
    if (problem != null) {
      return Text(problem, style: caption.copyWith(color: p.behind));
    }
    if (_name[c] == null) {
      return Text(
        'Can not be found. They need to sign in to Pointer once first.',
        style: caption.copyWith(color: p.behind),
      );
    }
    return Text(
      '✓ ${_name[c]} · ${campusName(campusOfAddress(address)!)} address'
      ' — ${batchOfAddress(address)} batch',
      style: caption.copyWith(fontWeight: FontWeight.w700, color: p.text),
    );
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
      load: () => _shownGrant(widget.campus, widget.dept),
      builder: (context, mine, _) {
        if (mine == null) {
          return PageFrame(
            header: _header(widget.campus, widget.dept, 'Hand over'),
            children: [
              Note(
                myRoles.value.owner || myRoles.value.admin
                    ? 'Nobody is president of ${branchCode(widget.dept)} on '
                        '${campusName(widget.campus)} yet, so there is '
                        'nothing to hand over. Appoint one from People.'
                    : 'Only a president of ${branchCode(widget.dept)} can '
                        'hand it over.',
              ),
            ],
          );
        }
        final scope = mine.scopeLabel;
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
        final secAddress = _sec.text.trim().toLowerCase();
        final secReady =
            secAddress.isEmpty ||
            (_looked.contains(_sec) &&
                _name[_sec] != null &&
                secAddress != address &&
                RoleStore.successorProblem(mine, secAddress) == null);
        final ready =
            _looked.contains(_email) &&
            problem == null &&
            _name[_email] != null &&
            secReady;
        final who = ready ? _name[_email]! : 'They';
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
                          secretary: secAddress.isEmpty ? null : secAddress,
                        ),
                      )
                      : null,
            ),
          ),
          children: [
            if (_previewing(mine)) _previewNote(mine),
            Text(
              'Name the next president of ${mine.scopeLabel} on '
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
              onChanged: (_) => _typed(mine, _email),
            ),
            const SizedBox(height: Space.xs),
            _status(
              mine,
              _email,
              'A successor must be on ${campusName(widget.campus)}, and '
              'must have signed in to Pointer once.',
            ),
            const SizedBox(height: Space.md),
            AppTextField(
              controller: _sec,
              label: 'Next secretary (optional)',
              hint: 'f2024…@${widget.campus}.bits-pilani.ac.in',
              labelAbove: true,
              onChanged: (_) => _typed(mine, _sec),
            ),
            const SizedBox(height: Space.xs),
            _status(
              mine,
              _sec,
              'Their term ends with the new president\'s. The current '
              'secretary\'s ends with yours.',
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
    this.secretary,
  });
  final String campus, dept, to;

  /// The next secretary's address, when one was named.
  final String? secretary;

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
      if (mine == null) {
        final r = myRoles.value;
        throw StateError(
          r.owner || r.admin
              ? 'This is a preview. Only the president can hand '
                  '${widget.dept} over.'
              : 'You no longer hold ${widget.dept}.',
        );
      }
      final ok = await _roles.handOver(
        mine,
        widget.to,
        secretary: widget.secretary,
      );
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
        final mine = await _shownGrant(widget.campus, widget.dept);
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
            if (mine != null && _previewing(mine)) _previewNote(mine),
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
                  if (widget.secretary case final sec?) ...[
                    const SizedBox(height: Space.sm),
                    side('NEXT SECRETARY', _id(sec), sec),
                  ],
                  const SizedBox(height: Space.sm),
                  Text(
                    '${branchCode(widget.dept, mine?.programme)} '
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
                    '${_id(widget.to)} is president of '
                        '${branchCode(widget.dept, mine?.programme)} on '
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
