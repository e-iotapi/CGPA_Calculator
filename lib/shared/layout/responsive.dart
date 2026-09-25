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
        return Scaffold(
          backgroundColor: p.background,
          floatingActionButton: floatingActionButton,
          body: SafeArea(bottom: false, child: body),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.lg,
                Space.xs,
                Space.lg,
                Space.md,
              ),
              child: Center(
                heightFactor: 1,
                child: AppNav.pill(
                  destinations: destinations,
                  selectedIndex: selectedIndex,
                  onSelected: onSelected,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
