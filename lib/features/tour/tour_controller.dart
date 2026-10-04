import 'dart:async';

import 'package:cgpa_calculator/features/tour/tour_overlay.dart';
import 'package:cgpa_calculator/features/tour/tour_steps.dart';
import 'package:cgpa_calculator/shared/tour_key.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// What the tour needs from the app, so the controller itself knows nothing
/// of the router, Home or Hive (and tests can stand in for all three).
class TourEnv {
  const TourEnv({
    required this.overlay,
    required this.push,
    required this.pop,
    required this.onPage,
    required this.selectProfile,
    required this.profile,
    required this.firstCourseId,
    required this.offshootHidden,
    required this.seen,
    required this.markSeen,
  });

  /// The root Navigator's overlay: above every page and sheet.
  final OverlayState? Function() overlay;

  /// Opens `page` on top of Home (the course page gets its `courseId`).
  final void Function(TourPage page, String? courseId) push;

  /// Back to the page beneath.
  final VoidCallback pop;

  /// Whether the router is showing `page` right now.
  final bool Function(TourPage page, String? courseId) onPage;

  /// Home's grade profile (1 Actual .. 4 Offshoot); the switch is not saved.
  final void Function(int profile) selectProfile;
  final int Function() profile;

  /// The first course in Actual, or null when there is none.
  final String? Function() firstCourseId;
  final bool Function() offshootHidden;
  final bool Function() seen;
  final Future<void> Function() markSeen;
}

/// Runs the guided tour. Everything it shows lives in one [OverlayEntry];
/// changing step repaints that entry only, so Home is never rebuilt by it.
class TourController extends ChangeNotifier with WidgetsBindingObserver {
  TourController(
    this.env, {
    this.navWait = const Duration(milliseconds: 380),
    this.steps = tourSteps,
  });

  final TourEnv env;

  /// Time given to a page push, pop or profile switch before measuring.
  final Duration navWait;
  final List<TourStep> steps;

  OverlayEntry? _entry;
  bool _active = false;
  bool _busy = false;
  bool _navigating = false;
  bool _seenWritten = false;
  int _from = 0;
  int _to = 0;
  int _i = 0;
  int _gen = 0;
  Rect? _hole;
  TourPage _page = TourPage.home;
  String? _courseId;
  int? _startProfile;

  bool get active => _active;

  /// True while the tour moves between pages; the card is hidden meanwhile.
  bool get busy => _busy;
  int get index => _i;
  TourStep get step => steps[_i];
  int get total => steps.length;
  String get chapter => tourChapters[step.chapter];
  bool get canBack => _i > _from;
  bool get isLast => _i >= _to;

  /// The highlighted control's rect on screen, null while moving.
  Rect? get hole => _hole;

  /// Starts the whole tour, or just `chapter` (0-based). False if it cannot
  /// (already running, no overlay, not on Home).
  Future<bool> start({int? chapter}) async {
    final overlay = env.overlay();
    if (_active || overlay == null || !env.onPage(TourPage.home, null)) {
      return false;
    }
    final inChapter = [
      for (var k = 0; k < steps.length; k++)
        if (chapter == null || steps[k].chapter == chapter) k,
    ];
    if (inChapter.isEmpty) return false;
    _from = inChapter.first;
    _to = inChapter.last;
    _i = _from;
    _active = true;
    _busy = true;
    _hole = null;
    _page = TourPage.home;
    _courseId = null;
    _seenWritten = false;
    _startProfile = env.profile();
    _gen++;
    _entry = OverlayEntry(builder: (_) => TourOverlay(controller: this));
    overlay.insert(_entry!);
    WidgetsBinding.instance.addObserver(this);
    notifyListeners();
    await _show(_from, 1);
    return true;
  }

  Future<void> next() async {
    if (!_active || _busy) return;
    if (isLast) return skip();
    await _show(_i + 1, 1);
  }

  Future<void> back() async {
    if (!_active || _busy || !canBack) return;
    await _show(_i - 1, -1);
  }

  /// Ends the tour early. Counts as seen, like finishing it.
  Future<void> skip() => _end();

  /// The router moved on its own (system Back, a link): the tour is over.
  void routeChanged() {
    if (!_active || _navigating) return;
    if (!env.onPage(_page, _courseId)) unawaited(_end(navigate: false));
  }

  @override
  void didChangeMetrics() {
    if (!_active || _busy) return;
    final g = _gen;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (g != _gen || !_active || _busy) return;
      final r = _rect(step);
      if (r != null && r != _hole) {
        _hole = r;
        notifyListeners();
      }
    });
  }

  // ---- stepping ----------------------------------------------------------

  /// Shows step [i], or the next one that exists in [dir] when its control is
  /// not in this build. Running off the end finishes; running off the start
  /// stays on the current step.
  Future<void> _show(int i, int dir) async {
    final g = _gen;
    _busy = true;
    notifyListeners();
    for (var k = i; k >= _from && k <= _to; k += dir) {
      final r = await _prepare(steps[k]);
      if (g != _gen) return;
      if (r != null) {
        _i = k;
        _hole = r;
        _busy = false;
        notifyListeners();
        return;
      }
    }
    if (dir > 0) return _end();
    await _show(_i, 1);
  }

  /// Gets the page and profile of [s] on screen and returns where its control
  /// is, or null when it has none here.
  Future<Rect?> _prepare(TourStep s) async {
    final g = _gen;
    if (s.page == TourPage.course && _courseId == null) return null;
    if (s.page == TourPage.home && s.profile == 4 && env.offshootHidden()) {
      return null;
    }
    await _goto(s.page);
    if (g != _gen) return null;
    if (s.page == TourPage.home && env.profile() != s.profile) {
      env.selectProfile(s.profile);
      await _wait();
      if (g != _gen) return null;
    }
    final r = await _locate(s);
    if (g != _gen) return null;
    if (s.target == 'row') _courseId ??= env.firstCourseId();
    return r;
  }

  Future<void> _wait() => Future<void>.delayed(navWait);

  Future<void> _goto(TourPage target) async {
    if (_page == target) return;
    final g = _gen;
    _navigating = true;
    try {
      if (_page != TourPage.home) {
        env.pop();
        _page = TourPage.home;
        await _wait();
        if (g != _gen) return;
      }
      if (target != TourPage.home) {
        env.push(target, _courseId);
        _page = target;
        await _wait();
      }
    } finally {
      _navigating = false;
    }
  }

  // ---- finding the control ----------------------------------------------

  int? get _profileNow => _page == TourPage.home ? env.profile() : null;

  /// The tour key of [s] that has something on screen, if any.
  GlobalKey? _live(TourStep s) {
    final p = _profileNow;
    for (final k in [tourKey(s.target, p), tourKey(s.target)]) {
      if (tourRect(k) != null) return k;
    }
    return null;
  }

  Rect? _rect(TourStep s) {
    final k = _live(s);
    return k == null ? null : tourRect(k);
  }

  Future<void> _frame() => WidgetsBinding.instance.endOfFrame;

  Future<Rect?> _locate(TourStep s) async {
    final g = _gen;
    for (var f = 0; f < 14 && _live(s) == null; f++) {
      await _frame();
      if (g != _gen) return null;
    }
    if (_live(s) == null) {
      await _reveal(s);
      if (g != _gen) return null;
    }
    var key = _live(s);
    if (key == null) return null;
    await _scrollIntoView(key);
    if (g != _gen) return null;
    key = _live(s);
    return key == null ? null : _settled(key, s);
  }

  /// A lazy list has not built a control that is far down: scroll the page
  /// (found through its anchor, a control that is always built) until it is.
  Future<void> _reveal(TourStep s) async {
    final g = _gen;
    final anchor =
        _page == TourPage.home
            ? tourKey('section', env.profile())
            : tourKey('page.${_page.name}');
    final ctx = anchor.currentContext;
    final sc = ctx == null ? null : Scrollable.maybeOf(ctx);
    final pos = sc?.position;
    if (sc == null || pos == null || pos.axis != Axis.vertical) return;
    pos.jumpTo(pos.minScrollExtent);
    for (var n = 0; n < 60 && _live(s) == null; n++) {
      await _frame();
      if (g != _gen || !sc.mounted) return;
      if (_live(s) != null || pos.pixels >= pos.maxScrollExtent) return;
      pos.jumpTo(
        (pos.pixels + pos.viewportDimension * 0.8).clamp(
          pos.minScrollExtent,
          pos.maxScrollExtent,
        ),
      );
    }
  }

  /// Scrolls the control into view if it is off screen or under the nav pill.
  Future<void> _scrollIntoView(GlobalKey key) async {
    final ctx = key.currentContext;
    final r = tourRect(key);
    if (ctx == null || r == null || Scrollable.maybeOf(ctx) == null) return;
    final mq = MediaQuery.of(ctx);
    final size = mq.size;
    final bottom =
        size.height - mq.padding.bottom - (_page == TourPage.home ? 100 : 8);
    if (r.top >= mq.padding.top && r.bottom <= bottom) return;
    await Scrollable.ensureVisible(
      ctx,
      alignment: 0.3,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  /// Waits (about 1.5 s at most) until the control stops moving.
  Future<Rect?> _settled(GlobalKey key, TourStep s) async {
    final g = _gen;
    Rect? last;
    var same = 0;
    for (var f = 0; f < 90; f++) {
      await _frame();
      if (g != _gen) return null;
      final r = tourRect(key);
      if (r == null) {
        last = null;
        same = 0;
      } else if (r == last) {
        if (++same >= 2) return r;
      } else {
        last = r;
        same = 0;
      }
    }
    return last;
  }

  // ---- ending ------------------------------------------------------------

  Future<void> _end({bool navigate = true}) async {
    if (!_active) return;
    _active = false;
    _busy = false;
    _gen++;
    WidgetsBinding.instance.removeObserver(this);
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
    final write = !_seenWritten && !env.seen();
    _seenWritten = true;
    if (navigate) {
      if (_page != TourPage.home) {
        _navigating = true;
        env.pop();
        _page = TourPage.home;
        _navigating = false;
      }
      final p = _startProfile;
      if (p != null && env.profile() != p) env.selectProfile(p);
    }
    _courseId = null;
    notifyListeners();
    if (write) {
      try {
        await env.markSeen();
      } catch (e) {
        debugPrint('tour: could not save seen: $e');
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
