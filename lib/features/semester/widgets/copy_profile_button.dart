import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
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

  Future<bool> _confirm(BuildContext context) async {
    final p = AppPalette.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (c) => AlertDialog(
            backgroundColor: p.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.row),
            ),
            title: Text(
              'Import from $from?',
              style: TypeScale.section.copyWith(color: p.text),
            ),
            content: Text(
              'Every $from grade, in all semesters, will be copied over your '
              '$to grades. This cannot be undone.',
              style: TypeScale.body.copyWith(
                fontWeight: FontWeight.w500,
                color: p.textMuted,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(c).pop(false),
                child: Text(
                  'Cancel',
                  style: TypeScale.button.copyWith(color: p.text),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(c).pop(true),
                child: Text(
                  'Import',
                  style: TypeScale.button.copyWith(
                    fontWeight: FontWeight.w700,
                    color: p.accent,
                  ),
                ),
              ),
            ],
          ),
    );
    return ok == true;
  }

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
