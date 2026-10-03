import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/routes.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/resources/resource.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/features/contribute/add_page.dart';
import 'package:cgpa_calculator/features/contribute/apply_page.dart';
import 'package:cgpa_calculator/features/contribute/contribute_data.dart';
import 'package:cgpa_calculator/features/contribute/contribute_widgets.dart';
import 'package:cgpa_calculator/features/contribute/edit_page.dart';
import 'package:cgpa_calculator/features/contribute/pending_page.dart';
import 'package:cgpa_calculator/features/resources/resources_page.dart';
import 'package:cgpa_calculator/features/setup/campus_pick_page.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/bottom_action.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:cgpa_calculator/shared/widgets/sliver_row_group.dart';
import 'package:flutter/material.dart';

String mineKey(String campus) => 'rmine-ui|$campus|${roleStore?.me}';

/// My links, shown when no filter is on or [f] matches.
enum ContribFilter { all, awaiting, approved, rejected }

bool _matches(ContribFilter f, LinkState s) => switch (f) {
  ContribFilter.all => true,
  ContribFilter.awaiting => s == LinkState.awaiting || s == LinkState.expired,
  ContribFilter.approved => s == LinkState.approved,
  ContribFilter.rejected => s == LinkState.rejected,
};

/// Board `Contribute`: my links with their state, and Add links. Staff
/// publish at once, so they get the button and no states.
class ContributePage extends StatefulWidget {
  const ContributePage({super.key});

  @override
  State<ContributePage> createState() => _ContributePageState();
}

class _ContributePageState extends State<ContributePage> {
  var _filter = ContribFilter.all;

  Future<void> _add(VoidCallback reload) async {
    await openRoute(context, Routes.contributeAdd, () => const AddPage());
    reload();
  }

  @override
  Widget build(BuildContext context) {
    final campus = viewCampus();
    const header = PageHeader(eyebrow: 'MORE', title: 'Contribute');
    final store = resourceStore;
    if (store == null || campus == null) {
      return PageFrame(
        header: header,
        children: [
          if (store == null)
            const Note('Sign in with your BITS account to contribute.')
          else
            campusPrompt(context),
        ],
      );
    }
    final direct = contributesDirectly;
    if (!direct) {
      return Loaded<MyContrib>(
        cacheKey: 'contrib-me|$campus|${roleStore!.me}',
        load: loadMyContrib,
        peek: peekMyContrib,
        builder: (context, mine, _) {
          return switch (contribStateOf(mine)) {
            ContribState.approved => _links(campus, header, mine, direct),
            ContribState.applied => const PendingPage(),
            _ => const ApplyPage(),
          };
        },
      );
    }
    return _links(campus, header, null, direct);
  }

  Widget _links(String campus, Widget header, MyContrib? mine, bool direct) {
    final p = AppPalette.of(context);
    final store = resourceStore!;
    return Loaded<List<Resource>>(
      cacheKey: mineKey(campus),
      load: () => store.mine(campus),
      peek: () => store.peekMine(campus),
      builder: (context, all, reload) {
        final now = DateTime.now();
        final rows = [
          for (final r in all)
            if (linkStateOf(r, now) case final s?)
              if (direct || _matches(_filter, s)) (r, s),
        ];
        return PageFrame(
          header: header,
          bottom: BottomAction(
            child: PrimaryButton(
              label: 'Add links',
              icon: Icons.add_rounded,
              onPressed: () => _add(reload),
            ),
          ),
          children: [
            if (direct)
              const Note(
                'Your links go live at once and need no approval.',
              )
            else ...[
              Text(
                '${mine?.me.points ?? 0} points · counted after approval',
                style: TypeScale.caption.copyWith(color: p.textMuted),
              ),
              const SizedBox(height: Space.sm),
              ChoicePills<ContribFilter>(
                values: ContribFilter.values,
                selected: _filter,
                label:
                    (f) => switch (f) {
                      ContribFilter.all => 'All',
                      ContribFilter.awaiting => 'Awaiting',
                      ContribFilter.approved => 'Approved',
                      ContribFilter.rejected => 'Rejected',
                    },
                onSelected: (f) => setState(() => _filter = f),
              ),
              const SizedBox(height: Space.sm),
            ],
            if (rows.isEmpty)
              Note(
                all.isEmpty || direct
                    ? 'No links yet'
                    : 'No ${_filter.name} links.',
              )
            else
              SliverRowGroup(
                count: rows.length,
                row: (context, i) {
                  final (r, s) = rows[i];
                  return _MyLink(r, s, direct: direct, onChanged: reload);
                },
              ),
          ],
        );
      },
    );
  }
}

class _MyLink extends StatelessWidget {
  const _MyLink(this.r, this.state, {required this.direct, this.onChanged});
  final Resource r;
  final LinkState state;
  final bool direct;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final where = r.isCourse ? (r.fromCourse ?? '') : departmentName(r.department);
    return Semantics(
      button: true,
      label: '${r.title}, $where, ${state.name}',
      excludeSemantics: true,
      child: InkWell(
        onTap: () async {
          await openRoute(
            context,
            Routes.contributeEdit(r.id),
            () => EditPage(id: r.id),
          );
          onChanged?.call();
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TypeScale.body.copyWith(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: p.text,
                        ),
                      ),
                      Text(
                        '$where · ${r.host}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TypeScale.caption.copyWith(color: p.textMuted),
                      ),
                      if (state == LinkState.rejected)
                        Text(
                          r.rejectedReason,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TypeScale.caption.copyWith(color: p.behind),
                        ),
                    ],
                  ),
                ),
                if (!direct) ...[
                  const SizedBox(width: 8),
                  LinkStateChip(state),
                ],
                Icon(Icons.chevron_right, size: 18, color: p.icon),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
