import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/shared/layout/breakpoints.dart';
import 'package:cgpa_calculator/shared/widgets/app_nav.dart';
import 'package:flutter/material.dart';

/// Page frame for every top-level screen: safe-area insets, the nav in the
/// right place for the width, and the body width capped on big monitors.
///
/// Below [Breakpoints.expanded] the nav is a pill along the bottom; at and
/// above it, a rail on the left. The breakpoint is read from the window's
/// constraints, not from the device.
class ResponsiveScaffold extends StatelessWidget {
  const ResponsiveScaffold({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.body,
    this.floatingActionButton,
  });

  final List<NavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget body;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return LayoutBuilder(
      builder: (context, c) {
        final wide = Breakpoints.of(c.maxWidth) == WindowSize.expanded;
        if (wide) {
          return Scaffold(
            backgroundColor: p.background,
            floatingActionButton: floatingActionButton,
            body: SafeArea(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(Space.md),
                    child: AppNav.rail(
                      destinations: destinations,
                      selectedIndex: selectedIndex,
                      onSelected: onSelected,
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: Breakpoints.maxContentWidth,
                        ),
                        child: body,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        // The pill floats over the page (boards `Main`, `More`): the body
        // runs underneath it, and a fade to the ground keeps the last row
        // from colliding with it. `extendBody` hands the pill's height to the
        // body as bottom padding, so a list pads by
        // `MediaQuery.paddingOf(context).bottom` to clear it.
        return Scaffold(
          backgroundColor: p.background,
          extendBody: true,
          floatingActionButton: floatingActionButton,
          body: SafeArea(bottom: false, child: body),
          // Off while the keyboard is up: only the field being typed in
          // should rise with it, not the nav (UT-3).
          bottomNavigationBar:
              MediaQuery.viewInsetsOf(context).bottom > 0
                  ? null
                  : _FloatingPill(
                    fade: p.background,
                    child: AppNav.pill(
                      destinations: destinations,
                      selectedIndex: selectedIndex,
                      onSelected: onSelected,
                    ),
                  ),
        );
      },
    );
  }
}

/// The pill, inset from the edges and the home indicator, over a fade to
/// [fade]. The fade is a plain gradient — no blur, no layer — and ignores
/// taps, so the content under it stays reachable.
class _FloatingPill extends StatelessWidget {
  const _FloatingPill({required this.fade, required this.child});

  final Color fade;
  final Widget child;

  /// How far above the pill the fade starts.
  static const double fadeHeight = 40;

  @override
  Widget build(BuildContext context) {
    final side =
        MediaQuery.sizeOf(context).width < AppNav.narrowWidth
            ? Space.lg
            : Space.gutter;
    // Its own layer: static over a scrolling list, so a scroll doesn't
    // repaint the fade (UI_OPT O4.3, and Safari's fixed layers, O8.3).
    return RepaintBoundary(
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [fade.withValues(alpha: 0), fade],
                    stops: const [0, 0.6],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(side, fadeHeight, side, Space.md),
              child: Center(heightFactor: 1, child: child),
            ),
          ),
        ],
      ),
    );
  }
}
