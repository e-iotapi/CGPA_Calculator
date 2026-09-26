import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
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
import 'package:flutter/semantics.dart';

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
    required this.onOpenCalendar,
    required this.onOpenSettings,
    required this.onToggleTheme,
    this.offshoot,
    this.classDeltas = const {},
    this.slideFromRight = true,
    this.onCompareGradePicked,
    this.onCompareChanged,
    this.onReorder,
  });

  final SemesterData data;

  /// "Good evening".
  final String greeting;
  final String name;

  final ValueChanged<String> onSemesterSelected;
  final ValueChanged<CourseSort> onSortSelected;

  /// This semester's courses in the order they were dragged into. Null
  /// hides the drag handles.
  final ValueChanged<List<Course>>? onReorder;
  final VoidCallback onExport;
  final VoidCallback onAddCourse;

  /// The course and its index in [SemesterData.courses].
  final void Function(Course course, int index) onCourseTap;
  final void Function(Course course, int grade) onGradePicked;

  /// A grade set from a Compare column, for profile id [profile].
  final void Function(Course course, int profile, int grade)?
  onCompareGradePicked;

  /// Compare's [slot] (0 left, 1 right) now shows profile id [profile].
  final void Function(int slot, int profile)? onCompareChanged;

  /// The user held a pull-down at the top of the list.
  final VoidCallback onClearRequested;

  /// +1 for the next tab, -1 for the previous.
  final ValueChanged<int> onSwipe;
  final VoidCallback onOpenAnalytics;
  final VoidCallback onOpenCalendar;
  final VoidCallback onOpenSettings;

  /// Flips between the light and dark palettes.
  final VoidCallback onToggleTheme;

  /// Shown in place of the stats and course list on the offshoot tab, filling
  /// the space below the header.
  final Widget? offshoot;
  final bool slideFromRight;

  /// Class-average delta by course id; courses without one show nothing.
  final Map<String, double> classDeltas;

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
            switchInCurve: Motion.curve,
            switchOutCurve: Motion.exitCurve,
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
            sliver: SliverReorderableList(
              itemCount: d.courses.length,
              onReorderItem: (from, to) {
                final order = [...d.courses];
                order.insert(to, order.removeAt(from));
                widget.onReorder?.call(order);
              },
              itemBuilder:
                  (_, i) => Padding(
                    key: ObjectKey(d.courses[i]),
                    padding: EdgeInsets.only(
                      bottom: i == d.courses.length - 1 ? 0 : 9,
                    ),
                    child: _draggable(
                      i,
                      CourseRow(
                        course: d.courses[i],
                        mode: d.mode,
                        classDelta: widget.classDeltas[d.courses[i].id],
                        onTap: () => widget.onCourseTap(d.courses[i], i),
                        onGradePicked:
                            (g) => widget.onGradePicked(d.courses[i], g),
                        compared: d.compared,
                        onCompareGradePicked:
                            widget.onCompareGradePicked == null
                                ? null
                                : (profile, g) => widget.onCompareGradePicked!(
                                  d.courses[i],
                                  profile,
                                  g,
                                ),
                      ),
                    ),
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
    // Four 46px buttons leave a narrow phone too little room for the name.
    final narrow = MediaQuery.sizeOf(context).width < 380;
    final btn = narrow ? 40.0 : Sizes.iconButton;
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
        CircleIconButton(
          icon: Icons.calendar_today_outlined,
          tooltip: 'Calendar',
          onPressed: widget.onOpenCalendar,
          size: btn,
        ),
        const SizedBox(width: Space.sm),
        CircleIconButton(
          icon: Icons.insert_chart_outlined_rounded,
          tooltip: 'Stats',
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
      StatCard card(int slot) {
        final f = slot == 0 ? d.comparedFigures.$1 : d.comparedFigures.$2;
        return StatCard(
          label: d.nameOf(slot == 0 ? d.compared.$1 : d.compared.$2),
          value: formatGpa(f.term),
          caption:
              'CGPA ${formatGpa(f.overall)} · '
              '${formatCredits(f.overall.shownCredits)} cr',
          hero: slot == 0,
          onTap:
              widget.onCompareChanged == null ? null : () => _pickProfile(slot),
          tapHint: 'Change profile',
        );
      }

      cards = [card(0), card(1)];
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

  /// Picks the profile for Compare's [slot]. Choosing the one on the other
  /// side swaps the two.
  Future<void> _pickProfile(int slot) async {
    final p = AppPalette.of(context);
    final here = slot == 0 ? d.compared.$1 : d.compared.$2;
    final other = slot == 0 ? d.compared.$2 : d.compared.$1;
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      backgroundColor: p.background,
      builder:
          (c) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: Space.lg),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.gutter,
                    0,
                    Space.gutter,
                    Space.sm,
                  ),
                  child: Text(
                    'Compare with',
                    style: TypeScale.title.copyWith(color: p.text),
                  ),
                ),
                for (final (i, name) in d.profileNames.indexed)
                  ListTile(
                    title: Text(
                      name,
                      style: TypeScale.body.copyWith(color: p.text),
                    ),
                    subtitle:
                        i + 1 == other
                            ? Text(
                              'On the other side; swaps',
                              style: TypeScale.caption.copyWith(
                                color: p.textMuted,
                              ),
                            )
                            : null,
                    trailing:
                        i + 1 == here
                            ? Icon(Icons.check_rounded, color: p.text)
                            : null,
                    onTap: () => Navigator.pop(c, i + 1),
                  ),
              ],
            ),
          ),
    );
    if (picked != null && picked != here) {
      widget.onCompareChanged!(slot, picked);
    }
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
          col(d.nameOf(d.compared.$1)),
          const SizedBox(width: Space.sm),
          col(d.nameOf(d.compared.$2)),
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

  /// Row [i] with a drag handle before it, and move up / down for screen
  /// readers. As it was when reordering is off.
  Widget _draggable(int i, Widget row) {
    final reorder = widget.onReorder;
    if (reorder == null) return row;
    final p = AppPalette.of(context);
    final courses = widget.data.courses;
    void move(int to) {
      final order = [...courses];
      order.insert(to, order.removeAt(i));
      reorder(order);
    }

    return Semantics(
      customSemanticsActions: {
        if (i > 0)
          const CustomSemanticsAction(label: 'Move up'): () => move(i - 1),
        if (i < courses.length - 1)
          const CustomSemanticsAction(label: 'Move down'): () => move(i + 1),
      },
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: i,
            child: Tooltip(
              message: 'Drag to reorder',
              child: SizedBox(
                width: 22,
                height: Sizes.minTouch,
                child: Icon(
                  Icons.drag_indicator_rounded,
                  size: 18,
                  color: p.textMuted.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
          Expanded(child: row),
        ],
      ),
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
