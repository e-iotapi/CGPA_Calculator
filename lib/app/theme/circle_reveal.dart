import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/perf/device_tier.dart';
import 'package:cgpa_calculator/core/perf/frame_stats.dart';
import 'package:cgpa_calculator/core/platform/browser.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// The theme snapshot's pixel ratio: at most 1.5, and 1 on a low tier device
/// or on iOS, where Safari caps canvas memory (UI_OPT O1.3, O8.1).
double snapshotRatio({
  required double dpr,
  required DeviceTier tier,
  required bool ios,
}) => tier == DeviceTier.low || ios ? 1.0 : math.min(dpr, 1.5);

/// Read once: every iOS browser is Safari underneath.
final bool _onIos = installTarget().device == InstallDevice.ios;

/// Where the last touch or click landed, in global coordinates. Pages and the
/// theme switch grow their circle from here.
abstract final class TapOrigin {
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
  /// root, or with reduced motion, just calls it.
  static Future<void> run(VoidCallback apply) async {
    final s = _key.currentState;
    if (s == null) {
      apply();
      return;
    }
    await s._run(apply);
  }

  /// Starts a snapshot now, so it is ready by the time the finger lifts and
  /// [run] is called (UI_OPT O1.3). Call this from `onPointerDown` on every
  /// theme-toggle button.
  static void prepare() => _key.currentState?._prepare();

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

  @override
  State<ThemeReveal> createState() => _ThemeRevealState();
}

class _ThemeRevealState extends State<ThemeReveal>
    with SingleTickerProviderStateMixin {
  final _boundary = GlobalKey();
  late final _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  );
  ui.Image? _old;
  Offset _origin = Offset.zero;

  ui.Image? _preparedImage;
  bool _flipped = false;
  bool _capturing = false;
  Timer? _expireTimer;

  @override
  void initState() {
    super.initState();
    snapshotsFlipped().then((f) {
      _flipped = f;
      debugPrint('[Pointer theme] snapshots flipped: $f');
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    _old?.dispose();
    _expireTimer?.cancel();
    _preparedImage?.dispose();
    super.dispose();
  }

  RenderRepaintBoundary? get _box =>
      _boundary.currentContext?.findRenderObject() as RenderRepaintBoundary?;

  /// UI_OPT O1.3: a cheaper snapshot, capped by device tier, tried through
  /// the synchronous path first.
  Future<ui.Image> _capture(RenderRepaintBoundary box) {
    final r = snapshotRatio(
      dpr: MediaQuery.devicePixelRatioOf(context),
      tier: deviceTier,
      ios: _onIos,
    );
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
    if (box == null ||
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

  Future<void> _run(VoidCallback apply) async {
    final box = _box;
    if (box == null ||
        _anim.isAnimating ||
        MediaQuery.disableAnimationsOf(context)) {
      apply();
      return;
    }
    ui.Image image;
    if (_preparedImage != null) {
      image = _preparedImage!;
      _preparedImage = null;
      _expireTimer?.cancel();
    } else {
      image = await _capture(box);
    }
    if (!mounted) return image.dispose();
    // O1.4: the cover shows, hidden and motionless, before the theme changes.
    setState(() {
      _old = image;
      _origin = TapOrigin.last ?? box.size.center(Offset.zero);
      _anim.value = 0;
    });
    await Future<void>.delayed(Duration.zero); // the cover gets to paint
    apply(); // the one rebuild happens under the cover
    await Future<void>.delayed(Duration.zero); // laid out, still hidden
    FrameStats.start('theme');
    await _anim.forward(from: 0); // now only the hole moves
    FrameStats.stop();
    if (!mounted) return;
    setState(() => _old = null);
    image.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final old = _old;
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        RepaintBoundary(key: _boundary, child: widget.child),
        if (old != null)
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _anim,
                  builder:
                      (_, _) => CustomPaint(
                        isComplex: true,
                        willChange: true,
                        painter: _HolePainter(
                          old,
                          _origin,
                          _flipped,
                          Curves.easeInOutCubic.transform(_anim.value),
                          deviceTier == DeviceTier.low
                              ? FilterQuality.low
                              : FilterQuality.medium,
                        ),
                      ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The old screen with a growing circular hole; it fades out at the end so
/// the last corners do not snap.
class _HolePainter extends CustomPainter {
  _HolePainter(this.image, this.center, this.flipped, this.t, this.quality);

  final ui.Image image;
  final Offset center;
  final bool flipped;
  final double t;
  final FilterQuality quality;

  @override
  void paint(Canvas canvas, Size size) {
    final r = _coverRadius(center, size) * t;
    final hole =
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(Offset.zero & size)
          ..addOval(Rect.fromCircle(center: center, radius: r));
    canvas.save();
    canvas.clipPath(hole);
    if (flipped) {
      canvas
        ..translate(0, size.height)
        ..scale(1, -1);
    }
    canvas.drawImageRect(
      image,
      Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
      Offset.zero & size,
      Paint()
        ..filterQuality = quality
        ..color = Color.fromRGBO(0, 0, 0, t < 0.75 ? 1 : (1 - t) / 0.25),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HolePainter old) => old.t != t || old.image != image;
}
