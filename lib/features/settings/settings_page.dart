import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/auth_util.dart';
import 'package:cgpa_calculator/core/models/programmes.dart';
import 'package:cgpa_calculator/core/platform/browser.dart';
import 'package:cgpa_calculator/features/import/erp_import_page.dart';
import 'package:cgpa_calculator/features/settings/settings_controller.dart';
import 'package:cgpa_calculator/features/settings/settings_view.dart';
import 'package:cgpa_calculator/script.dart';
import 'package:cgpa_calculator/sync.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cgpa_calculator/features/settings/install_guide.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Settings. Discipline changes only set [erase]; the home screen applies
/// them through initializeCourses when this page closes, as before.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  User? get _user => FirebaseAuth.instance.currentUser;

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
              onPickBatch: () => _pickBatch(context),
              campus: campus?.label,
              onPickCampus: () => _pickCampus(context),
              onTheme: _setTheme,
              onRenameProfile: (i) => _renameProfile(context, i),
              onExport: () => _exportCsv(context),
              onImportBackup: () => _importFromFile(context),
              onImportOld: () => _importFromOldSite(context),
              onImportErp: kIsWeb ? () => _importFromErp(context) : null,
              onReport: () => _submitReport(context),
              onReset: () => _reset(context),
              onSignOut: _signOut,
              onInstall: kIsWeb ? () => _install(context) : null,
              installed: kIsWeb && isStandalone(),
              onEmail:
                  () => launchUrl(Uri.parse('mailto:siddhu.cms@gmail.com')),
              onGithub:
                  () => launchUrl(
                    Uri.parse('https://github.com/e-iotapi'),
                    mode: LaunchMode.externalApplication,
                  ),
            ),
      ),
    );
  }

  Future<T?> _pick<T>(
    BuildContext context,
    String title,
    List<(T, String)> options,
    T current,
  ) {
    final p = AppPalette.of(context);
    return showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: p.background,
      builder:
          (c) => ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(c).height * 0.7,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: Space.lg),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.gutter,
                    0,
                    Space.gutter,
                    Space.sm,
                  ),
                  child: Text(
                    title,
                    style: TypeScale.title.copyWith(color: p.text),
                  ),
                ),
                for (final (v, label) in options)
                  ListTile(
                    title: Text(
                      label,
                      style: TypeScale.body.copyWith(color: p.text),
                    ),
                    trailing:
                        v == current
                            ? Icon(Icons.check_rounded, color: p.accent)
                            : null,
                    selected: v == current,
                    onTap: () => Navigator.pop(c, v),
                  ),
              ],
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
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text(action),
              ),
            ],
          ),
    );
    return ok == true;
  }

  Future<void> _pickDiscipline(BuildContext context, bool dual) async {
    final half =
        dual
            ? selecteddiscipline.substring(0, 2)
            : selecteddiscipline.substring(2, 4);
    final v = await _pick(
      context,
      dual ? 'Dual degree' : 'Discipline',
      disciplineOptions(dual: dual, current: half),
      half,
    );
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

  Future<void> _pickBatch(BuildContext context) async {
    final v = await _pick(context, 'Batch', [
      for (final y in batchOptions(DateTime.now()).reversed)
        (y, '20${y.toString().padLeft(2, '0')}'),
    ], batch);
    if (v == null || v == batch || !context.mounted) return;
    final next = batchErase(batch, v, erase);
    if (next == 1 &&
        erase != 1 &&
        !await _confirm(context, 'Change batch?', eraseWarning(1)!, 'Change')) {
      return;
    }
    erase = next;
    batch = v;
    await setdis();
    await initializeCourses();
    if (mounted) setState(() {});
  }

  Future<void> _pickCampus(BuildContext context) async {
    final v = await _pick(context, 'Campus', [
      for (final c in Campus.values) (c, c.label),
    ], campus);
    if (v == null || v == campus || !context.mounted) return;
    campus = v;
    await setdis();
    if (mounted) setState(() {});
  }

  /// The browser's own prompt where it has one; otherwise, and always on
  /// iOS, the home-screen steps.
  Future<void> _install(BuildContext context) async {
    final target = installTarget();
    if (target.device != InstallDevice.ios && promptInstall()) return;
    await showInstallGuide(context, target);
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
          (c) => AlertDialog(
            title: Text('Name profile $i'),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLength: 9,
              decoration: const InputDecoration(
                helperText: 'Nine letters at most',
              ),
              onSubmitted: (t) => Navigator.pop(c, t),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(c, controller.text),
                child: const Text('Save'),
              ),
            ],
          ),
    );
    controller.dispose();
    if (name == null) return;
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

  Future<void> _signOut() async {
    await Sync.stop();
    await FirebaseAuth.instance.signOut();
    await Sync.clearLocal();
    reloadPage();
  }

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

  Future<void> _importFromFile(BuildContext context) async {
    String? text;
    try {
      text = await pickTextFile('.json,application/json');
    } catch (e) {
      if (context.mounted) _toast(context, 'Could not read the file: $e');
      return;
    }
    if (text == null || !context.mounted) return; // cancelled

    Map<String, int> counts;
    try {
      counts = Sync.validate(text);
    } catch (e) {
      _toast(
        context,
        e is FormatException
            ? "That file isn't a grade backup: ${e.message}"
            : '$e',
      );
      return;
    }
    final summary = [
      if (counts['coursesBox'] != null) '${counts['coursesBox']} courses',
      if (counts['settingsBox'] != null) '${counts['settingsBox']} settings',
      if ((counts['offshootBox'] ?? 0) > 0)
        '${counts['offshootBox']} offshoot courses',
      if ((counts['marksBox'] ?? 0) > 0) '${counts['marksBox']} marks entries',
    ].join(', ');
    if (!await _confirm(
      context,
      'Replace your grades?',
      'This file contains $summary.\n\nImporting replaces everything '
          'currently saved to your account. This cannot be undone.',
      'Import',
    )) {
      return;
    }
    try {
      await Sync.apply(text);
      await Sync.push();
      reloadPage();
    } catch (e) {
      if (context.mounted) _toast(context, 'Import failed: $e');
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
          (c) => AlertDialog(
            title: const Text('Import from old site'),
            content: SizedBox(
              width: 420,
              child: TextField(
                controller: controller,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: 'Paste the JSON copied from the old site',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Import'),
              ),
            ],
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
      if (context.mounted) _toast(context, 'Import failed: $e');
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
                (c, setDialog) => AlertDialog(
                  title: const Text('Report a problem'),
                  content: SizedBox(
                    width: 420,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final t in types)
                              ChoiceChip(
                                label: Text(t),
                                selected: type == t,
                                onSelected: (_) => setDialog(() => type = t),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: controller,
                          maxLines: 5,
                          maxLength: 2000,
                          decoration: const InputDecoration(
                            hintText:
                                'What went wrong, or which course is missing?',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const Text(
                          'Sent with your email so a reply is possible.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Send'),
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
