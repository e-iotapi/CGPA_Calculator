import 'package:cgpa_calculator/admin/widgets.dart' show TierTag;
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/auth_util.dart';
import 'package:cgpa_calculator/core/models/programmes.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/features/setup/degree_setup_page.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart'
    show PrimaryButton;
import 'package:cgpa_calculator/shared/widgets/bottom_action.dart';
import 'package:cgpa_calculator/shared/widgets/pill_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The router sends every location to owner setup while this is true.
final ownerSetupDue = ValueNotifier<bool>(false);

/// An owner whose sign-in is not a BITS address, with no campus stored yet.
bool ownerSetupNeeded(MyRoles roles, String? email, String? storedCampus) =>
    roles.owner &&
    (email == null || campusOfAddress(email) == null) &&
    storedCampus == null;

/// Owner setup (§10.21): campus and batch for a non-BITS owner.
class OwnerSetupPage extends StatefulWidget {
  const OwnerSetupPage({super.key, required this.email, required this.onDone});

  final String? email;
  final VoidCallback onDone;

  @override
  State<OwnerSetupPage> createState() => _OwnerSetupPageState();
}

class _OwnerSetupPageState extends State<OwnerSetupPage> {
  Campus? _campus;
  final _year = TextEditingController();
  var _busy = false;

  int? get _yearValue {
    final y = int.tryParse(_year.text);
    return y != null && yearInRange(y) ? y : null;
  }

  @override
  void dispose() {
    _year.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    setState(() => _busy = true);
    await saveCampusAndBatch(_campus!, _yearValue!);
    if (!mounted) return;
    setState(() => _busy = false);
    widget.onDone();
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
    final ready = _campus != null && _yearValue != null;

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
                    Text('ONE-TIME SETUP · OWNER', style: label),
                    const SizedBox(height: 3),
                    Semantics(
                      header: true,
                      child: Text(
                        'Campus and batch',
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
                      'Your sign-in isn\'t a BITS address, so Pointer can\'t '
                      'read your campus or batch. Set them once here.',
                      style: body,
                    ),
                    const SizedBox(height: Space.md),
                    Container(
                      padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SIGNED IN AS', style: label),
                          const SizedBox(height: 7),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.email ?? '',
                                  overflow: TextOverflow.ellipsis,
                                  style: body.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: p.text,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const TierTag('OWNER', strong: true),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Space.lg),
                    Text('CAMPUS', style: label),
                    const SizedBox(height: 8),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      mainAxisExtent: 38,
                      children: [
                        for (final c in Campus.values)
                          PillButton(
                            label: c.label,
                            height: 38,
                            expand: true,
                            selected: _campus == c,
                            onPressed: () => setState(() => _campus = c),
                          ),
                      ],
                    ),
                    const SizedBox(height: Space.lg),
                    Text('BATCH', style: label),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _year,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      onChanged: (_) => setState(() {}),
                      style: body.copyWith(color: p.text, fontSize: 14),
                      decoration: InputDecoration(
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
                    const SizedBox(height: 6),
                    Text(
                      'The year you joined. It sets which semesters you see.',
                      style: body.copyWith(fontSize: 11),
                    ),
                  ],
                ),
                BottomAction(
                  caption:
                      'Both are final once set, as they are for everyone '
                      'else.',
                  child: PrimaryButton(
                    tall: true,
                    label: 'Continue',
                    onPressed: ready && !_busy ? _continue : null,
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
