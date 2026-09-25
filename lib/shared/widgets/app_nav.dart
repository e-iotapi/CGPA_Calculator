import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:flutter/material.dart';

class NavDestination {
  const NavDestination({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

/// The app's primary navigation: a floating pill along the bottom on narrow
/// windows, a left rail on wide ones. Every destination always shows its
/// label — profile names are user-chosen, so an icon alone is ambiguous.
///
/// Deliberately not a [BottomNavigationBar]: that silently switches to
/// `shifting` at four items, which drops the background colour and hides
/// unselected labels.
class AppNav extends StatelessWidget {
  const AppNav.pill({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  }) : vertical = false;

  const AppNav.rail({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  }) : vertical = true;

  final List<NavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool vertical;

  /// The pill centres at this width rather than stretching across tablets.
  static const double pillMaxWidth = 480;
  static const double railWidth = 96;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final items = [
      for (var i = 0; i < destinations.length; i++)
        _NavItem(
          destination: destinations[i],
          selected: i == selectedIndex,
          onTap: () => onSelected(i),
          vertical: vertical,
        ),
    ];

    final Widget body =
        vertical
            ? SizedBox(
              width: railWidth,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: Space.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final item in items) ...[
                      item,
                      const SizedBox(height: Space.sm),
                    ],
                  ],
                ),
              ),
            )
            : ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: pillMaxWidth),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Row(
                  children: [for (final item in items) Expanded(child: item)],
                ),
              ),
            );

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Navigation',
      child: Container(
        decoration: BoxDecoration(
          color: p.navBackground,
          // On dark grounds the nav is only a shade lighter; a hairline keeps
          // its edge visible.
          border: p.isDark ? Border.all(color: p.divider) : null,
          borderRadius: BorderRadius.circular(
            vertical ? Radii.card : Radii.nav,
          ),
        ),
        child: body,
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
    required this.vertical,
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final fg = selected ? p.onHero : p.navIcon;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.row),
    );
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? p.hero : Colors.transparent,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          splashColor: fg.withValues(alpha: 0.10),
          highlightColor: fg.withValues(alpha: 0.06),
          child: ConstrainedBox(
            // Grows with the text rather than clipping it.
            constraints: BoxConstraints(
              minHeight: vertical ? 60 : Sizes.navItem,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(destination.icon, size: 19, color: fg),
                  const SizedBox(height: 3),
                  Text(
                    destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: TypeScale.family,
                      fontSize: 10.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      color: fg,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
