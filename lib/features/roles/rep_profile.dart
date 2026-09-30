import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/routes.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/roles/contacts.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/bottom_action.dart';
import 'package:cgpa_calculator/shared/widgets/card_row.dart';
import 'package:cgpa_calculator/shared/widgets/notice.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The signed-in user's contact store, or `null` before sign-in.
ContactStore? get contactStore => switch (roleStore) {
  final r? => ContactStore(r),
  null => null,
};

/// After roles load: is RepProfile due, and what do Settings show?
Future<void> checkProfile() async {
  final store = contactStore;
  final r = myRoles.value;
  if (store == null || !r.privileged) return;
  try {
    final dir = await store.myDirectory();
    final staff = await store.myStaffContact();
    myContactSummary.value =
        dir?.summary ?? (staff == null ? null : 'Phone, for staff only');
    profileDue.value = needsProfile(
      r,
      hasStaffContact: staff != null,
      directory: dir,
    );
  } on Object catch (e) {
    debugPrint('[Pointer contacts] check failed: $e');
  }
}

/// Board `RepProfile` ("Before you start", §16.3 fix 8). Served first after
/// an appointment and impossible to skip — Sign out is the only other way
/// off it. Reopened from Settings › Contact details.
class RepProfilePage extends StatefulWidget {
  const RepProfilePage({super.key, this.onSignOut});

  /// Offered while the page is forced.
  final VoidCallback? onSignOut;

  @override
  State<RepProfilePage> createState() => _RepProfilePageState();
}

class _RepProfilePageState extends State<RepProfilePage> {
  final _name = TextEditingController(text: roleStore?.myName ?? '');
  final _phone = TextEditingController();
  final _whatsapp = TextEditingController();
  bool _showEmail = false, _showPhone = false, _showWa = false, _busy = false;
  late final Future<void> _loaded = _load();

  bool get _listed => listedRoles(myRoles.value).isNotEmpty;

  Future<void> _load() async {
    final store = contactStore;
    if (store == null) return;
    final staff = await store.myStaffContact();
    final dir = await store.myDirectory();
    if (staff != null) {
      _name.text = staff.name;
      _phone.text = staff.phone;
    }
    if (dir != null) {
      _name.text = dir.name;
      _showEmail = dir.shownEmail != null;
      _whatsapp.text = dir.whatsapp ?? '';
      _showWa = _whatsapp.text.isNotEmpty;
      _showPhone = dir.phone != null;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _whatsapp.dispose();
    super.dispose();
  }

  String? get _problem {
    if (_name.text.trim().isEmpty) return 'Add your name.';
    if (!phonePattern.hasMatch(_phone.text.trim())) {
      return 'Add a phone number other maintainers can reach you on.';
    }
    final wa = _showWa ? _whatsapp.text.trim() : '';
    if (_showWa && !phonePattern.hasMatch(wa)) {
      return 'That WhatsApp number does not look right.';
    }
    if (_listed && !_showEmail && !_showPhone && wa.isEmpty) {
      return 'Show students at least one way to reach you.';
    }
    return null;
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      // The listing must match each grant's expiry as it stands now; a
      // cached copy (up to 7 days old) misses a handover or renewal.
      await refreshMyRoles();
      await contactStore!.saveProfile(
        myRoles.value,
        name: _name.text,
        phone: _phone.text,
        showEmail: _showEmail,
        whatsapp: _showWa ? _whatsapp.text : '',
        showPhone: _showPhone,
      );
      final forced = profileDue.value;
      await checkProfile();
      if (!mounted) return;
      if (forced) {
        context.go(Routes.roles);
      } else {
        Navigator.of(context).maybePop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(problem(e))));
      }
    }
  }

  /// A board switch row: the title over its detail, the themed switch.
  Widget _switch(String title, String? subtitle, bool v, ValueChanged<bool> f) {
    final p = AppPalette.of(context);
    // One node: the switch is announced with its title.
    return MergeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TypeScale.body.copyWith(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: p.text,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TypeScale.caption.copyWith(color: p.textMuted),
                    ),
                ],
              ),
            ),
            const SizedBox(width: Space.sm),
            Switch(value: v, onChanged: (x) => setState(() => f(x))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final roles = myRoles.value;
    final forced = profileDue.value;
    final grants = roles.grants;
    final by =
        grants.map((g) => g.grantedByName).where((n) => n.isNotEmpty).toSet();
    final campus = campusName(campusOfAddress(roleStore?.me ?? '') ?? '');
    return FutureBuilder<void>(
      future: _loaded,
      builder: (context, s) {
        // After the load, so saved details count.
        final problem = _problem;
        return PageFrame(
          header: PageHeader(
            eyebrow: forced ? "YOU'VE BEEN APPOINTED" : 'CONTACT DETAILS',
            title: forced ? 'Before you start' : 'Contact details',
            back: !forced,
            actions: [
              // Not skippable: signing out is the only other way off.
              if (forced && widget.onSignOut != null)
                TextButton(
                  onPressed: widget.onSignOut,
                  style: TextButton.styleFrom(
                    foregroundColor: p.text,
                    minimumSize: const Size(44, 44),
                  ),
                  child: const Text('Sign out'),
                ),
            ],
          ),
          bottom:
              s.connectionState != ConnectionState.done
                  ? null
                  : BottomAction(
                    caption: problem,
                    child: PrimaryButton(
                      label:
                          _busy
                              ? 'Saving…'
                              : forced
                              ? 'Save and continue'
                              : 'Save',
                      onPressed: _busy || problem != null ? null : _save,
                    ),
                  ),
          children: [
            if (s.connectionState != ConnectionState.done)
              const LinearProgressIndicator()
            else ...[
              if (grants.isNotEmpty)
                Container(
                  padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
                  decoration: BoxDecoration(
                    // Ink in both modes, as on Controls.
                    color: p.navBackground,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final g in grants)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              TierTag.of(g.role),
                              if (g.role != GrantRole.admin) ...[
                                ScopeChip(
                                  campusName(g.campus),
                                  icon: Icons.place_outlined,
                                ),
                                ScopeChip(g.scopeLabel, muted: true),
                              ],
                            ],
                          ),
                        ),
                      Text(
                        '${by.isEmpty ? '' : 'Appointed by ${by.join(', ')}. '}'
                        'Other maintainers need a way to reach you'
                        '${_listed ? ', and so do the students you represent' : ''}.',
                        style: TypeScale.caption.copyWith(
                          fontSize: 11.5,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                          color: p.navIcon,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: Space.sm),
              AppCard(
                child: AppTextField(
                  controller: _name,
                  label: 'Your name, as students see it',
                  labelAbove: true,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: Space.sm),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppTextField(
                      controller: _phone,
                      label: 'Phone number · required',
                      hint: '+91 98xxx xxxxx',
                      labelAbove: true,
                      onChanged: (_) => setState(() {}),
                    ),
                    const Note(
                      'Seen only by owners, admins, presidents and CRs.',
                    ),
                  ],
                ),
              ),
              if (_listed) ...[
                const SectionLabel('Shown to students · at least one'),
                AppCard(
                  child: Column(
                    children: [
                      _switch(
                        'BITS email',
                        roleStore?.me,
                        _showEmail,
                        (x) => _showEmail = x,
                      ),
                      const CardDivider(),
                      _switch('WhatsApp', null, _showWa, (x) {
                        _showWa = x;
                        if (x && _whatsapp.text.trim().isEmpty) {
                          _whatsapp.text = _phone.text.trim();
                        }
                      }),
                      if (_showWa) ...[
                        AppTextField(
                          controller: _whatsapp,
                          label: 'WhatsApp number',
                          labelAbove: true,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: Space.sm),
                      ],
                      const CardDivider(),
                      _switch(
                        'Phone call',
                        'The number above',
                        _showPhone,
                        (x) => _showPhone = x,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Space.sm),
                Notice(
                  text: TextSpan(
                    text:
                        'Listed on Representatives for $campus only. '
                        'Anything shown can be screenshotted: turning it off '
                        'removes the listing, not what people already saw.',
                  ),
                ),
              ],
            ],
          ],
        );
      },
    );
  }
}
