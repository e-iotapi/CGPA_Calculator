import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/grading/cgpa.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/semester/semester_controller.dart';
import 'package:cgpa_calculator/features/semester/widgets/course_row.dart';
import 'package:cgpa_calculator/features/semester/widgets/semester_pills.dart';
import 'package:cgpa_calculator/shared/layout/breakpoints.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/circle_icon_button.dart';
import 'package:cgpa_calculator/shared/widgets/pill_button.dart';
import 'package:cgpa_calculator/shared/widgets/stat_card.dart';
import 'package:flutter/material.dart';

/// The home screen: greeting, one-line summary, SGPA/CGPA, semester picker
/// and the course list. Purely presentational — every change goes out
/// through a callback, and the owner rebuilds it with fresh [data].
class SemesterView extends StatefulWidget {
  const SemesterView({
    super.key,
    required this.data,
    required this.greeting,
    required this.name,
    required this.onSemesterSelected,
    required this.onSortSelected,
    required this.onExport,
    required this.onAddCourse,
    required this.onCourseTap,
    required this.onGradePicked,
    required this.onClearRequested,
    required this.onSwipe,
    required this.onOpenAnalytics,
    required this.onOpenSettings,
    required this.onToggleTheme,
    this.onInstall,
    this.offshoot,
    this.slideFromRight = true,
  });

  final SemesterData data;

  /// "Good evening".
  final String greeting;
  final String name;

  final ValueChanged<String> onSemesterSelected;
  final ValueChanged<CourseSort> onSortSelected;
  final VoidCallback onExport;
  final VoidCallback onAddCourse;

  /// The course and its index in [SemesterData.courses].
  final void Function(Course course, int index) onCourseTap;
  final void Function(Course course, int grade) onGradePicked;

  /// The user held a pull-down at the top of the list.
  final VoidCallback onClearRequested;

  /// +1 for the next tab, -1 for the previous.
  final ValueChanged<int> onSwipe;
  final VoidCallback onOpenAnalytics;
  final VoidCallback onOpenSettings;

  /// Flips between the light and dark palettes.
  final VoidCallback onToggleTheme;

  /// Null hides the install button.
  final VoidCallback? onInstall;

  /// Shown in place of the stats and course list on the offshoot tab, filling
  /// the space below the header.
  final Widget? offshoot;
  final bool slideFromRight;

  @override
  State<SemesterView> createState() => _SemesterViewState();
}

class _SemesterViewState extends State<SemesterView> {
  final _pull = ValueNotifier<double>(0);
  int _pullSession = 0;

  @override
  void dispose() {
    _pull.dispose();
    super.dispose();
  }

  SemesterData get d => widget.data;

  bool get _single =>
      d.mode == SemesterMode.actual || d.mode == SemesterMode.expected;

  /// Pull down past 60px and hold for a second to be asked whether to clear
  /// this semester's grades. Letting go resets it.
  bool _onScroll(ScrollNotification n) {
    if (!_single) return false;
    final px = n.metrics.pixels;
    _pull.value = px < 0 ? px : 0;
    final pulling =
        px < -60 &&
        ((n is ScrollUpdateNotification && n.dragDetails != null) ||
            (n is OverscrollNotification && n.dragDetails != null));
    if (!pulling) {
      _pullSession = 0;
      return false;
    }
    if (_pullSession != 0) return false;
    final session = _pullSession = DateTime.now().millisecondsSinceEpoch;
    Future.delayed(const Duration(seconds: 1), () {
      if (_pullSession == session && mounted) {
        _pullSession = 0;
        widget.onClearRequested();
      }
    });
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (e) {
        final v = e.primaryVelocity ?? 0;
        if (v < 0) widget.onSwipe(1);
        if (v > 0) widget.onSwipe(-1);
      },
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = Breakpoints.of(c.maxWidth) != WindowSize.compact;
          return AnimatedSwitcher(
            duration: Motion.slow,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder:
                (child, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                    position: Tween(
                      begin: Offset(widget.slideFromRight ? 0.08 : -0.08, 0),
                      end: Offset.zero,
                    ).animate(a),
                    child: child,
                  ),
                ),
            child: KeyedSubtree(
              key: ValueKey(d.mode),
              child:
                  d.mode == SemesterMode.offshoot && widget.offshoot != null
                      ? _offshootLayout()
                      : _listLayout(wide),
            ),
          );
        },
      ),
    );
  }

  Widget _offshootLayout() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.gutter,
          Space.lg,
          Space.gutter,
          Space.sm,
        ),
        child: _header(eyebrow: 'Finance offshoot', title: 'Your total'),
      ),
      Expanded(child: widget.offshoot!),
    ],
  );

  Widget _listLayout(bool wide) {
    final p = AppPalette.of(context);
    final scroll = NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.lg,
              Space.gutter,
              0,
            ),
            sliver: SliverList.list(
              children: [
                _header(),
                const SizedBox(height: 15),
                _editorial(),
                if (!wide) ...[const SizedBox(height: 15), _stats(false)],
                const SizedBox(height: 15),
                _semesterPills(),
                const SizedBox(height: 15),
                _sectionHeader(),
                const SizedBox(height: Space.md),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            sliver: SliverList.separated(
              itemCount: d.courses.length,
              separatorBuilder: (_, _) => const SizedBox(height: 9),
              itemBuilder:
                  (_, i) => CourseRow(
                    course: d.courses[i],
                    mode: d.mode,
                    onTap: () => widget.onCourseTap(d.courses[i], i),
                    onGradePicked: (g) => widget.onGradePicked(d.courses[i], g),
                  ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              9,
              Space.gutter,
              Space.xxl,
            ),
            sliver: SliverToBoxAdapter(
              child: _single ? _addCard() : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );

    final list = Stack(
      children: [
        scroll,
        // Shown while the list is pulled past the top.
        ValueListenableBuilder<double>(
          valueListenable: _pull,
          builder:
              (_, v, _) =>
                  v < -80
                      ? Positioned(
                        top: Space.sm,
                        left: 0,
                        right: 0,
                        child: Text(
                          'Hold to clear grades',
                          textAlign: TextAlign.center,
                          style: TypeScale.caption.copyWith(color: p.textMuted),
                        ),
                      )
                      : const SizedBox.shrink(),
        ),
      ],
    );

    if (!wide) return list;
    // Tablet and up: the stat cards move into a right rail.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: list),
        SizedBox(
          width: 260,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, Space.lg, Space.gutter, 0),
            child: _stats(true),
          ),
        ),
      ],
    );
  }

  /// Greeting and name, or [eyebrow] and [title] in their place.
  Widget _header({String? eyebrow, String? title}) {
    final p = AppPalette.of(context);
    // Three 46px buttons leave a 320px phone too little room for the name.
    final btn =
        MediaQuery.sizeOf(context).width < 380 ? 40.0 : Sizes.iconButton;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Both lines shrink rather than truncate when the header is
              // crowded.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  eyebrow ?? widget.greeting,
                  maxLines: 1,
                  style: TypeScale.caption.copyWith(
                    fontSize: 12.5,
                    color: p.textMuted,
                  ),
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  title ?? widget.name,
                  maxLines: 1,
                  style: TypeScale.title.copyWith(color: p.text),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: Space.md),
        if (widget.onInstall != null) ...[
          CircleIconButton(
            icon: Icons.install_mobile_rounded,
            tooltip: 'Install app',
            onPressed: widget.onInstall,
            size: btn,
          ),
          const SizedBox(width: Space.sm),
        ],
        CircleIconButton(
          icon: Icons.insert_chart_outlined_rounded,
          tooltip: 'Degree progress',
          onPressed: widget.onOpenAnalytics,
          size: btn,
        ),
        const SizedBox(width: Space.sm),
        CircleIconButton(
          icon: p.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          tooltip: p.isDark ? 'Switch to light mode' : 'Switch to dark mode',
          onPressed: widget.onToggleTheme,
          size: btn,
        ),
        const SizedBox(width: Space.sm),
        CircleIconButton(
          icon: Icons.settings_outlined,
          tooltip: 'Settings',
          onPressed: widget.onOpenSettings,
          size: btn,
        ),
      ],
    );
  }

  Widget _editorial() {
    final p = AppPalette.of(context);
    final text = d.editorial;
    final bold = d.editorialEmphasis;
    final base = TypeScale.editorial.copyWith(color: p.textMuted);
    if (bold == null) return Text(text, style: base);
    final i = text.indexOf(bold);
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: text.substring(0, i)),
          TextSpan(
            text: bold,
            style: TextStyle(fontWeight: FontWeight.w800, color: p.text),
          ),
          TextSpan(text: text.substring(i + bold.length)),
        ],
      ),
    );
  }

  Widget _stats(bool stacked) {
    final List<Widget> cards;
    if (d.mode == SemesterMode.compare) {
      StatCard card(Profile p, bool hero) {
        final f = p == Profile.actual ? d.actual : d.expected;
        return StatCard(
          label: d.nameOf(p),
          value: formatGpa(f.term),
          caption:
              'CGPA ${formatGpa(f.overall)} · '
              '${formatCredits(f.overall.shownCredits)} cr',
          hero: hero,
        );
      }

      cards = [card(Profile.actual, true), card(Profile.expected, false)];
    } else {
      final f = d.current;
      cards = [
        StatCard(
          label: 'SGPA',
          value: formatGpa(f.term),
          caption: '${formatCredits(f.term.shownCredits)} credits · ${d.sem}',
          hero: true,
        ),
        StatCard(
          label: 'CGPA',
          value: formatGpa(f.overall),
          caption: '${formatCredits(f.overall.shownCredits)} credits',
        ),
      ];
    }
    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [cards[0], const SizedBox(height: 11), cards[1]],
      );
    }
    // flex-basis 0: neither card can push the other out.
    return Row(
      children: [
        Expanded(child: cards[0]),
        const SizedBox(width: 11),
        Expanded(child: cards[1]),
      ],
    );
  }

  Widget _semesterPills() => SemesterPills(
    semesters: d.semesters,
    selected: d.sem,
    onSelected: widget.onSemesterSelected,
  );

  Widget _sectionHeader() {
    final p = AppPalette.of(context);
    final n = d.courses.length;
    final title = Expanded(
      child: Text(
        '$n course${n == 1 ? '' : 's'}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TypeScale.section.copyWith(color: p.text),
      ),
    );

    if (d.mode == SemesterMode.compare) {
      Widget col(String name) => SizedBox(
        width: compareGradeWidth,
        child: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TypeScale.label.copyWith(fontSize: 10, color: p.textMuted),
        ),
      );
      return Row(
        children: [
          title,
          col(d.profileNames.$1),
          const SizedBox(width: Space.sm),
          col(d.profileNames.$2),
          // Lines the labels up over the chips inside the card padding.
          const SizedBox(width: 15),
        ],
      );
    }

    return Row(
      children: [
        title,
        MenuAnchor(
          menuChildren: [
            for (final s in CourseSort.values)
              MenuItemButton(
                onPressed: () => widget.onSortSelected(s),
                leadingIcon: Icon(
                  s == d.sort ? Icons.check_rounded : null,
                  size: 18,
                ),
                child: Text(s.label, style: TypeScale.button),
              ),
          ],
          builder:
              (_, menu, _) => PillButton(
                label: d.sort.label,
                icon: Icons.sort_rounded,
                height: Sizes.pillSmall,
                onPressed: () => menu.isOpen ? menu.close() : menu.open(),
              ),
        ),
        const SizedBox(width: Space.sm),
        PillButton.icon(
          icon: Icons.download_rounded,
          semanticLabel: 'Export gradesheet',
          onPressed: widget.onExport,
        ),
      ],
    );
  }

  Widget _addCard() {
    final p = AppPalette.of(context);
    return AppCard(
      color: Colors.transparent,
      border: BorderSide(color: p.outline),
      onTap: widget.onAddCourse,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_rounded, size: 18, color: p.text),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              d.courses.isEmpty
                  ? 'No courses in ${d.sem} yet — add some'
                  : 'Add courses',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TypeScale.body.copyWith(color: p.text),
            ),
          ),
        ],
      ),
    );
  }
}
