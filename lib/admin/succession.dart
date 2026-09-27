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

PageHeader _header(String campus, String dept, String title) => PageHeader(
  eyebrow: '$dept · ${campusName(campus).toUpperCase()}',
  title: title,
);

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

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _lookUp(Grant mine) async {
    final problem = RoleStore.successorProblem(mine, _email.text);
    if (problem != null) {
      setState(() {
        _looked = true;
        _name = null;
      });
      return;
    }
    final n = await _roles.personName(_email.text.trim().toLowerCase());
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
        final header = _header(widget.campus, widget.dept, 'Hand over');
        if (mine == null) {
          return PageFrame(
            header: header,
            children: [
              Note('Only a president of ${widget.dept} can hand it over.'),
            ],
          );
        }
        if (mine.handedTo case final to?) {
          return PageFrame(
            header: header,
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
              Text(
                'You can cancel until then: their access ends at once and '
                'yours runs to ${shortDay(mine.expiresBefore ?? mine.expiresAt, year: true)} '
                'again. After the overlap only an admin can give the '
                'department back.',
                style: caption,
              ),
              const SizedBox(height: Space.md),
              PrimaryButton(
                label: _busy ? 'Cancelling…' : 'Cancel the handover',
                onPressed: _busy ? null : () => _cancel(mine),
              ),
            ],
          );
        }
        final address = _email.text.trim().toLowerCase();
        final problem = RoleStore.successorProblem(mine, address);
        final now = DateTime.now();
        final ends = RoleStore.outgoingExpiry(mine, now);
        final ready = _looked && problem == null && _name != null;
        return PageFrame(
          header: header,
          children: [
            const SectionLabel('1 · Who takes over'),
            AppTextField(
              controller: _email,
              label: 'Their BITS address',
              onChanged:
                  (_) => setState(() {
                    _looked = false;
                    _name = null;
                  }),
            ),
            const SizedBox(height: Space.xs),
            if (!_looked)
              TextButton(
                onPressed: address.isEmpty ? null : () => _lookUp(mine),
                child: const Text('Look up'),
              )
            else if (problem != null)
              Text(problem, style: caption.copyWith(color: p.behind))
            else if (_name == null)
              Text(
                'Can not be found. They need to sign in to Pointer once first.',
                style: caption.copyWith(color: p.behind),
              )
            else
              AppCard(
                child: Text(
                  '$_name · ${campusName(campusOfAddress(address)!)} · '
                  'batch of ${batchOfAddress(address)}',
                  style: TypeScale.body.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            if (ready) ...[
              const SectionLabel('2 · What happens'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today: $_name becomes president of ${widget.dept} '
                      'on ${campusName(widget.campus)}.',
                      style: TypeScale.body,
                    ),
                    const SizedBox(height: Space.xs),
                    Text(
                      '${shortDay(ends, year: true)}: your access ends. '
                      'Until then you both hold the department.',
                      style: TypeScale.body,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.xs),
              Text(
                'The overlap never extends your own term. CRs, resources and '
                'course structures stay with the department. You can cancel '
                'while the overlap runs; after it, only an admin can give the '
                'department back.',
                style: caption,
              ),
              const SizedBox(height: Space.md),
              PrimaryButton(
                label: 'Continue',
                onPressed:
                    () => context.push(
                      Routes.deptSuccessionConfirm(
                        widget.campus,
                        widget.dept,
                        address,
                      ),
                    ),
              ),
            ],
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
    final typed = _code.text.trim().toUpperCase() == widget.dept;
    return PageFrame(
      header: _header(widget.campus, widget.dept, 'Confirm the handover'),
      children: [
        Text(
          'Hand ${widget.dept} to ${widget.to}. Type ${widget.dept} to '
          'confirm.',
          style: TypeScale.body,
        ),
        const SizedBox(height: Space.sm),
        AppTextField(
          controller: _code,
          label: 'Department code',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: Space.xs),
        Text(
          'Written to the audit log.',
          style: TypeScale.caption.copyWith(color: p.textMuted),
        ),
        const SizedBox(height: Space.md),
        PrimaryButton(
          label: _busy ? 'Handing over…' : 'Hand over',
          onPressed: typed && !_busy ? _go : null,
        ),
      ],
    );
  }
}
