import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/routes.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/features/roles/rep_profile.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/card_row.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Where a role opens: Home for Student, the department or course page for
/// a grant.
String homeFor(Grant? g) => switch (g?.role) {
  null || GrantRole.admin => g == null ? Routes.home : Routes.admin,
  GrantRole.dept => Routes.dept(g!.campus, g.scope),
  GrantRole.course => Routes.crCourse(g!.campus, g.scope),
};

/// "Student", "President · ELEC", "CR · CS F301".
String roleLabel(Grant? g) => switch (g?.role) {
  null => 'Student',
  GrantRole.admin => 'Admin',
  GrantRole.dept => 'President · ${g!.scope}',
  GrantRole.course => 'CR · ${g!.scope}',
};

/// Board `RoleSwitch`: a president or CR picks the role Pointer works in
/// (§16.3 fix 15). It is really them — every save is theirs and logged. The
/// choice stays on this device; a lapsed grant drops back to Student.
class RoleSwitchPage extends StatelessWidget {
  const RoleSwitchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final r = myRoles.value;
    final now = workingAs.value;
    final campus =
        r.grants.map((g) => g.campus).where((c) => c != 'all').firstOrNull;

    Future<void> pick(Grant? g) async {
      await setWorkingAs(g);
      if (!context.mounted) return;
      if (GoRouter.maybeOf(context) != null) {
        context.go(homeFor(g));
      } else {
        Navigator.of(context).maybePop();
      }
    }

    Widget option(Grant? g) {
      final selected = g?.id == now?.id;
      return InkWell(
        onTap: () => pick(g),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 12, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    g == null ? const TierTag('STUDENT') : TierTag.of(g.role),
                    const SizedBox(height: 6),
                    Text(
                      g == null ? 'Student' : g.role.label,
                      style: TypeScale.body.copyWith(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: p.text,
                      ),
                    ),
                    Text(
                      g == null
                          ? 'Your own grades'
                          : '${g.scopeLabel} · until '
                              '${shortDay(g.expiresAt, year: true)}',
                      style: TypeScale.caption.copyWith(color: p.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Space.sm),
              selected
                  ? const ScopeChip('✓ NOW')
                  : Icon(Icons.chevron_right_rounded, color: p.textMuted),
            ],
          ),
        ),
      );
    }

    return PageFrame(
      header: PageHeader(
        eyebrow:
            'YOUR ROLES${campus == null ? '' : ' · ${campusName(campus).toUpperCase()}'}',
        title: 'Work as',
      ),
      children: [
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              option(null),
              for (final g in r.grants) ...[const CardDivider(), option(g)],
            ],
          ),
        ),
        const SizedBox(height: Space.sm),
        // Mint wash: reassurance, not a warning.
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: p.hero.withValues(alpha: p.isDark ? 0.18 : 0.4),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.verified_user_outlined,
                  size: 15,
                  color: p.text,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'This is really you. Whatever you change is saved under your '
                  'name and logged. Pointer keeps opening in the role you '
                  'pick, with a strip at the top to switch back.',
                  style: TypeScale.caption.copyWith(
                    fontSize: 11.5,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                    color: p.text,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.sm),
        AppCard(
          padding: EdgeInsets.zero,
          child: CardRow(
            leading: Icon(Icons.contact_phone_outlined, color: p.icon),
            title: 'Your contact details',
            titleLines: 2,
            subtitle:
                myContactSummary.value ?? 'Name, phone, what students see',
            onTap:
                () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const RepProfilePage(),
                  ),
                ),
          ),
        ),
        const Note(
          'Only roles you hold today are listed. One that lapses disappears, '
          'and Pointer goes back to Student.',
        ),
      ],
    );
  }
}

/// The strip at the top while working as a role, or viewing as one (Open
/// as): names it, with a way back.
class RoleStrip extends StatelessWidget {
  const RoleStrip({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: viewAs,
    builder:
        (context, view, _) => ValueListenableBuilder(
          valueListenable: workingAs,
          builder: (context, working, _) {
            final text =
                view != null
                    ? 'Viewing as ${view.label}'
                    : working != null
                    ? 'Working as ${roleLabel(working)}'
                    : null;
            if (text == null) return child;
            final p = AppPalette.of(context);
            return Column(
              children: [
                Material(
                  color: p.inverse,
                  child: SafeArea(
                    bottom: false,
                    child: SizedBox(
                      height: 40,
                      child: Row(
                        children: [
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TypeScale.caption.copyWith(
                                fontWeight: FontWeight.w700,
                                color: p.onInverse,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              if (view != null) {
                                viewAs.value = null;
                              } else {
                                setWorkingAs(null);
                              }
                              stripNavigate?.call(
                                view != null ? Routes.openAs : Routes.home,
                              );
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: p.accent,
                              minimumSize: const Size(0, 40),
                            ),
                            child: Text(
                              view != null ? 'Back to Owner' : 'Student',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    child: child,
                  ),
                ),
              ],
            );
          },
        ),
  );
}

/// Set by the app to its router's `go`, since the strip sits above the
/// navigator.
void Function(String location)? stripNavigate;
