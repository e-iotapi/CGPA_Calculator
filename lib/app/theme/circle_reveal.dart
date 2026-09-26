import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Where the last touch or click landed, in global coordinates. Pages and the
/// theme switch grow their circle from here.
abstract final class TapOrigin {
  static Offset? last;
}

/// Records every pointer-down for [TapOrigin], without taking part in hit
/// testing.
class TapOriginTracker extends StatelessWidget {
  const TapOriginTracker({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (e) => TapOrigin.last = e.position,
    child: child,
  );
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
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeInOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return AnimatedBuilder(
      animation: curved,
      child: page,
      builder: (_, c) {
        final t = curved.value;
        if (t >= 1) return c!;
        return ClipPath(clipper: _CircleClipper(origin, t), child: c);
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

  @override
  void dispose() {
    _anim.dispose();
    _old?.dispose();
    super.dispose();
  }

  Future<void> _run(VoidCallback apply) async {
    final box =
        _boundary.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (box == null ||
        _anim.isAnimating ||
        MediaQuery.disableAnimationsOf(context)) {
      apply();
      return;
    }
    final dpr = MediaQuery.devicePixelRatioOf(context);
    // Capped: a full-screen picture at 3x is slow to take on a phone, and it
    // is only on screen for half a second.
    final image = await box.toImage(pixelRatio: math.min(dpr, 1.5));
    if (!mounted) return image.dispose();
    setState(() {
      _old = image;
      _origin = TapOrigin.last ?? box.size.center(Offset.zero);
    });
    apply();
    await _anim.forward(from: 0);
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
              child: AnimatedBuilder(
                animation: _anim,
                builder:
                    (_, _) => CustomPaint(
                      painter: _HolePainter(
                        old,
                        _origin,
                        Curves.easeInOutCubic.transform(_anim.value),
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
  _HolePainter(this.image, this.center, this.t);

  final ui.Image image;
  final Offset center;
  final double t;

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
    canvas.drawImageRect(
      image,
      Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
      Offset.zero & size,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..color = Color.fromRGBO(0, 0, 0, t < 0.75 ? 1 : (1 - t) / 0.25),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HolePainter old) => old.t != t || old.image != image;
}
