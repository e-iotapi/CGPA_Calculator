import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/shared/widgets/tag_badge.dart';
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

/// Board `Diverged`: the YOURS line while anything is detached, and, only
/// when the official scheme changed since, the amber card with Review and
/// Keep mine.
class DivergedCard extends StatelessWidget {
  const DivergedCard({
    super.key,
    required this.yours,
    required this.changed,
    required this.onKeepMine,
    this.onReview,
    this.age = '',
    this.body = '',
  });

  /// Names of what is theirs: "Mid Semester", "the course average".
  final List<String> yours;

  /// Names whose official version changed after they made it theirs. Empty:
  /// no amber card.
  final List<String> changed;
  final VoidCallback onKeepMine;
  final VoidCallback? onReview;

  /// "2 days ago": when the official scheme last changed.
  final String age;

  /// What changed, in words.
  final String body;

  /// [l] joined as English prose: "a", "a and b", "a, b and c".
  static String list(List<String> l) =>
      l.length == 1
          ? l.single
          : '${l.sublist(0, l.length - 1).join(', ')} and ${l.last}';

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final t = p.noticeTone;
    final note = TypeScale.caption.copyWith(
      fontSize: 11,
      height: 1.45,
      color: p.textMuted,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 9,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TagBadge('YOURS', tone: TagTone.yours),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                '${list(yours)} ${yours.length == 1 ? 'is' : 'are'} edited '
                'by you. Official updates to '
                '${yours.length == 1 ? 'it' : 'them'} are paused; the rest '
                'keep updating.',
                style: note,
              ),
            ),
          ],
        ),
        if (changed.isNotEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
            decoration: BoxDecoration(
              color: t.fill,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 9,
              children: [
                Text(
                  'OFFICIAL ${list(changed)} CHANGED'
                          '${age.isEmpty ? '' : ' · $age'}'
                      .toUpperCase(),
                  style: TypeScale.label.copyWith(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: t.text,
                  ),
                ),
                Text(
                  body,
                  style: TypeScale.body.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                    color: p.isDark ? t.text : const Color(0xFF4A3408),
                  ),
                ),
                Row(
                  spacing: 8,
                  children: [
                    if (onReview != null)
                      Expanded(
                        child: FilledButton(
                          onPressed: onReview,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(40),
                            shape: const StadiumBorder(),
                            backgroundColor: p.inverse,
                            foregroundColor: p.onInverse,
                          ),
                          child: const Text('Review'),
                        ),
                      ),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onKeepMine,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(40),
                          shape: const StadiumBorder(),
                          foregroundColor: t.text,
                          side: BorderSide(
                            color: t.text.withValues(alpha: 0.35),
                          ),
                        ),
                        child: const Text('Keep mine'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
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
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(
            child: Text(
              'Use the official $name',
              textAlign: TextAlign.center,
              style: TypeScale.body.copyWith(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: p.accent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
