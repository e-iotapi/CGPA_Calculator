import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Paths of the screens that exist today (ARCHITECTURE.md §16.1), relative
/// to the `/calculator/` base href.
abstract final class Routes {
  static const home = '/';
  static const stats = '/stats';
  static const calendar = '/calendar';
  static const settings = '/settings';
  static const resources = '/resources';
  static const reviews = '/reviews';
  static const more = '/more';
  static const representatives = '/representatives';
  static String courseReviews(String id, {String? professor}) =>
      '/reviews/${Uri.encodeComponent(id)}'
      '${professor == null ? '' : '?professor=${Uri.encodeQueryComponent(professor)}'}';
  static String professorReviews(String id) =>
      '/reviews/professor/${Uri.encodeComponent(id)}';
  static String course(String id) => '/course/${Uri.encodeComponent(id)}';
  static const roles = '/roles';
  static const welcome = '/welcome';
  static const ownerSetup = '/setup/owner';

  // Owners and admins; roster, audit and professor merge also presidents.
  static const admin = '/admin';
  static const adminPeople = '/admin/people';
  static const adminGrant = '/admin/grant';
  static const adminOwners = '/admin/owners';
  static const adminTerms = '/admin/terms';
  static const adminContact = '/admin/contact';
  static const adminAudit = '/admin/audit';
  static const adminRoster = '/admin/roster';
  static const adminVolunteers = '/admin/roster/volunteers';
  static const adminPublish = '/admin/publish';
  static const adminMerge = '/admin/professors/merge';
  static const openAs = '/admin/open-as';

  // Presidents and CRs: the scope is in the path (§16.1).
  static String dept(String campus, String dept) => '/maintain/$campus/$dept';
  static String deptCourses(String campus, String dept) =>
      '/maintain/$campus/$dept/courses';
  static String deptProfessors(String campus, String dept) =>
      '/maintain/$campus/$dept/professors';
  static String deptResources(String campus, String dept) =>
      '/maintain/$campus/$dept/resources';
  static String deptReviews(String campus, String dept) =>
      '/maintain/$campus/$dept/reviews';
  static String deptSuccession(String campus, String dept) =>
      '/maintain/$campus/$dept/succession';
  static String deptSuccessionConfirm(String campus, String dept, String to) =>
      '/maintain/$campus/$dept/succession/confirm?to=${Uri.encodeQueryComponent(to)}';
  static String crCourse(String campus, String courseId) =>
      '/maintain/$campus/course/${Uri.encodeComponent(courseId)}';
}

/// Opens [location] above the current screen and completes when it closes.
/// Without a router above (widget tests pump screens bare) it pushes [page].
Future<void> openRoute(
  BuildContext context,
  String location,
  Widget Function() page, {
  Object? extra,
}) async {
  if (GoRouter.maybeOf(context) != null) {
    await context.push(location, extra: extra);
    return;
  }
  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page()));
}
