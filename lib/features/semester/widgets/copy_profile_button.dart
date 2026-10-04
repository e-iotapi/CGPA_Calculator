import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/shared/widgets/confirm_dialog.dart';
import 'package:flutter/material.dart';

/// The round copy button on the Expected profile (board `Expected`): an
/// icon only, named by its tooltip. It stays up for as long as the profile
/// is open, and asks before copying every [from] grade over the [to] grades.
class CopyProfileButton extends StatelessWidget {
  const CopyProfileButton({
    super.key,
    required this.from,
    required this.to,
    required this.onCopy,
  });

  /// Profile names, "Actual" and "Expected" unless renamed.
  final String from, to;
  final Future<void> Function() onCopy;

  Future<bool> _confirm(BuildContext context) => confirmDialog(
    context,
    title: 'Import from $from?',
    body:
        'Every $from grade, in all semesters, will be copied over your '
        '$to grades. This cannot be undone.',
    action: 'Import',
  );

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return FloatingActionButton(
      heroTag: null,
      tooltip: 'Copy every $from grade into $to',
      elevation: 4,
      backgroundColor: p.inverse,
      foregroundColor: p.onInverse,
      shape: const CircleBorder(),
      onPressed: () async {
        if (await _confirm(context)) await onCopy();
      },
      child: const Icon(Icons.copy_rounded, size: 22),
    );
  }
}
