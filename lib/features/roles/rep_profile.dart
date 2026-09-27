import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/routes.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/roles/contacts.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
  bool _showEmail = false, _showPhone = false, _busy = false;
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
    final wa = _whatsapp.text.trim();
    if (wa.isNotEmpty && !phonePattern.hasMatch(wa)) {
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
      await contactStore!.saveProfile(
        myRoles.value,
        name: _name.text,
        phone: _phone.text,
        showEmail: _showEmail,
        whatsapp: _whatsapp.text,
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

  Widget _switch(
    String title,
    String? subtitle,
    bool v,
    ValueChanged<bool> f,
  ) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(title, style: TypeScale.body),
    subtitle: subtitle == null ? null : Text(subtitle),
    value: v,
    onChanged: (x) => setState(() => f(x)),
  );

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final caption = TypeScale.caption.copyWith(
      height: 1.45,
      color: p.textMuted,
    );
    final roles = myRoles.value;
    final problem = _problem;
    return FutureBuilder<void>(
      future: _loaded,
      builder:
          (context, s) => PageFrame(
            header: PageHeader(
              eyebrow: roles.grants.map((g) => g.role.tag).toSet().join(' · '),
              title: profileDue.value ? 'Before you start' : 'Contact details',
            ),
            children: [
              if (s.connectionState != ConnectionState.done)
                const LinearProgressIndicator()
              else ...[
                Text(
                  'Other maintainers need a way to reach you'
                  '${_listed ? ', and so do the students you represent' : ''}.',
                  style: caption,
                ),
                const SizedBox(height: Space.md),
                AppTextField(
                  controller: _name,
                  label: 'Your name',
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: Space.sm),
                AppTextField(
                  controller: _phone,
                  label: 'Phone',
                  hint: 'Seen only by owners, admins, presidents and CRs',
                  onChanged: (_) => setState(() {}),
                ),
                if (_listed) ...[
                  const SectionLabel('What students see'),
                  AppCard(
                    child: Column(
                      children: [
                        _switch(
                          'Email',
                          roleStore?.me,
                          _showEmail,
                          (x) => _showEmail = x,
                        ),
                        _switch(
                          'Phone',
                          'The number above',
                          _showPhone,
                          (x) => _showPhone = x,
                        ),
                        AppTextField(
                          controller: _whatsapp,
                          label: 'WhatsApp (optional)',
                          dense: true,
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.xs),
                  Text(
                    'Each is separate. Listed on Representatives for '
                    '${campusName(campusOfAddress(roleStore?.me ?? '') ?? '')} '
                    'only. Anything shown can be screenshotted: turning it '
                    'off removes the listing, not what people already saw.',
                    style: caption,
                  ),
                ],
                const SizedBox(height: Space.md),
                if (problem != null)
                  Text(problem, style: caption.copyWith(color: p.behind)),
                const SizedBox(height: Space.sm),
                PrimaryButton(
                  label:
                      _busy
                          ? 'Saving…'
                          : profileDue.value
                          ? 'Save and continue'
                          : 'Save',
                  onPressed: _busy || problem != null ? null : _save,
                ),
                if (profileDue.value && widget.onSignOut != null)
                  TextButton(
                    onPressed: widget.onSignOut,
                    child: const Text('Sign out'),
                  ),
              ],
            ],
          ),
    );
  }
}
