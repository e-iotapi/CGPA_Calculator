import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/admin/dept_list.dart';
import 'package:cgpa_calculator/app/routes.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/catalog/catalog.dart';
import 'package:cgpa_calculator/core/models/offering.dart';
import 'package:cgpa_calculator/core/professors/professor_store.dart';
import 'package:cgpa_calculator/core/roles/capabilities.dart';
import 'package:cgpa_calculator/core/roles/maintain_store.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/core/storage/cache_boxes.dart';
import 'package:cgpa_calculator/features/marks/official.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/card_row.dart';
import 'package:cgpa_calculator/shared/widgets/notice.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:cgpa_calculator/shared/widgets/search_box.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce/hive.dart';

const _recentKey = 'openAsRecent';
const _campuses = ['goa', 'hyderabad', 'pilani', 'dubai'];

/// [keys] with the ones in [recent] first, most recent first; the rest keep
/// their order (§10.22: the last opened on top).
List<String> recentFirst(List<String> keys, List<String> recent) => [
  for (final r in recent)
    if (keys.contains(r)) r,
  for (final k in keys)
    if (!recent.contains(k)) k,
];

/// What Open as opened last on this device, most recent first.
List<String> openedRecently() {
  if (!Hive.isBoxOpen(deviceBoxName)) return const [];
  final raw = Hive.box(deviceBoxName).get(_recentKey);
  return raw is List ? [for (final r in raw) '$r'] : const [];
}

Future<void> _remember(String key) async {
  if (!Hive.isBoxOpen(deviceBoxName)) return;
  final next = [key, ...openedRecently().where((k) => k != key)].take(8);
  await Hive.box(deviceBoxName).put(_recentKey, next.toList());
}

/// Board `RolePick`: an owner opens Pointer as any role (§16.3 fix 1). It
/// changes what they see, not what they can do: the database still sees the
/// owner, and every save is theirs.
class OpenAsPage extends StatelessWidget {
  const OpenAsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final name = roleStore?.myName ?? '';
    void open(ViewAs? v, String to) {
      viewAs.value = v;
      context.go(to);
    }

    Widget row(
      String tag,
      bool strong,
      String title,
      String line,
      VoidCallback go,
    ) => CardRow(
      minHeight: 56,
      // 58 wide on the board, so the titles line up; never narrower than
      // the tag itself.
      leading: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 58),
        child: Align(
          widthFactor: 1,
          alignment: Alignment.centerLeft,
          child: TierTag(tag, strong: strong),
        ),
      ),
      title: title,
      // Two lines at large text beside the 58 wide tag (T9.1).
      titleLines: 2,
      subtitle: line,
      onTap: go,
    );

    return PageFrame(
      header: const PageHeader(
        eyebrow: 'OWNER · TESTING AND DEVELOPMENT',
        title: 'Open Pointer as',
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: p.navBackground,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: p.hero,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  name.isEmpty ? '?' : name[0].toUpperCase(),
                  style: TypeScale.body.copyWith(
                    fontWeight: FontWeight.w800,
                    color: p.onHero,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'You' : name,
                      style: TypeScale.body.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: p.isDark ? p.text : p.onInverse,
                      ),
                    ),
                    Text(
                      'Signed in as an owner',
                      style: TypeScale.caption.copyWith(
                        fontSize: 10.5,
                        color: p.navIcon,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              row(
                'OWNER',
                false,
                'Owner',
                'Everything, every campus',
                () => open(null, Routes.admin),
              ),
              const CardDivider(),
              row(
                'ADMIN',
                true,
                'Admin',
                'Controls without Owner only',
                () => open(const ViewAs(Role.admin), Routes.admin),
              ),
              const CardDivider(),
              row(
                'PRES',
                false,
                'Department president',
                'Pick a department and campus',
                () => context.push(Routes.openAsDept),
              ),
              const CardDivider(),
              row(
                'CR',
                true,
                'Course manager',
                'Pick a course and campus',
                () => context.push(Routes.openAsCourse),
              ),
              const CardDivider(),
              row(
                'STUDENT',
                false,
                'Student',
                'Your own grades, as any student sees them',
                () => open(const ViewAs(Role.student), Routes.home),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Notice(
          warning: true,
          text: TextSpan(
            children: [
              TextSpan(
                text: 'This changes what you see, not what you can do. ',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              TextSpan(
                text:
                    'The database still sees your owner account: anything you '
                    'save is saved as you and logged with your name. A strip '
                    'at the top says which role you are viewing as, with a '
                    'button back here.',
              ),
            ],
          ),
        ),
        const Note(
          'Only owners ever see this screen. Testing what a role may actually '
          'do uses the emulator and test accounts, never this screen.',
        ),
      ],
    );
  }
}

/// The campus pills and a search box, shared by both pickers.
class _PickerFrame extends StatelessWidget {
  const _PickerFrame({
    required this.title,
    required this.campus,
    required this.onCampus,
    required this.search,
    required this.hint,
    required this.onSearch,
    required this.children,
    this.eyebrow = 'OPEN AS · DEPARTMENT PRESIDENT',
  });
  final String eyebrow, title, campus, hint;
  final ValueChanged<String> onCampus;
  final TextEditingController search;
  final VoidCallback onSearch;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => PageFrame(
    header: PageHeader(eyebrow: eyebrow, title: title),
    children: [
      ChoicePills<String>(
        values: _campuses,
        selected: campus,
        // The board's short form, so four fit at 320.
        label: (c) => c == 'hyderabad' ? 'Hyd' : campusName(c),
        equal: true,
        onSelected: onCampus,
      ),
      const SizedBox(height: Space.sm),
      SearchBox(controller: search, hint: hint, onChanged: (_) => onSearch()),
      ...children,
    ],
  );
}

/// A card of picker rows: the title over a line, and a chevron.
Widget _rows(List<(String, String, VoidCallback)> rows) => AppCard(
  padding: EdgeInsets.zero,
  child: Column(
    children: [
      for (final (i, (title, line, go)) in rows.indexed) ...[
        if (i > 0) const CardDivider(),
        CardRow(title: title, subtitle: line, onTap: go, titleLines: 2),
      ],
    ],
  ),
);

/// Board `ViewAsDept`: which department to open as its president; the last
/// opened sits on top. ELEC has a row per programme, since each has its own
/// presidents, and every row opens the ELEC they manage together.
class ViewAsDeptPage extends StatefulWidget {
  const ViewAsDeptPage({super.key});

  @override
  State<ViewAsDeptPage> createState() => _ViewAsDeptPageState();
}

class _ViewAsDeptPageState extends State<ViewAsDeptPage> {
  String _campus = 'goa';
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _open(String dept) async {
    await _remember('dept:$_campus:$dept');
    viewAs.value = ViewAs(Role.president, campus: _campus, scope: dept);
    if (mounted) context.go(Routes.dept(_campus, dept));
  }

  @override
  Widget build(BuildContext context) => Loaded<(List<Grant>, List<String>)>(
    cacheKey: 'open-as-depts|$_campus',
    key: ValueKey(_campus),
    load:
        () async => (
          await roleStore!.roster(campus: _campus),
          await departmentSource.at(_campus),
        ),
    peek: () {
      final grants = roleStore!.peekRoster(campus: _campus);
      return grants == null ? null : (grants, departmentsAt(_campus));
    },
    builder: (context, data, _) {
      final (grants, depts) = data;
      final now = DateTime.now();
      final q = _search.text.trim().toLowerCase();
      final recent = [
        for (final r in openedRecently())
          if (r.startsWith('dept:$_campus:')) r.split(':').last,
      ];
      final keys = recentFirst(depts, recent);
      final shown = [
        for (final b in deptBranches(keys))
          if (branchMatches(b, q)) b,
      ];
      int presidents(String d, String? prog) =>
          grants
              .where(
                (g) =>
                    g.role == GrantRole.dept &&
                    g.scope == d &&
                    (prog == null || g.programme == prog) &&
                    g.campus == _campus &&
                    g.liveAt(now),
              )
              .length;
      return _PickerFrame(
        title: 'Which department?',
        campus: _campus,
        onCampus: (c) => setState(() => _campus = c),
        search: _search,
        hint: 'Dept or programme',
        onSearch: () => setState(() {}),
        children: [
          SectionLabel(
            '${campusName(_campus)} · '
            '${deptBranches(depts).length} '
            'branches',
          ),
          if (shown.isEmpty)
            const Note('No department matches.')
          else
            _rows([
              for (final b in shown)
                (
                  branchName(b),
                  '${branchCodes(b)} · '
                      '${presidents(b.dept, b.programme)} president'
                      '${presidents(b.dept, b.programme) == 1 ? '' : 's'}'
                      '${recent.contains(b.dept) ? ' · opened recently' : ''}',
                  () => _open(b.dept),
                ),
            ]),
        ],
      );
    },
  );
}

typedef _Offered = ({String id, List<String> professors, int crs});

/// Board `ViewAsCourse`: which of this term's offerings to open as its CR,
/// each with its professors and CR count; the last opened on top.
class ViewAsCoursePage extends StatefulWidget {
  const ViewAsCoursePage({super.key});

  @override
  State<ViewAsCoursePage> createState() => _ViewAsCoursePageState();
}

class _ViewAsCoursePageState extends State<ViewAsCoursePage> {
  String _campus = 'goa';
  final _search = TextEditingController();
  final _term = currentTerm(DateTime.now());

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<List<_Offered>> _load() async {
    final store = roleStore!;
    final got = await MaintainStore(store).campusOfferings(_campus, _term);
    final grants = await store.roster(campus: _campus);
    final profs = ProfessorStore(store.db);
    final names = <String, String>{};
    final now = DateTime.now();
    final out = <_Offered>[];
    for (final o in got) {
      final id = o.courseId;
      if (id.isEmpty) continue;
      final ps = <String>[];
      for (final pid in o.professors) {
        final n = names[pid] ??= (await profs.get(pid))?.name ?? '';
        if (n.isNotEmpty) ps.add(n);
      }
      out.add((
        id: id,
        professors: ps,
        crs:
            grants
                .where(
                  (g) =>
                      g.role == GrantRole.course &&
                      g.scope == id &&
                      g.liveAt(now),
                )
                .length,
      ));
    }
    return out..sort((a, b) => a.id.compareTo(b.id));
  }

  Future<void> _open(String id) async {
    await _remember('course:$_campus:$id');
    viewAs.value = ViewAs(Role.cr, campus: _campus, scope: id);
    if (mounted) context.go(Routes.crCourse(_campus, id));
  }

  @override
  Widget build(BuildContext context) => Loaded<List<_Offered>>(
    cacheKey: 'open-as-courses|$_campus',
    key: ValueKey(_campus),
    load: _load,
    peek: () {
      final store = roleStore!;
      final got = MaintainStore(store).peekCampusOfferings(_campus, _term);
      final grants = store.peekRoster(campus: _campus);
      if (got == null || grants == null) return null;
      final profs = ProfessorStore(store.db);
      final names = <String, String>{};
      final now = DateTime.now();
      final out = <_Offered>[];
      for (final o in got) {
        final id = o.courseId;
        if (id.isEmpty) continue;
        final ps = <String>[];
        for (final pid in o.professors) {
          final p = profs.peekGet(pid);
          if (p == null) return null;
          final n = names[pid] ??= p.name;
          if (n.isNotEmpty) ps.add(n);
        }
        out.add((
          id: id,
          professors: ps,
          crs:
              grants
                  .where(
                    (g) =>
                        g.role == GrantRole.course &&
                        g.scope == id &&
                        g.liveAt(now),
                  )
                  .length,
        ));
      }
      return out..sort((a, b) => a.id.compareTo(b.id));
    },
    builder: (context, offered, _) {
      final q = _search.text.trim().toLowerCase();
      final recent = [
        for (final r in openedRecently())
          if (r.startsWith('course:$_campus:')) r.split(':').last,
      ];
      final byId = {for (final o in offered) o.id: o};
      final order = recentFirst([for (final o in offered) o.id], recent);
      final shown = [
        for (final id in order)
          if (q.isEmpty ||
              id.toLowerCase().contains(q) ||
              byId[id]!.professors.any((n) => n.toLowerCase().contains(q)))
            byId[id]!,
      ];
      return _PickerFrame(
        eyebrow: 'OPEN AS · COURSE MANAGER',
        title: 'Which course?',
        campus: _campus,
        onCampus: (c) => setState(() => _campus = c),
        search: _search,
        hint: 'Code or professor',
        onSearch: () => setState(() {}),
        children: [
          SectionLabel('${campusName(_campus)} · offered ${termLabel(_term)}'),
          if (shown.isEmpty)
            Note(
              offered.isEmpty
                  ? 'Nothing is offered on this campus for ${termLabel(_term)} '
                      'yet.'
                  : 'No course matches.',
            )
          else
            _rows([
              for (final o in shown)
                (
                  '${o.id} · ${catalog.master.where((m) => m.id == o.id).firstOrNull?.title ?? ''}',
                  '${o.professors.isEmpty ? 'No professor yet' : o.professors.join(', ')}'
                      ' · ${o.crs} CR${o.crs == 1 ? '' : 's'}',
                  () => _open(o.id),
                ),
            ]),
        ],
      );
    },
  );
}
