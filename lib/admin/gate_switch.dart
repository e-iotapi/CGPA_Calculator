import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/cache/cache_first.dart';
import 'package:cgpa_calculator/core/reviews/gate_store.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/features/reviews/gate_ui.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/card_row.dart';
import 'package:cgpa_calculator/shared/widgets/icon_dialog.dart';
import 'package:cgpa_calculator/shared/widgets/notice.dart';
import 'package:flutter/material.dart';

const _gateCampuses = ['goa', 'hyderabad', 'pilani', 'dubai'];

/// Board `CompulsorySwitch`: the review gate for a campus, as one row on
/// DeptHome (that president's campus, their [dept]) and AdminHome (pills
/// pick the campus, no [dept]). Switching on asks first (`SwitchOn`); off
/// does not.
class GateSwitchRow extends StatefulWidget {
  const GateSwitchRow({super.key, required this.campus, this.dept});
  final String campus;

  /// The department the writer holds; null for owners and admins.
  final String? dept;

  @override
  State<GateSwitchRow> createState() => _GateSwitchRowState();
}

class _GateSwitchRowState extends State<GateSwitchRow> {
  late String _campus = widget.campus;
  GateInfo? _info;
  bool _busy = false;
  String? _failed;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Draws the saved row at once, then refreshes behind it.
  Future<void> _load() async {
    final roles = roleStore;
    if (roles == null) return;
    final c = _campus;
    setState(() {
      _info = peekGateInfo(_campus);
      _failed = null;
    });
    try {
      final v = await gateInfo(c);
      if (mounted && c == _campus) setState(() => _info = v);
    } catch (e) {
      if (mounted && c == _campus && _info == null) {
        setState(() => _failed = problem(e));
      }
    }
  }

  Future<void> _set(bool on) async {
    if (on &&
        await showDialog<bool>(
              context: context,
              builder:
                  (_) => IconDialog(
                    icon: Icons.lock_outline_rounded,
                    title: 'Turn on forced reviews for ${campusName(_campus)}?',
                    body:
                        'Every student will need to review their electives, up '
                        'to 5, before they can read any review. You can turn '
                        'it off any time.',
                    primary: 'Turn on',
                    secondary: 'Cancel',
                  ),
            ) !=
            true) {
      return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await GateStore(roleStore!).set(_campus, on, dept: widget.dept);
      await forget('gateinfo|$_campus');
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(problem(e))));
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  String _subtitle() {
    final i = _info;
    if (i == null) return 'Students must review their electives';
    if (!i.on) return 'Off · reviews are open to everyone';
    final since =
        i.at == null
            ? null
            : shortDay(DateTime.fromMillisecondsSinceEpoch(i.at!), year: true);
    return [
      'On',
      if (i.by != null) 'turned on by ${i.by}',
      if (since != null) 'since $since',
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final on = _info?.on ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.dept == null) ...[
          ChoicePills<String>(
            values: _gateCampuses,
            selected: _campus,
            label: campusName,
            onSelected: (c) {
              _campus = c;
              _load();
            },
          ),
          const SizedBox(height: Space.sm),
        ],
        if (_failed != null && _info == null) ...[
          Notice(text: TextSpan(text: _failed), warning: true),
          const SizedBox(height: Space.sm),
          SizedBox(
            height: Sizes.minTouch,
            child: OutlinedButton(onPressed: _load, child: const Text('Try again')),
          ),
          const SizedBox(height: Space.sm),
        ],
        AppCard(
          padding: EdgeInsets.zero,
          child: CardRow(
            leading: IconTile(Icons.lock_outline_rounded),
            title: 'Compulsory reviews',
            titleLines: 2,
            subtitle: _subtitle(),
            minHeight: 58,
            trailing: Semantics(
              label: 'Compulsory reviews',
              child: Switch(
                value: on,
                onChanged: _busy || _info == null ? null : _set,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
