import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/reviews/review.dart';
import 'package:cgpa_calculator/core/reviews/review_store.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/features/reviews/review_widgets.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
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

  Future<List<Review>> _load() => switch (_view) {
    _View.all => _store.moderation(widget.campus, widget.dept),
    _View.reported => _store.moderation(
      widget.campus,
      widget.dept,
      hidden: false,
      reportedOnly: true,
    ),
    _View.hidden => _store.moderation(widget.campus, widget.dept, hidden: true),
  };

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
    final p = AppPalette.of(context);
    return Loaded<List<Review>>(
      key: ValueKey('$_view|$_loads'),
      load: _load,
      builder:
          (context, reviews, _) => PageFrame(
            header: PageHeader(
              eyebrow:
                  '${widget.dept} · ${campusName(widget.campus).toUpperCase()}',
              title: 'Reviews',
            ),
            children: [
              ChoicePills<_View>(
                values: _View.values,
                selected: _view,
                label:
                    (v) => switch (v) {
                      _View.all => 'All',
                      _View.reported => 'Reported',
                      _View.hidden => 'Hidden',
                    },
                onSelected: (v) => setState(() => _view = v),
              ),
              const SizedBox(height: Space.sm),
              for (final r in reviews) ...[
                ReviewTile(
                  r: r,
                  showCourse: true,
                  footer: Row(
                    children: [
                      Expanded(
                        child: Text(
                          r.hidden
                              ? 'Hidden by ${r.hiddenByName ?? 'a moderator'}: '
                                  '${r.reason ?? ''}'
                              : r.reports == 0
                              ? 'Not reported'
                              : '${r.reports} report${r.reports == 1 ? '' : 's'}',
                          style: TypeScale.caption.copyWith(
                            color:
                                r.reports > 0 || r.hidden
                                    ? p.behind
                                    : p.textMuted,
                          ),
                        ),
                      ),
                      if (r.hidden)
                        TextButton(
                          onPressed:
                              () => _act(
                                () => _store.unhide(r),
                                'Unhidden. Its rating counts again.',
                              ),
                          child: const Text('Unhide'),
                        )
                      else ...[
                        if (r.reports > 0)
                          TextButton(
                            onPressed:
                                () => _act(
                                  () => _store.keep(r),
                                  'Kept. The reports are cleared.',
                                ),
                            child: const Text('Keep'),
                          ),
                        TextButton(
                          onPressed: () => _hide(r),
                          child: const Text('Hide'),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: Space.xs),
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
              Text(
                'Hiding takes a review off the page and out of the rating; '
                'its author still sees it, with your reason. Every hide, '
                'unhide and keep goes in the audit log.',
                style: TypeScale.caption.copyWith(
                  height: 1.45,
                  color: p.textMuted,
                ),
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
