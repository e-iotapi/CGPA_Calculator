import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cgpa_calculator/app/theme/screen_cover.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/perf/device_tier.dart';
import 'package:cgpa_calculator/core/perf/frame_stats.dart';
import 'package:cgpa_calculator/core/platform/browser.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart' show timeDilation;

/// Where the last touch or click landed, in global coordinates. Pages and the
/// theme switch grow their circle from here.
abstract final class TapOrigin {
  /// The last recorded position, or `null` before any tap.
  static Offset? last;
  static bool _listening = false;

  /// Also records taps from the page itself: with the semantics tree on
  /// (screen readers, the test env) a tapped button gets no pointer event,
  /// so iOS grew the circle from an older tap.
  static void listen() {
    if (_listening) return;
    _listening = true;
    onDomPointerDown((x, y) => last = Offset(x, y));
  }
}

/// Records every pointer-down for [TapOrigin], without taking part in hit
/// testing.
class TapOriginTracker extends StatelessWidget {
  const TapOriginTracker({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    TapOrigin.listen();
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) => TapOrigin.last = e.position,
      child: child,
    );
  }
}

/// Some browsers (Firefox on Linux) read WebGL snapshots back upside down.
/// Snapshots one known picture, top half filled, and checks which way up it
/// came back. False off the web or if the check fails.
Future<bool> snapshotsFlipped() async {
  if (!kIsWeb) return false;
  try {
    final rec = ui.PictureRecorder();
    Canvas(rec).drawRect(
      const Rect.fromLTWH(0, 0, 1, 1),
      Paint()..color = const Color(0xFFFFFFFF),
    );
    final picture = rec.endRecording();
    final image = picture.toImageSync(1, 2);
    picture.dispose();
    final bytes = await image.toByteData();
    image.dispose();
    // RGBA: byte 3 is the top pixel's alpha, byte 7 the bottom's.
    return bytes != null && bytes.getUint8(3) == 0 && bytes.getUint8(7) != 0;
  } catch (_) {
    return false;
  }
}

/// How the theme switch gets the old screen to animate.
enum SwitchMethod {
  /// Flutter's own pictures of the screen.
  pictures,

  /// A copy the browser holds above the app ([ScreenCover]).
  cover,

  /// No picture: the old ground eases out over the new theme.
  veil,
}

/// Firefox reads WebGL pixels back slowly (each Flutter picture froze the
/// page 1.5-3 s, owner, 2026-10-06), so there the browser copies the screen
/// instead. `?fx=pictures`, `cover` or `veil` force one, to compare.
SwitchMethod switchMethod({required bool firefox, String? fx}) =>
    switch (fx) {
      'pictures' => SwitchMethod.pictures,
      'cover' => SwitchMethod.cover,
      'veil' => SwitchMethod.veil,
      _ => firefox ? SwitchMethod.cover : SwitchMethod.pictures,
    };

/// Radius that covers all of [size] from [center].
double _coverRadius(Offset center, Size size) => [
  Offset.zero,
  Offset(size.width, 0),
  Offset(0, size.height),
  Offset(size.width, size.height),
].map((c) => (c - center).distance).reduce(math.max);

class _CircleClipper extends CustomClipper<Path> {
  const _CircleClipper(this.center, this.fraction);

  final Offset center;
  final double fraction;

  @override
  Path getClip(Size size) =>
      Path()..addOval(
        Rect.fromCircle(
          center: center,
          radius: _coverRadius(center, size) * fraction,
        ),
      );

  @override
  bool shouldReclip(_CircleClipper old) =>
      old.fraction != fraction || old.center != center;
}

/// Every page opens as a circle growing out of the tap that opened it, and
/// closes back into it. Reduced motion gets a plain fade.
class CircleRevealTransitionsBuilder extends PageTransitionsBuilder {
  const CircleRevealTransitionsBuilder();

  static final _origins = Expando<Offset>();
  static final _curves = Expando<CurvedAnimation>();

  /// How many `CurvedAnimation`s have been created. Tests only (O2.3).
  @visibleForTesting
  static int debugCurvesCreated = 0;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 420);

  @override
  Duration get reverseTransitionDuration => Motion.slow;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // The content is painted once and only the clip changes per frame.
    final page = RepaintBoundary(child: child);
    if (MediaQuery.disableAnimationsOf(context) || route.isFirst) {
      return FadeTransition(opacity: animation, child: page);
    }
    final size = MediaQuery.sizeOf(context);
    final origin =
        _origins[route] ??= TapOrigin.last ?? size.center(Offset.zero);
    // O2.3: one curve per route, not one per build.
    final curved =
        _curves[route] ??= () {
          debugCurvesCreated++;
          return CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
        }();
    // O2.2: the circle's edge moves fast, so a hard edge on weak GPUs costs
    // nothing visible.
    final edge = deviceTier == DeviceTier.low ? Clip.hardEdge : Clip.antiAlias;
    return AnimatedBuilder(
      animation: curved,
      child: page,
      builder: (_, c) {
        final t = curved.value;
        // O2.1: always the same widget type, so the page never remounts.
        return ClipPath(
          clipper: _CircleClipper(origin, t),
          clipBehavior: t >= 1 ? Clip.none : edge,
          child: c,
        );
      },
    );
  }
}

/// Holds the app, and runs the theme switch as a circle of the new theme
/// growing out of the tap over a picture of the old one.
class ThemeReveal extends StatefulWidget {
  const ThemeReveal({super.key, required this.child});

  final Widget child;

  static final _key = GlobalKey<_ThemeRevealState>();

  /// The [ThemeReveal] to put at the root; there is one.
  static Widget root(Widget child) => ThemeReveal(key: _key, child: child);

  /// Calls [apply], which changes the theme, behind the reveal. Without a
  /// root, or with reduced motion, just calls it. [from] is the old theme's
  /// ground, for the veil where pictures are too slow.
  static Future<void> run(VoidCallback apply, {Color? from}) async {
    final s = _key.currentState;
    if (s == null) {
      apply();
      return;
    }
    await s._run(apply, from: from);
  }

  /// Starts a snapshot now, so it is ready by the time the finger lifts and
  /// [run] is called (UI_OPT O1.3). Call this from `onPointerDown` on every
  /// theme-toggle button.
  static void prepare() => _key.currentState?._prepare();

  /// [child], a theme toggle, with [prepare] on hover and on press, so the
  /// capture is done before the click rather than inside the animation.
  static Widget warm(Widget child) => MouseRegion(
    onEnter: (_) => prepare(),
    child: Listener(onPointerDown: (_) => prepare(), child: child),
  );

  /// How many snapshots have been captured (prepared or on-demand). Tests
  /// only.
  @visibleForTesting
  static int captures = 0;

  /// The snapshot [prepare] is holding, if any. Tests only.
  @visibleForTesting
  static ui.Image? get debugPreparedImage => _key.currentState?._preparedImage;

  /// The reveal animation's current value. Tests only.
  @visibleForTesting
  static double? get debugAnimValue => _key.currentState?._anim.value;

  /// How far the closing fade has run (0 when not fading). Tests only.
  @visibleForTesting
  static double? get debugFadeValue => _key.currentState?._fade.value;

  @override
  State<ThemeReveal> createState() => _ThemeRevealState();
}

class _ThemeRevealState extends State<ThemeReveal>
    with TickerProviderStateMixin {
  final _boundary = GlobalKey();
  late final _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  );
  // The last picture fades into the live app: a snapshot is never exactly
  // the screen (thin pill outlines came back a shade off, a visible jump).
  late final _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );
  bool _fading = false, _crossFade = false;
  ui.Image? _old, _new;
  Offset _origin = Offset.zero;

  ui.Image? _preparedImage;
  bool _flipped = false;
  bool _capturing = false;
  Timer? _expireTimer;

  // Read at startup: the first navigation drops the query from the URL.
  final _fx = Uri.base.queryParameters['fx'];
  late final _method = switchMethod(
    firefox: kIsWeb && installTarget().browser == InstallBrowser.firefox,
    fx: _fx,
  );
  bool get _noPictures => _method != SwitchMethod.pictures;
  // The circle on every screen, now Firefox runs it smoothly too (owner,
  // 2026-10-06); `?fx=fade` cross-fades instead, to compare.
  late final _fadeOnly = _fx == 'fade';
  Color? _veil;
  // Animations paused under the browser's copy: each Flutter frame redraws
  // the whole app on the thread the copy's animation runs on.
  bool _still = false;

  @override
  void initState() {
    super.initState();
    // The flip check reads pixels back too: none of it where they're slow.
    if (_noPictures) return;
    snapshotsFlipped().then((f) {
      _flipped = f;
      debugPrint('[Pointer theme] snapshots flipped: $f');
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    _fade.dispose();
    _old?.dispose();
    _expireTimer?.cancel();
    _preparedImage?.dispose();
    super.dispose();
  }

  RenderRepaintBoundary? get _box =>
      _boundary.currentContext?.findRenderObject() as RenderRepaintBoundary?;

  /// A snapshot at the app's own pixel ratio on every device: any lower one
  /// shows as a clear resolution drop (owner, 2026-10-04). Tried through the
  /// synchronous path first.
  Future<ui.Image> _capture(RenderRepaintBoundary box) {
    final r = MediaQuery.devicePixelRatioOf(context);
    ThemeReveal.captures++;
    try {
      return Future.value(box.toImageSync(pixelRatio: r));
    } on UnsupportedError {
      debugPrint('[Pointer theme] toImageSync unavailable');
      return box.toImage(pixelRatio: r);
    }
  }

  void _prepare() {
    final box = _box;
    if (_noPictures ||
        box == null ||
        _preparedImage != null ||
        _capturing ||
        _anim.isAnimating) {
      return;
    }
    _capturing = true;
    _capture(box).then((img) {
      _capturing = false;
      if (!mounted) {
        img.dispose();
        return;
      }
      _preparedImage = img;
      _expireTimer?.cancel();
      _expireTimer = Timer(const Duration(seconds: 2), () {
        _preparedImage?.dispose();
        _preparedImage = null;
      });
    });
  }

  Future<void> _run(VoidCallback apply, {Color? from}) async {
    final box = _box;
    if (box == null ||
        _anim.isAnimating ||
        MediaQuery.disableAnimationsOf(context)) {
      apply();
      return;
    }
    final ground = from ?? const Color(0xFF000000);
    if (_method == SwitchMethod.veil) return _runVeil(apply, ground);
    if (_method == SwitchMethod.cover) return _runCover(apply, ground);
    ui.Image? image = _preparedImage, next;
    _preparedImage = null;
    _expireTimer?.cancel();
    var applied = false;
    // Any failure (a snapshot Safari refuses) still switches the theme and
    // lifts the cover: without this the old picture stayed over the app and
    // the button looked dead on iPhone (owner, 2026-10-04).
    try {
      image ??= await _capture(box);
      if (!mounted) return;
      // O1.4: the cover shows, hidden and motionless, before the theme
      // changes.
      setState(() {
        _old = image;
        _origin = TapOrigin.last ?? box.size.center(Offset.zero);
        _crossFade = _fadeOnly;
        _anim.value = 0;
      });
      await Future<void>.delayed(Duration.zero); // the cover gets to paint
      apply(); // the one rebuild happens under the cover
      applied = true;
      await Future<void>.delayed(Duration.zero); // laid out, still hidden
      // The new screen is captured too and the live app sits out the
      // animation: on the web every frame replays the whole app's drawing,
      // so a text-heavy page under the hole ran the reveal at 25 fps on a
      // big window. Two images per frame keep it smooth (owner, 2026-10-04).
      await WidgetsBinding.instance.endOfFrame; // the new theme is painted
      if (!mounted) return;
      next = await _capture(box);
      if (!mounted) return;
      setState(() => _new = next);
      FrameStats.start('theme');
      _anim.duration = Duration(milliseconds: _crossFade ? 420 : 560);
      await _anim.forward(from: 0); // now only the hole (or the fade) moves
      FrameStats.stop();
      if (!mounted) return;
      setState(() => _fading = true); // the live app returns under it
      await _fade.forward(from: 0);
    } on Object catch (e) {
      debugPrint('[Pointer theme] reveal failed: $e');
      if (!applied) apply();
    } finally {
      if (mounted) {
        setState(() {
          _old = _new = null;
          _fading = false;
        });
        _fade.value = 0;
      }
      image?.dispose();
      next?.dispose();
    }
  }

  /// The browser's copy of the screen covers the app while the theme changes
  /// under it, then opens (circle) or fades away; the veil if no copy.
  Future<void> _runCover(VoidCallback apply, Color ground) async {
    final cover = await ScreenCover.take();
    if (!mounted || cover == null) {
      cover?.remove();
      return _runVeil(apply, ground);
    }
    final fade = _fadeOnly;
    final origin = TapOrigin.last ?? context.size!.center(Offset.zero);
    try {
      apply();
      // Material animates its outline to the new theme over 200 ms; paused
      // through the circle, pill borders kept the old colour and jumped after
      // (owner, 2026-10-06). Run time fast for two frames under the copy so
      // they land, then pause everything for the reveal.
      timeDilation = 0.01;
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;
      timeDilation = 1;
      if (!mounted) return;
      setState(() => _still = true);
      await WidgetsBinding.instance.endOfFrame; // the settled theme, under it
      await cover.reveal(
        origin,
        fade: fade,
        duration: Duration(milliseconds: fade ? 420 : 560),
      );
    } on Object catch (e) {
      debugPrint('[Pointer theme] cover failed: $e');
      cover.remove();
    } finally {
      timeDilation = 1;
      if (mounted) setState(() => _still = false);
    }
  }

  /// No pictures: the old ground covers the screen, the theme changes under
  /// it, and it eases out to show the new one.
  Future<void> _runVeil(VoidCallback apply, Color from) async {
    setState(() {
      _veil = from;
      _anim.value = 0;
    });
    await Future<void>.delayed(Duration.zero); // the veil gets to paint
    apply();
    try {
      _anim.duration = const Duration(milliseconds: 420);
      await _anim.forward(from: 0);
    } finally {
      if (mounted) setState(() => _veil = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final old = _old, veil = _veil;
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        Offstage(
          offstage: _new != null && !_fading,
          child: RepaintBoundary(
            key: _boundary,
            child: TickerMode(enabled: !_still, child: widget.child),
          ),
        ),
        if (old != null)
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_anim, _fade]),
                  builder:
                      (_, _) => CustomPaint(
                        isComplex: true,
                        willChange: true,
                        painter: _HolePainter(
                          old,
                          _new,
                          _origin,
                          _flipped,
                          (_crossFade ? Curves.easeOut : Curves.easeInOutCubic)
                              .transform(_anim.value),
                          1 - Curves.easeInOut.transform(_fade.value),
                          deviceTier == DeviceTier.low
                              ? FilterQuality.low
                              : FilterQuality.medium,
                          crossFade: _crossFade,
                        ),
                      ),
                ),
              ),
            ),
          ),
        if (veil != null)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _anim,
                builder:
                    (_, _) => ColoredBox(
                      color: veil.withValues(
                        alpha: 1 - Curves.easeOut.transform(_anim.value),
                      ),
                    ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The old screen with a growing circular hole onto the new one ([next]).
/// The hole reaches the farthest corner exactly at the end, so the old
/// screen stays opaque throughout; a fade here turned the last corner into a
/// grey blob. Only once it is gone does [next] fade ([opacity]) into the
/// live app, which is the same theme underneath.
class _HolePainter extends CustomPainter {
  _HolePainter(
    this.image,
    this.next,
    this.center,
    this.flipped,
    this.t,
    this.opacity,
    this.quality, {
    this.crossFade = false,
  });

  final ui.Image image;
  final ui.Image? next;
  final Offset center;
  final bool flipped;
  final double t;

  /// The whole overlay's, for the closing fade.
  final double opacity;
  final FilterQuality quality;

  /// No hole: the old screen fades out over the new by [t].
  final bool crossFade;

  @override
  void paint(Canvas canvas, Size size) {
    final r = _coverRadius(center, size) * t;
    final hole =
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(Offset.zero & size)
          ..addOval(Rect.fromCircle(center: center, radius: r));
    canvas.save();
    if (flipped) {
      canvas
        ..translate(0, size.height)
        ..scale(1, -1);
    }
    final paint =
        Paint()
          ..filterQuality = quality
          ..color = Color.fromRGBO(0, 0, 0, opacity);
    void draw(ui.Image i) => canvas.drawImageRect(
      i,
      Offset.zero & Size(i.width.toDouble(), i.height.toDouble()),
      Offset.zero & size,
      paint,
    );
    if (next != null) draw(next!);
    if (crossFade) {
      paint.color = Color.fromRGBO(0, 0, 0, opacity * (1 - t));
      if (t < 1) draw(image);
      canvas.restore();
      return;
    }
    canvas.restore();
    if (t >= 1) return; // the hole is the whole screen
    canvas.save();
    canvas.clipPath(hole);
    if (flipped) {
      canvas
        ..translate(0, size.height)
        ..scale(1, -1);
    }
    draw(image);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HolePainter old) =>
      old.t != t ||
      old.opacity != opacity ||
      old.image != image ||
      old.next != next ||
      old.crossFade != crossFade;
}
