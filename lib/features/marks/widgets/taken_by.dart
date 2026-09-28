import 'package:cgpa_calculator/admin/widgets.dart' show LabelRow;
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/models/offering.dart';
import 'package:cgpa_calculator/core/professors/professor_store.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/shared/widgets/pill_button.dart';
import 'package:flutter/material.dart';

/// Board `Marks`' "Taken by" row (ARCHITECTURE.md §10.2): who teaches it
/// this term, read-only — if it is wrong, the CR fixes it once for everyone.
/// Where nobody is set yet, it says so rather than disappearing.
class TakenByRow extends StatefulWidget {
  const TakenByRow({
    super.key,
    required this.term,
    required this.professorIds,
    this.onReviews,
  });

  final String term;
  final List<String> professorIds;

  /// Opens the course's reviews, filtered to this professor.
  final VoidCallback? onReviews;

  @override
  State<TakenByRow> createState() => _TakenByRowState();
}

class _TakenByRowState extends State<TakenByRow> {
  late Future<List<String>> _names = _load();

  Future<List<String>> _load() async {
    final r = roleStore;
    if (r == null || widget.professorIds.isEmpty) return const [];
    final store = ProfessorStore(r.db);
    final out = <String>[];
    for (final id in widget.professorIds) {
      try {
        if (await store.get(id) case final p?) out.add(p.name);
      } catch (_) {
        // Offline with nothing cached: the row says nobody is set.
      }
    }
    return out;
  }

  @override
  void didUpdateWidget(TakenByRow old) {
    super.didUpdateWidget(old);
    if (old.professorIds.join() != widget.professorIds.join()) {
      _names = _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return FutureBuilder<List<String>>(
      future: _names,
      builder: (context, s) {
        final names = s.data ?? const [];
        return Padding(
          padding: const EdgeInsets.only(bottom: Space.sm),
          child: LabelRow(
            label: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TAKEN BY · ${termLabel(widget.term).toUpperCase()}',
                  style: TypeScale.label.copyWith(color: p.textMuted),
                ),
                Text(
                  names.isEmpty ? 'No professor set yet' : names.join(', '),
                  style: TypeScale.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: names.isEmpty ? p.textMuted : p.text,
                  ),
                ),
              ],
            ),
            trailing:
                widget.onReviews == null
                    ? const SizedBox.shrink()
                    : PillButton(
                      label: 'Reviews',
                      height: 34,
                      onPressed: widget.onReviews,
                    ),
          ),
        );
      },
    );
  }
}
