import 'package:cgpa_calculator/core/storage/cache_boxes.dart';
import 'package:cgpa_calculator/auth_util.dart';
import 'package:cgpa_calculator/app/routes.dart';
import 'package:cgpa_calculator/core/models/programmes.dart';
import 'package:cgpa_calculator/core/platform/browser.dart';
import 'package:cgpa_calculator/core/prefs/prefs_store.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/features/roles/rep_profile.dart';
import 'package:cgpa_calculator/features/roles/role_switch_page.dart';
import 'package:cgpa_calculator/features/import/erp_import_page.dart';
import 'package:cgpa_calculator/features/settings/settings_controller.dart';
import 'package:cgpa_calculator/features/settings/settings_view.dart';
import 'package:cgpa_calculator/features/setup/programme_pick_page.dart';
import 'package:cgpa_calculator/script.dart';
import 'package:cgpa_calculator/sync.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cgpa_calculator/features/settings/install_guide.dart';
import 'package:cgpa_calculator/features/contribute/apply_page.dart';
import 'package:cgpa_calculator/features/contribute/contribute_data.dart';
import 'package:flutter/foundation.dart';
import 'package:cgpa_calculator/shared/widgets/confirm_dialog.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/pill_button.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:flutter/material.dart';

/// Settings. Discipline changes only set [erase]; the home screen applies
/// them through initializeCourses when this page closes, as before.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

/// Signs out, clears this device's copy and starts over.
Future<void> signOut() async {
  await Sync.stop();
  await FirebaseAuth.instance.signOut();
  await Sync.clearLocal();
  await clearAccountCaches();
  reloadPage();
}

/// Settings › Discipline: Pick a programme, with the same filter as setup's
/// picker — M.Sc. for the dual half, B.E. (never A5) for the other — plus
/// the current code and the choices that are not programmes.
Future<String?> pickDisciplineHalf(
  BuildContext context, {
  required bool dual,
  required String half,
}) {
  final choices = disciplineOptions(dual: dual, current: half);
  final options = [
    for (final p in programmesAt(campus))
      if (dual ? p.isMsc : !p.isMsc && p.code != 'A5') p,
  ];
  if (programmeFor(half) case final cur? when !options.contains(cur)) {
    options.add(cur);
  }
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      builder:
          (_) => ProgrammePickPage(
            heading: dual ? 'Dual degree' : 'Discipline',
            options: options,
            selected: half,
            extras: [
              for (final (code, label) in choices)
                if (programmeFor(code) == null) (code, label),
            ],
          ),
    ),
  );
}

class _SettingsPageState extends State<SettingsPage> {
  User? get _user => FirebaseAuth.instance.currentUser;

  void _again() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    contribState.addListener(_again);
    refreshContribState();
  }

  @override
  void dispose() {
    contribState.removeListener(_again);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    return Theme(
      data: thm.materialTheme,
      child: Builder(
        builder:
            (context) => SettingsView(
              name:
                  user?.displayName?.trim().isNotEmpty == true
                      ? user!.displayName!.trim()
                      : firstNameOf(user),
              email: user?.email ?? 'Not signed in',
              discipline: selecteddiscipline,
              batch: batch,
              isDark: thm.isDark,
              profiles: profileNames,
              onClose: () => Navigator.of(context).maybePop(),
              onPickDiscipline: (dual) => _pickDiscipline(context, dual),
              campus: campus?.label,
              onTheme: _setTheme,
              showOffshoot: !offshootHiddenNow.value,
              onShowOffshoot: prefsStore == null ? null : _setShowOffshoot,
              onRenameProfile: (i) => _renameProfile(context, i),
              onExport: () => _exportCsv(context),
              onImportOld: () => _importFromOldSite(context),
              onImportErp: kIsWeb ? () => _importFromErp(context) : null,
              onReport: () => _submitReport(context),
              onReset: () => _reset(context),
              onSignOut: _signOut,
              onInstall: kIsWeb ? () => _install(context) : null,
              installed: kIsWeb && isStandalone(),
              onEmail: () => openUrl('mailto:mishra.siddharth@icloud.com'),
              onGithub: () => openUrl('https://github.com/e-iotapi'),
              // Your roles (ARCHITECTURE.md §16.4): owners and live grants.
              workingAs: myRoles.value.owner
                  ? (viewAs.value?.label ?? 'Owner')
                  : roleLabel(workingAs.value),
              onWorkingAs: myRoles.value.privileged
                  ? () async {
                      await openRoute(
                        context,
                        myRoles.value.owner ? Routes.openAs : Routes.roles,
                        () => const RoleSwitchPage(),
                      );
                      if (mounted) setState(() {});
                    }
                  : null,
              onContribute:
                  roleStore == null ||
                          myRoles.value.privileged ||
                          const [
                            ContribState.applied,
                            ContribState.approved,
                          ].contains(contribState.value)
                      ? null
                      : () => openRoute(
                        context,
                        Routes.contributeApply,
                        () => const ApplyPage(),
                      ),
              contactSummary: myContactSummary.value ?? 'Not set',
              onContact: myRoles.value.privileged
                  ? () async {
                      await openRoute(
                        context,
                        Routes.welcome,
                        () => const RepProfilePage(),
                      );
                      if (mounted) setState(() {});
                    }
                  : null,
              onControls: myRoles.value.reachesAdmin
                  ? () => openRoute(context, Routes.admin, () => const SizedBox())
                  : null,
            ),
      ),
    );
  }

  Future<bool> _confirm(
    BuildContext context,
    String title,
    String body,
    String action,
  ) async {
    return confirmDialog(context, title: title, body: body, action: action);
  }

  Future<void> _pickDiscipline(BuildContext context, bool dual) async {
    final half =
        dual
            ? selecteddiscipline.substring(0, 2)
            : selecteddiscipline.substring(2, 4);
    final v = await pickDisciplineHalf(context, dual: dual, half: half);
    if (v == null || v == half || !context.mounted) return;
    final change = changeDiscipline(
      selecteddiscipline,
      dual: dual,
      value: v,
      erase: erase,
    );
    final warning = eraseWarning(change.erase);
    if (warning != null &&
        change.erase != erase &&
        !await _confirm(context, 'Change discipline?', warning, 'Change')) {
      return;
    }
    setState(() {
      erase = change.erase;
      selecteddiscipline = change.discipline;
      selectdual = selecteddiscipline.substring(0, 2);
      selecengg = selecteddiscipline.substring(2, 4);
    });
  }

  Future<void> _install(BuildContext context) => offerInstall(context);

  /// Tap only; the store writes the device copy first, so a failed sync
  /// leaves the switch where the person put it.
  Future<void> _setShowOffshoot(bool show) async {
    final done = prefsStore!.setOffshootHidden(!show);
    setState(() {});
    try {
      await done;
    } catch (e) {
      debugPrint('prefs: $e');
    }
  }

  Future<void> _setTheme(bool dark) => switchTheme(
    dark,
    then: () {
      if (mounted) setState(() {});
    },
  );

  Future<void> _renameProfile(BuildContext context, int i) async {
    final controller = TextEditingController(text: profileNames[i - 1]);
    final name = await showDialog<String>(
      context: context,
      builder:
          (c) => AppDialog(
            title: 'Name profile $i',
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLength: 9,
              style: appFieldStyle(AppPalette.of(c)),
              cursorColor: AppPalette.of(c).text,
              decoration: appFieldDecoration(
                AppPalette.of(c),
                helper: 'Nine letters at most',
              ),
              onSubmitted: (t) => Navigator.pop(c, t),
            ),
            actions: [
              DialogAction('Cancel', onTap: () => Navigator.pop(c)),
              DialogAction(
                'Save',
                onTap: () => Navigator.pop(c, controller.text),
                ink: true,
              ),
            ],
          ),
    );
    controller.dispose();
    if (name == null) return;
    final blank = name.trim().isEmpty;
    setState(() {
      final n = profileName(name, 'Profile $i');
      switch (i) {
        case 1:
          profile1n = n;
        case 2:
          profile2n = n;
        default:
          moreProfileNames[i - 3] = n;
      }
    });
    await setprof();
    // A spaces-only name is silently dropped to the default (BUG-28): say so.
    if (blank && context.mounted) {
      _toast(context, "A blank name isn't allowed — kept 'Profile $i'.");
    }
  }

  Future<void> _reset(BuildContext context) async {
    if (!await _confirm(
      context,
      'Reset courses?',
      'This reloads the course list for your discipline and deletes your '
          'grades. It cannot be undone.',
      'Reset',
    )) {
      return;
    }
    erase = 1;
    await initializeCourses();
    if (context.mounted) _toast(context, 'Courses reset.');
  }

  Future<void> _signOut() => signOut();

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(behavior: SnackBarBehavior.floating, content: Text(msg)),
    );
  }

  void _exportCsv(BuildContext context) {
    try {
      _toast(context, 'Downloaded ${exportGradesCsv()}');
    } catch (e) {
      _toast(context, 'Export failed: $e');
    }
  }

  /// Reads the ERP performance sheet PDF, shows what it changes, then sets
  /// Actual grades from it.
  Future<void> _importFromErp(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ErpImportPage()),
    );
    if (mounted) setState(() {});
  }

  Future<void> _importFromOldSite(BuildContext context) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (c) => StatefulBuilder(
            builder:
                (c, setDialog) => AppDialog(
                  title: 'Import from old site',
                  content: TextField(
                    controller: controller,
                    maxLines: 8,
                    onChanged: (_) => setDialog(() {}),
                    style: appFieldStyle(AppPalette.of(c)),
                    cursorColor: AppPalette.of(c).text,
                    decoration: appFieldDecoration(
                      AppPalette.of(c),
                      hint: 'Paste the JSON copied from the old site',
                    ),
                  ),
                  actions: [
                    DialogAction(
                      'Cancel',
                      onTap: () => Navigator.pop(c, false),
                    ),
                    DialogAction(
                      'Import',
                      // Disabled while empty, not a silent no-op (BUG-44).
                      onTap:
                          controller.text.trim().isEmpty
                              ? null
                              : () => Navigator.pop(c, true),
                      ink: true,
                    ),
                  ],
                ),
          ),
    );
    final text = controller.text;
    controller.dispose();
    if (ok != true) return;
    try {
      await Sync.apply(text);
      await Sync.push();
      reloadPage();
    } catch (e) {
      if (context.mounted) {
        _toast(context, "That doesn't look like exported data. Import failed.");
      }
    }
  }

  Future<void> _submitReport(BuildContext context) async {
    final controller = TextEditingController();
    var type = 'Bug';
    const types = ['Bug', 'Missing course', 'Suggestion'];
    final send = await showDialog<bool>(
      context: context,
      builder:
          (c) => StatefulBuilder(
            builder:
                (c, setDialog) => AppDialog(
                  title: 'Report a problem',
                  body: 'Sent with your email so a reply is possible.',
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final t in types)
                            PillButton(
                              label: t,
                              selected: type == t,
                              onPressed: () => setDialog(() => type = t),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: controller,
                        maxLines: 5,
                        maxLength: 2000,
                        style: appFieldStyle(AppPalette.of(c)),
                        cursorColor: AppPalette.of(c).text,
                        decoration: appFieldDecoration(
                          AppPalette.of(c),
                          hint: 'What went wrong, or which course is missing?',
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    DialogAction('Cancel', onTap: () => Navigator.pop(c, false)),
                    DialogAction(
                      'Send',
                      onTap: () => Navigator.pop(c, true),
                      ink: true,
                    ),
                  ],
                ),
          ),
    );
    final message = controller.text.trim();
    controller.dispose();
    if (send != true || !context.mounted) return;
    if (message.isEmpty) {
      _toast(context, 'Nothing to send — the message was empty.');
      return;
    }
    final user = _user;
    if (user == null) {
      _toast(context, 'You need to be signed in to send a report.');
      return;
    }
    try {
      await FirebaseFirestore.instance.collection('reports').add({
        'uid': user.uid,
        'email': user.email ?? '',
        'type': type,
        'message': message,
        'discipline': selecteddiscipline,
        'batch': batch,
        'appVersion': '2.3.1+131',
        'userAgent': userAgent(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (context.mounted) _toast(context, 'Thanks — your report was sent.');
    } catch (e) {
      if (context.mounted) _toast(context, 'Could not send the report: $e');
    }
  }
}
