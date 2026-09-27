import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:flutter/material.dart';

/// Board `Divergence`: the first edit of an official value asks before it
/// detaches (ARCHITECTURE.md §5). True: make it mine. False or dismissed:
/// keep official.
Future<bool> confirmDivergence(
  BuildContext context, {
  required String name,
  required String change,
}) async {
  final p = AppPalette.of(context);
  final t = p.noticeTone;
  final mine = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    backgroundColor: p.background,
    constraints: const BoxConstraints(maxWidth: 640),
    builder:
        (c) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              0,
              Space.gutter,
              Space.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'YOU ARE CHANGING AN OFFICIAL VALUE',
                  style: TypeScale.label.copyWith(color: t.text),
                ),
                const SizedBox(height: Space.sm),
                Text('Make $name yours?', style: TypeScale.title),
                const SizedBox(height: Space.sm),
                Text(
                  '$change. Official changes to $name will stop arriving and '
                  'you keep it current. The other components, the credits and '
                  'your own marks are not affected.',
                  style: TypeScale.body.copyWith(color: p.textMuted),
                ),
                const SizedBox(height: Space.xs),
                Text(
                  'You can switch back any time with Use the official '
                  'version.',
                  style: TypeScale.caption.copyWith(color: p.textMuted),
                ),
                const SizedBox(height: Space.lg),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(c, false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          shape: const StadiumBorder(),
                        ),
                        child: const Text('Keep official'),
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(c, true),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          shape: const StadiumBorder(),
                          backgroundColor: p.inverse,
                          foregroundColor: p.onInverse,
                        ),
                        child: const Text('Make it mine'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
  );
  return mine ?? false;
}

/// Board `Diverged`: what the student made theirs, and — when the official
/// scheme changed since — the notice, with Keep mine beside it.
class DivergedCard extends StatelessWidget {
  const DivergedCard({
    super.key,
    required this.yours,
    required this.changed,
    required this.onKeepMine,
  });

  /// Names of what is theirs: "Mid Semester", "the course average".
  final List<String> yours;

  /// Names whose official version changed after they made it theirs. Empty:
  /// no notice.
  final List<String> changed;
  final VoidCallback onKeepMine;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final t = p.noticeTone;
    String list(List<String> l) =>
        l.length == 1
            ? l.single
            : '${l.sublist(0, l.length - 1).join(', ')} and ${l.last}';
    return AppCard(
      color: changed.isEmpty ? null : t.fill,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            changed.isEmpty ? 'YOURS' : 'THE OFFICIAL SCHEME CHANGED',
            style: TypeScale.label.copyWith(
              color: changed.isEmpty ? p.textMuted : t.text,
            ),
          ),
          const SizedBox(height: Space.xs),
          Text(
            changed.isEmpty
                ? '${list(yours)} ${yours.length == 1 ? 'is' : 'are'} yours. '
                    'Official updates to ${yours.length == 1 ? 'it' : 'them'} '
                    'are paused; the rest keep updating.'
                : 'The official ${list(changed)} changed. Yours stays as it '
                    'is until you choose — use the official version below, or '
                    'keep yours.',
            style: TypeScale.body.copyWith(
              fontSize: 12.5,
              color: changed.isEmpty ? p.text : t.text,
            ),
          ),
          if (changed.isNotEmpty) ...[
            const SizedBox(height: Space.sm),
            SizedBox(
              height: Sizes.minTouch,
              child: OutlinedButton(
                onPressed: onKeepMine,
                style: OutlinedButton.styleFrom(
                  shape: const StadiumBorder(),
                  foregroundColor: t.text,
                ),
                child: const Text('Keep mine'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Use the official Mid Semester": discards what the student made theirs.
class UseOfficialButton extends StatelessWidget {
  const UseOfficialButton({
    super.key,
    required this.name,
    required this.onPressed,
  });

  final String name;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(minimumSize: const Size(0, Sizes.minTouch)),
      icon: const Icon(Icons.restart_alt_rounded, size: 18),
      label: Text('Use the official $name'),
    ),
  );
}
