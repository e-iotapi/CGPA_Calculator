/// Who may do what: a literal copy of the role table in ARCHITECTURE.md §4
/// (§16.3 fix 2). Screens ask [can] and never inline a role check; the rules
/// tests walk the same table, and test/core/capabilities_test.dart fails when
/// this copy and the document disagree.
library;

/// A rung of the role table, strongest first.
enum Role { owner, admin, president, cr, student }

/// One row of the table. The cells are the document's text, verbatim.
enum Capability {
  addRemoveOwners('Add / remove owners', '✓ (never themselves)', '—', '—', '—'),
  appointAdmins('Appoint / revoke admins', '✓', '—', '—', '—'),
  appointPresidents('Appoint / revoke presidents', '✓', '✓', '—', '—'),
  appointCrs('Appoint / revoke CRs', '✓', '✓', '✓ in scope', '—'),
  publish('Publishing, analytics', '✓', '—', '—', '—'),
  publicContact('Public contact (`config/public`)', '✓', '✓', '—', '—'),
  grantTermsCrPresident(
    'Grant terms — CR and president lengths',
    '✓',
    '✓',
    '—',
    '—',
  ),
  grantTermsAdmin('Grant terms — admin length', '✓', '—', '—', '—'),
  mergeProfessors('Merge duplicate professors', '✓', '✓', '✓ in scope', '—'),
  courseStructures(
    'Course structures, eval schemes',
    '✓',
    '—',
    '✓',
    '✓ own courses',
  ),
  bulkUpload('Bulk upload a JSON of eval schemes', '✓', '—', '✓', '—'),
  degreeRequirements('Degree requirements', '✓', '—', '✓', '—'),
  departmentResources('Department resources', '✓', '—', '✓', '—'),
  courseResources('Course resources', '✓', '—', '✓', '✓ own courses'),
  averages(
    'Averages — course, component, part',
    '✓',
    '—',
    '✓',
    '✓ own courses',
  ),
  professors('Professors — create, rename', '✓', '—', '✓', 'pick only'),
  moderateReviews('Moderate reviews', '✓', '—', '✓ in scope', '—'),
  readAuditAndRoster(
    'Read the audit log and the roster',
    '✓',
    '✓',
    '✓ own campus',
    '—',
  );

  const Capability(this.label, this.owner, this.admin, this.president, this.cr);

  /// The row's name in the table.
  final String label;

  /// The owner column's text.
  final String owner;

  /// The admin column's text.
  final String admin;

  /// The president column's text.
  final String president;

  /// The CR column's text.
  final String cr;

  /// The table text for [role] on this row.
  String cell(Role role) => switch (role) {
    Role.owner => owner,
    Role.admin => admin,
    Role.president => president,
    Role.cr => cr,
    Role.student => '—',
  };
}

/// Whether [role] may do [action].
///
/// [inScope]: the target lies inside the actor's grant — their department on
/// their campus for a president, their course for a CR. Presidents and CRs
/// only ever act in scope (§4, "Scope"), so every one of their ticks needs
/// it. [targetIsSelf]: the action is aimed at the actor's own account.
/// "pick only" (a CR choosing a professor) is not create or rename.
bool can(
  Role role,
  Capability action, {
  bool inScope = true,
  bool targetIsSelf = false,
}) {
  final cell = action.cell(role);
  if (!cell.startsWith('✓')) return false;
  if (cell.contains('never themselves') && targetIsSelf) return false;
  if (role == Role.president || role == Role.cr) return inScope;
  return true;
}
