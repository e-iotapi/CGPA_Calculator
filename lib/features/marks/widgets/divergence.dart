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
  final body = TypeScale.body.copyWith(
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    height: 1.5,
    color: p.icon,
  );
  final strong = body.copyWith(fontWeight: FontWeight.w700, color: p.text);
  final mine = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: p.surface,
    barrierColor: p.inverse.withValues(alpha: 0.42),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    constraints: const BoxConstraints(maxWidth: 640),
    builder:
        (c) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: p.outline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'YOU ARE CHANGING AN OFFICIAL VALUE',
                  style: TypeScale.label.copyWith(color: p.textMuted),
                ),
                Semantics(
                  header: true,
                  child: Text(
                    'Make $name yours?',
                    style: TypeScale.title.copyWith(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: p.text,
                    ),
                  ),
                ),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '$change. Official changes to '),
                      TextSpan(text: name, style: strong),
                      const TextSpan(
                        text:
                            ' will stop arriving and you keep it current. The '
                            'other components, the credits and your own marks '
                            'are not affected.',
                      ),
                    ],
                  ),
                  style: body,
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: p.background,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text: 'You can switch back any time with ',
                        ),
                        TextSpan(
                          text: 'Use the official version',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: p.text,
                          ),
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                    style: TypeScale.caption.copyWith(
                      fontSize: 11,
                      color: p.textMuted,
                    ),
                  ),
                ),
                Row(
                  spacing: 8,
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(c, false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          shape: const StadiumBorder(),
                          foregroundColor: p.text,
                          side: BorderSide(color: p.text, width: 1.5),
                        ),
                        child: const Text('Keep official'),
                      ),
                    ),
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
