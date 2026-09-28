import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/reviews/review.dart';
import 'package:cgpa_calculator/core/reviews/review_store.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/features/reviews/review_widgets.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:cgpa_calculator/core/models/offering.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/notice.dart';
import 'package:cgpa_calculator/shared/widgets/pill_button.dart';
import 'package:flutter/material.dart';

enum _View { all, reported, hidden }

/// Board `DeptReviews`: a president moderates their department's reviews on
/// their campus. Hide-only, with a reason, and every change is logged
/// (§10.3); nothing is ever edited or deleted by staff.
class DeptReviews extends StatefulWidget {
  const DeptReviews({super.key, required this.campus, required this.dept});
  final String campus, dept;

  @override
  State<DeptReviews> createState() => _DeptReviewsState();
}

class _DeptReviewsState extends State<DeptReviews> {
  _View _view = _View.reported;
  int _loads = 0;

  ReviewStore get _store => reviewStore!;

  Future<_Lists> _load() async => (
    all: await _store.moderation(widget.campus, widget.dept),
    reported: await _store.moderation(
      widget.campus,
      widget.dept,
      hidden: false,
      reportedOnly: true,
    ),
    hidden: await _store.moderation(widget.campus, widget.dept, hidden: true),
  );

  Future<void> _act(Future<void> Function() f, String done) async {
    try {
      await f();
      if (!mounted) return;
      sayReview(context, done);
      setState(() => _loads++);
    } catch (e) {
      if (mounted) sayReview(context, e);
    }
  }

  Future<void> _hide(Review r) async {
    final why = await showDialog<String>(
      context: context,
      builder: (_) => const _ReasonDialog(),
    );
    if (why == null || why.isEmpty) return;
    await _act(() => _store.hide(r, why), 'Hidden. Its rating came off.');
  }

  @override
  Widget build(BuildContext context) {
    return Loaded<_Lists>(
      key: ValueKey(_loads),
      load: _load,
      builder: (context, lists, _) {
        final reviews = switch (_view) {
          _View.all => lists.all,
          _View.reported => lists.reported,
          _View.hidden => lists.hidden,
        };
        final shown = [
          for (final r in lists.all)
            if (!r.hidden) r,
        ];
        return PageFrame(
          header: PageHeader(
            eyebrow:
                '${campusName(widget.campus).toUpperCase()} ONLY · '
                '${widget.dept}',
            title: 'Reviews',
          ),
          children: [
            _Summary(dept: widget.dept, campus: widget.campus, shown: shown),
            const SizedBox(height: Space.md),
            ChoicePills<_View>(
              values: _View.values,
              selected: _view,
              equal: true,
              label:
                  (v) => switch (v) {
                    _View.all => 'All',
                    _View.reported => 'Reported',
                    _View.hidden => 'Hidden',
                  },
              count:
                  (v) => switch (v) {
                    _View.all => '${lists.all.length}',
                    _View.reported => '${lists.reported.length}',
                    _View.hidden => '${lists.hidden.length}',
                  },
              onSelected: (v) => setState(() => _view = v),
            ),
            const SizedBox(height: Space.sm),
            for (final r in reviews) ...[
              _ModCard(
                r: r,
                onKeep:
                    r.reports > 0 && !r.hidden
                        ? () => _act(
                          () => _store.keep(r),
                          'Kept. The reports are cleared.',
                        )
                        : null,
                onHide: r.hidden ? null : () => _hide(r),
                onUnhide:
                    r.hidden
                        ? () => _act(
                          () => _store.unhide(r),
                          'Unhidden. Its rating counts again.',
                        )
                        : null,
              ),
              const SizedBox(height: Space.sm),
            ],
            if (reviews.isEmpty)
              Note(switch (_view) {
                _View.reported =>
                  'Nothing reported. Students report a '
                      'review from its course page.',
                _View.hidden => 'Nothing hidden.',
                _View.all => 'No reviews in ${widget.dept} yet.',
              }),
            const SizedBox(height: Space.sm),
            Notice(
              text: const TextSpan(
                text:
                    'Hiding is reversible and never a delete. It takes a '
                    'review off the page and out of the rating; its author '
                    'still sees it, with your reason. Every hide, unhide and '
                    'keep goes in the audit log.',
              ),
            ),
          ],
        );
      },
    );
  }
}

typedef _Lists =
    ({List<Review> all, List<Review> reported, List<Review> hidden});

/// The department's reviews on this campus at a glance: count, average and
/// how many would take the course, with a bar.
class _Summary extends StatelessWidget {
  const _Summary({
    required this.dept,
    required this.campus,
    required this.shown,
  });
  final String dept, campus;
  final List<Review> shown;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final n = shown.length;
    final avg = n == 0 ? null : shown.fold(0, (a, r) => a + r.stars) / n;
    final take = n == 0 ? null : shown.where((r) => r.recommend).length / n;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$dept · ${campusName(campus).toUpperCase()} · '
            '$n REVIEW${n == 1 ? '' : 'S'}',
            style: TypeScale.label.copyWith(
              color: p.textMuted,
              letterSpacing: 1,
            ),
          ),
          Text(
            'This campus only',
            style: TypeScale.caption.copyWith(color: p.textMuted),
          ),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.lg,
            runSpacing: Space.xs,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: avg == null ? '–' : avg.toStringAsFixed(1),
                      style: TypeScale.title.copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextSpan(
                      text: ' / 5',
                      style: TypeScale.caption.copyWith(color: p.textMuted),
                    ),
                  ],
                ),
              ),
              Text(
                take == null
                    ? 'NO RATINGS YET'
                    : '${(take * 100).round()}% WOULD TAKE IT',
                style: TypeScale.label.copyWith(letterSpacing: 0.8),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 7,
              child: LinearProgressIndicator(
                value: take ?? 0,
                color: p.text,
                backgroundColor: p.surfaceSunken,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One review as a moderator sees it: chips, reports, rating, the text, and
/// Keep / Hide (or Unhide) as 32 tall pills.
class _ModCard extends StatelessWidget {
  const _ModCard({required this.r, this.onKeep, this.onHide, this.onUnhide});
  final Review r;
  final VoidCallback? onKeep, onHide, onUnhide;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final text = r.text?.trim() ?? '';
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TierTag(r.courseId, strong: true),
              ScopeChip(termLabel(r.term), muted: true, height: 22),
              if (r.reports > 0)
                Text(
                  '${r.reports} REPORT${r.reports == 1 ? '' : 'S'}',
                  style: TypeScale.label.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: p.noticeTone.text,
                  ),
                ),
            ],
          ),
          const SizedBox(height: Space.sm),
          Row(
            children: [
              Icon(Icons.star_rounded, size: 16, color: p.text),
              const SizedBox(width: 3),
              Text(
                '${r.stars} of 5',
                style: TypeScale.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: p.text,
                ),
              ),
              const SizedBox(width: Space.sm),
              TierTag(r.recommend ? 'TAKE IT' : "DON'T"),
            ],
          ),
          if (text.isNotEmpty) ...[
            const SizedBox(height: Space.sm),
            Text(text, style: TypeScale.body.copyWith(height: 1.45)),
          ],
          const SizedBox(height: Space.sm),
          Text(
            r.hidden
                ? 'Hidden by ${r.hiddenByName ?? 'a moderator'}: '
                    '${r.reason ?? ''}'
                : 'Anonymous to students · attributable to you',
            style: TypeScale.caption.copyWith(
              color: r.hidden ? p.behind : p.textMuted,
            ),
          ),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              if (onKeep != null)
                PillButton(label: 'Keep', height: 32, onPressed: onKeep),
              if (onHide != null)
                PillButton(
                  label: 'Hide',
                  height: 32,
                  selected: true,
                  onPressed: onHide,
                ),
              if (onUnhide != null)
                PillButton(label: 'Unhide', height: 32, onPressed: onUnhide),
            ],
          ),
        ],
      ),
    );
  }
}

/// Asks why a review is hidden. Owns its field, so it outlives the closing
/// animation.
class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog();

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Hide this review?'),
    content: TextField(
      controller: _reason,
      autofocus: true,
      decoration: const InputDecoration(
        labelText: 'Reason',
        hintText: 'Names a person, abusive, not about the course…',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, _reason.text.trim()),
        child: const Text('Hide'),
      ),
    ],
  );
}
