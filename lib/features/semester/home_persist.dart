// Which settings Home saves for which change (UI_OPT O3.1). Home's build
// saves nothing; each handler saves what it changed, via `writesFor`.

/// What changed on Home.
enum HomeChange { semester, sort, profile, rebuild }

/// A settings write, one per `script.dart` setter: `sem` is `setsem`, `sort`
/// is `setsort`, `profile` is `setprof`.
enum HomeWrite { sem, sort, profile }

/// The writes [c] needs. A plain rebuild needs none.
List<HomeWrite> writesFor(HomeChange c) => switch (c) {
  HomeChange.semester => const [HomeWrite.sem],
  HomeChange.sort => const [HomeWrite.sort],
  HomeChange.profile => const [HomeWrite.profile],
  HomeChange.rebuild => const [],
};
