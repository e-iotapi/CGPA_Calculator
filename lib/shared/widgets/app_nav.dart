import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/shared/tour_key.dart';
import 'package:cgpa_calculator/shared/widgets/pointer_mark.dart';
import 'package:flutter/material.dart';

/// One entry of [AppNav].
class NavDestination {
  const NavDestination({required this.icon, required this.label, this.tourId});

  /// The entry's icon.
  final IconData icon;

  /// The entry's label, also its tooltip and screen-reader name.
  final String label;

  /// The guided tour's key id for this entry, when it tours it.
  final String? tourId;
}

/// Gives [item] the tour key of [d], if it has one.
Widget _tour(NavDestination d, Widget item) =>
    d.tourId == null
        ? item
        : KeyedSubtree(key: tourKey(d.tourId!), child: item);

/// The app's primary navigation: a floating pill along the bottom on narrow
/// windows, a left rail on wide ones.
///
/// On the pill (boards `Main`, `More`) the selected destination is a mint
/// pill with its icon and label; the others are 50px round icon buttons whose
/// label is their tooltip and screen-reader name (44px under [narrowWidth]).
/// When the selected label cannot fit (200% text, a long profile name) the
/// pill drops to its icon rather than squeezing the others. The rail has
/// room, so it always shows every label.
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
  static const double pillMaxWidth = 420;

  /// The rail's width.
  static const double railWidth = 96;

  /// Below this window width the pill's icons shrink from 50px to the 44px
  /// minimum, so the selected label still fits on a 320px phone.
  static const double narrowWidth = 360;

  /// The pill's icon-button size at the window width of [context].
  static double itemSize(BuildContext context) =>
      MediaQuery.sizeOf(context).width < narrowWidth
          ? Sizes.minTouch
          : Sizes.navItem;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final Widget body;
    if (vertical) {
      body = SizedBox(
        width: railWidth,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, Space.lg, 12, Space.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: PointerMark(
                  color: p.isDark ? p.onHero : p.hero,
                  size: 30,
                ),
              ),
              const SizedBox(height: Space.lg),
              for (var i = 0; i < destinations.length; i++) ...[
                _tour(
                  destinations[i],
                  _RailItem(
                    destination: destinations[i],
                    onMint: p.isDark,
                    selected: i == selectedIndex,
                    onTap: () => onSelected(i),
                  ),
                ),
                const SizedBox(height: Space.sm),
              ],
            ],
          ),
        ),
      );
    } else {
      body = ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: pillMaxWidth),
        child: SizedBox(
          height: Sizes.nav,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < destinations.length; i++)
                  if (i == selectedIndex)
                    Flexible(
                      child: _tour(
                        destinations[i],
                        _SelectedPill(
                          destination: destinations[i],
                          onTap: () => onSelected(i),
                        ),
                      ),
                    )
                  else
                    _tour(
                      destinations[i],
                      _IconItem(
                        destination: destinations[i],
                        onTap: () => onSelected(i),
                      ),
                    ),
              ],
            ),
          ),
        ),
      );
    }

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Navigation',
      child: Container(
        decoration: BoxDecoration(
          // In dark mode the rail is mint, so it stands out (owner,
          // 2026-10-04); the pill keeps the dark nav colour.
          color: vertical && p.isDark ? p.hero : p.navBackground,
          borderRadius: BorderRadius.circular(
            vertical ? Radii.card : Radii.nav,
          ),
        ),
        // On dark grounds the nav is only a shade lighter; a hairline keeps
        // its edge visible. Drawn on top: as a border it padded the items,
        // shifting them 1 px in dark mode only (owner, 2026-10-06).
        foregroundDecoration:
            p.isDark
                ? BoxDecoration(
                  border: Border.all(color: p.divider),
                  borderRadius: BorderRadius.circular(
                    vertical ? Radii.card : Radii.nav,
                  ),
                )
                : null,
        child: body,
      ),
    );
  }
}

const _itemShape = StadiumBorder();

/// An unselected destination on the pill: a round icon button.
class _IconItem extends StatelessWidget {
  const _IconItem({required this.destination, required this.onTap});

  final NavDestination destination;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Tooltip(
      message: destination.label,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        selected: false,
        label: destination.label,
        excludeSemantics: true,
        child: Material(
          type: MaterialType.transparency,
          shape: _itemShape,
          child: InkWell(
            onTap: onTap,
            customBorder: _itemShape,
            splashColor: p.navIcon.withValues(alpha: 0.12),
            highlightColor: p.navIcon.withValues(alpha: 0.08),
            child: SizedBox.square(
              dimension: AppNav.itemSize(context),
              child: Icon(destination.icon, size: 19, color: p.navIcon),
            ),
          ),
        ),
      ),
    );
  }
}

/// The selected destination on the pill: mint, icon and label side by side.
class _SelectedPill extends StatelessWidget {
  const _SelectedPill({required this.destination, required this.onTap});

  final NavDestination destination;
  final VoidCallback onTap;

  static const _pad = 13.0;
  static const _icon = 17.0;
  static const _gap = 7.0;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final style = TextStyle(
      fontFamily: TypeScale.family,
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
      color: p.onHero,
    );
    return Semantics(
      button: true,
      selected: true,
      label: destination.label,
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, c) {
          // Shows the label only when it fits whole.
          final label = TextPainter(
            text: TextSpan(
              text: destination.label,
              style: DefaultTextStyle.of(context).style.merge(style),
            ),
            maxLines: 1,
            textScaler: MediaQuery.textScalerOf(context),
            textDirection: Directionality.of(context),
          )..layout();
          final full = _pad * 2 + _icon + _gap + label.width;
          label.dispose();
          // A pixel of slack: the painter and the laid-out text can differ
          // in the last decimal.
          final showLabel = full + 1 <= c.maxWidth;
          final item = AppNav.itemSize(context);
          return Material(
            color: p.hero,
            shape: _itemShape,
            child: InkWell(
              onTap: onTap,
              customBorder: _itemShape,
              child: SizedBox(
                height: item,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: showLabel ? _pad : 0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (!showLabel) SizedBox(width: (item - _icon) / 2),
                      Icon(destination.icon, size: _icon, color: p.onHero),
                      if (showLabel) ...[
                        const SizedBox(width: _gap),
                        // Flexible absorbs sub-pixel rounding; the check
                        // above already guarantees the whole label fits.
                        Flexible(
                          child: Text(
                            destination.label,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.clip,
                            style: style,
                          ),
                        ),
                      ] else
                        SizedBox(width: (item - _icon) / 2),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A destination on the left rail: icon over label, mint when selected.
class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.destination,
    required this.selected,
    required this.onMint,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;

  /// Drawn on the mint rail of dark mode: dark icons and labels, and a
  /// dark pill when selected (a mint one would vanish).
  final bool onMint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final fg =
        onMint
            ? (selected ? p.hero : p.onHero)
            : (selected ? p.onHero : p.navIcon);
    const shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(Radii.row)),
    );
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? (onMint ? p.onHero : p.hero) : Colors.transparent,
        shape: shape,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          splashColor: fg.withValues(alpha: 0.10),
          highlightColor: fg.withValues(alpha: 0.06),
          child: ConstrainedBox(
            // Grows with the text rather than clipping it.
            constraints: const BoxConstraints(minHeight: 60),
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
