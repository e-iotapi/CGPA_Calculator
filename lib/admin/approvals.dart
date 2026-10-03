import 'package:cgpa_calculator/admin/volunteers.dart' show defaultDept;
import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/contrib/contributor_store.dart';
import 'package:cgpa_calculator/core/platform/browser.dart';
import 'package:cgpa_calculator/core/resources/resource.dart';
import 'package:cgpa_calculator/core/resources/resource_store.dart' show LinkExpired;
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/features/resources/resources_page.dart'
    show resourceStore;
import 'package:cgpa_calculator/features/setup/campus_pick_page.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/confirm_dialog.dart';
import 'package:cgpa_calculator/shared/widgets/notice.dart';
import 'package:cgpa_calculator/shared/widgets/outlined_pill.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:cgpa_calculator/shared/widgets/pill_button.dart';
import 'package:flutter/material.dart';

typedef _Data = ({
  List<ContributorRequest> requests,
  List<PendingBatch> batches,
  List<Grant> contributors,
});

/// Presets on the Reason sheet (decline and reject).
const reasonPresets = [
  'Not a good fit',
  'Broken or private link',
  'Wrong department or course',
  'Duplicate of an existing link',
];

/// Asks why: a preset or a note, then Send. Null when dismissed.
Future<String?> askReason(BuildContext context, {required String title}) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ReasonSheet(title: title),
    );

class ReasonSheet extends StatefulWidget {
  const ReasonSheet({super.key, required this.title});
  final String title;

  @override
  State<ReasonSheet> createState() => _ReasonSheetState();
}

class _ReasonSheetState extends State<ReasonSheet> {
  final _note = TextEditingController();
  String? _preset, _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _send() {
    final n = _note.text.trim();
    final text = [if (_preset != null) _preset!, if (n.isNotEmpty) n].join(': ');
    if (text.isEmpty) {
      return setState(() => _error = 'Pick a reason or write one.');
    }
    Navigator.of(context).pop(text.length > 200 ? text.substring(0, 200) : text);
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        Space.gutter,
        Space.lg,
        Space.gutter,
        MediaQuery.viewInsetsOf(context).bottom + Space.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: TypeScale.title),
          const SizedBox(height: Space.sm),
          ChoicePills<String>(
            values: reasonPresets,
            selected: _preset,
            label: (s) => s,
            onSelected:
                (s) => setState(() {
                  _preset = _preset == s ? null : s;
                  _error = null;
                }),
          ),
          const SizedBox(height: Space.sm),
          AppTextField(
            controller: _note,
            label: 'Note (optional)',
            error: _error,
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: Space.md),
          PrimaryButton(label: 'Send', onPressed: _send),
        ],
      ),
    ),
  );
}

/// Board `Approvals`: contributor applications and link requests for one
/// department. Presidents and secretaries open it for their own; an admin
/// picks a department.
class Approvals extends StatefulWidget {
  const Approvals({super.key, this.campus, this.dept});
  final String? campus, dept;

  @override
  State<Approvals> createState() => _ApprovalsState();
}

class _ApprovalsState extends State<Approvals> {
  late String? _dept = widget.dept ?? defaultDept(_campus ?? '');
  bool _links = false;
  int _loads = 0, _done = 0, _total = 0;
  bool _busy = false;
  String? _error;
  final _failed = <String>[];

  String? get _campus => widget.campus ?? viewCampus();

  ContributorStore get _contrib => ContributorStore(roleStore!);

  Future<_Data> _load(String campus, String dept) async {
    final reqs = await _contrib.requests(campus, dept);
    final batches = await resourceStore!.pending(campus, dept);
    final roster = await roleStore!.roster(campus: campus);
    return _data(reqs, batches, roster, dept);
  }

  _Data? _peek(String campus, String dept) {
    final r = _contrib.peekRequests(campus, dept);
    final b = resourceStore?.peekPending(campus, dept);
    final g = roleStore?.peekRoster(campus: campus);
    return r == null || b == null || g == null ? null : _data(r, b, g, dept);
  }

  _Data _data(
    List<ContributorRequest> r,
    List<PendingBatch> b,
    List<Grant> g,
    String dept,
  ) {
    final now = DateTime.now();
    return (
      requests: r,
      batches: b,
      contributors: [
        for (final x in g)
          if (x.role == GrantRole.contributor &&
              x.liveAt(now) &&
              x.dept == dept)
            x,
      ],
    );
  }

  void _say(String text) =>
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(text)));

  /// Runs [f] with the screen locked; a refusal is shown, then reloads.
  Future<void> _run(int total, Future<void> Function() f, String done) async {
    setState(() {
      _busy = true;
      _total = total;
      _done = 0;
      _error = null;
      _failed.clear();
    });
    try {
      await f();
      if (_failed.isNotEmpty) {
        if (mounted) setState(() => _error = 'Not approved: ${_failed.join('; ')}.');
      } else if (mounted) {
        _say(done);
      }
    } catch (e) {
      if (mounted) setState(() => _error = problem(e));
    }
    if (mounted) {
      setState(() {
        _busy = false;
        _loads++;
      });
    }
  }

  /// Approves every link of [b], one at a time so progress shows. A link
  /// that cannot be approved (past its 15 days, or refused) is noted in
  /// [_failed] and the rest go on.
  Future<void> _approveBatch(PendingBatch b) async {
    var queued = b.links;
    for (final l in b.links) {
      try {
        await resourceStore!.approve(_with(b, queued), linkIds: {l.id});
        queued = [for (final q in queued) if (q.id != l.id) q];
      } on LinkExpired {
        _failed.add('${l.title} (expired, reject it)');
      } catch (e) {
        debugPrint('$e');
        _failed.add(l.title);
      }
      if (mounted) setState(() => _done++);
    }
  }

  Future<void> _rejectBatch(PendingBatch b, String reason) async {
    var rest = b.links;
    while (rest.isNotEmpty) {
      await resourceStore!.reject(
        _with(b, rest),
        linkIds: {rest.first.id},
        reason: reason,
      );
      rest = rest.sublist(1);
      if (mounted) setState(() => _done++);
    }
  }

  PendingBatch _with(PendingBatch b, List<({String id, String title, String url})> links) =>
      PendingBatch(
        id: b.id,
        campus: b.campus,
        dept: b.dept,
        email: b.email,
        username: b.username,
        at: b.at,
        links: links,
      );

  Future<void> _decline(ContributorRequest r) async {
    final why = await askReason(context, title: 'Why decline ${r.name}?');
    if (why == null || !mounted) return;
    await _run(1, () => _contrib.decline(r, reason: why), 'Declined');
  }

  Future<void> _reject(PendingBatch b) async {
    final why = await askReason(context, title: 'Why reject these links?');
    if (why == null || !mounted) return;
    await _run(
      b.links.length,
      () => _rejectBatch(b, why),
      b.links.length == 1 ? 'Link rejected' : 'Links rejected',
    );
  }

  Future<void> _revoke(Grant g) async {
    final ok = await confirmDialog(
      context,
      title: 'Revoke ${g.name}?',
      body: 'They can no longer add links. Their points stay.',
      action: 'Revoke',
      cancel: 'Keep',
      danger: true,
    );
    if (!ok || !mounted) return;
    await _run(1, () => _contrib.revoke(g), 'Revoked');
  }

  @override
  Widget build(BuildContext context) {
    final campus = _campus;
    final dept = _dept;
    final header = PageHeader(
      eyebrow:
          campus == null
              ? 'Admin'
              : '${campusName(campus).toUpperCase()} · ${dept ?? ''}',
      title: 'Contributor approvals',
    );
    if (campus == null || dept == null) {
      return PageFrame(
        header: header,
        children: const [Note('Pick a campus and department first.')],
      );
    }
    return Loaded<_Data>(
      key: ValueKey('$dept|$_loads'),
      cacheKey: 'approvals|$campus|$dept',
      load: () => _load(campus, dept),
      peek: () => _peek(campus, dept),
      gated: (context, d, reload, saved) {
        final off = saved || _busy;
        final n = _links ? d.batches.length : d.requests.length;
        return PageFrame(
          header: header,
          children: [
            if (widget.dept == null) _DeptPicker(
              campus: campus,
              dept: dept,
              onChanged: (v) => setState(() => _dept = v),
            ),
            ChoicePills<bool>(
              equal: true,
              values: const [false, true],
              selected: _links,
              label: (l) => l ? 'Links' : 'Applications',
              count: (l) => '${l ? d.batches.length : d.requests.length}',
              onSelected: (v) => setState(() => _links = v),
            ),
            const SizedBox(height: Space.sm),
            if (_busy)
              Notice(
                text: TextSpan(
                  text: 'Working on $_done of $_total…',
                ),
              ),
            if (_error != null)
              Notice(warning: true, text: TextSpan(text: _error)),
            if (n > 0)
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedPill(
                  label: 'Approve all',
                  onPressed:
                      off
                          ? null
                          : () =>
                              _links
                                  ? _run(
                                    d.batches.fold(0, (a, b) => a + b.links.length),
                                    () async {
                                      for (final b in d.batches) {
                                        await _approveBatch(b);
                                      }
                                    },
                                    'Approved',
                                  )
                                  : _run(d.requests.length, () async {
                                    for (final r in d.requests) {
                                      await _contrib.approve(r);
                                      if (mounted) setState(() => _done++);
                                    }
                                  }, 'Approved'),
                ),
              ),
            if (_links) ...[
              if (d.batches.isEmpty) const Note('No links are waiting.'),
              for (final b in d.batches)
                _BatchCard(
                  b,
                  off: off,
                  onApprove:
                      () => _run(
                        b.links.length,
                        () => _approveBatch(b),
                        'Approved',
                      ),
                  onReject: () => _reject(b),
                ),
            ] else ...[
              if (d.requests.isEmpty) const Note('No applications are waiting.'),
              for (final r in d.requests)
                _RequestCard(
                  r,
                  off: off,
                  onApprove:
                      () => _run(1, () => _contrib.approve(r), 'Approved'),
                  onDecline: () => _decline(r),
                ),
              if (d.contributors.isNotEmpty) ...[
                const SectionLabel('Contributors'),
                for (final g in d.contributors)
                  _ContributorRow(g, off: off, onRevoke: () => _revoke(g)),
              ],
            ],
          ],
        );
      },
    );
  }
}

class _DeptPicker extends StatelessWidget {
  const _DeptPicker({
    required this.campus,
    required this.dept,
    required this.onChanged,
  });
  final String campus, dept;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.sm),
    child: DropdownButtonFormField<String>(
      initialValue: dept,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Department'),
      items: [
        for (final d in departmentsAt(campus))
          DropdownMenuItem(value: d, child: Text(departmentName(d))),
      ],
      onChanged: onChanged,
    ),
  );
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.yes,
    required this.no,
    required this.onYes,
    required this.onNo,
    required this.off,
  });
  final String yes, no;
  final VoidCallback onYes, onNo;
  final bool off;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      PillButton(
        label: yes,
        selected: true,
        height: Sizes.minTouch,
        onPressed: off ? null : onYes,
      ),
      const SizedBox(width: 8),
      PillButton(
        label: no,
        height: Sizes.minTouch,
        onPressed: off ? null : onNo,
      ),
    ],
  );
}

class _RequestCard extends StatelessWidget {
  const _RequestCard(
    this.r, {
    required this.off,
    required this.onApprove,
    required this.onDecline,
  });
  final ContributorRequest r;
  final bool off;
  final VoidCallback onApprove, onDecline;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              r.name.isEmpty ? r.email : r.name,
              style: TypeScale.body.copyWith(
                fontWeight: FontWeight.w700,
                color: p.text,
              ),
            ),
            Text(
              '${r.email} · ${ago(DateTime.fromMillisecondsSinceEpoch(r.createdAt))}',
              style: TypeScale.caption.copyWith(color: p.textMuted),
            ),
            const SizedBox(height: Space.sm),
            _Actions(
              yes: 'Approve',
              no: 'Decline',
              onYes: onApprove,
              onNo: onDecline,
              off: off,
            ),
          ],
        ),
      ),
    );
  }
}

class _BatchCard extends StatelessWidget {
  const _BatchCard(
    this.b, {
    required this.off,
    required this.onApprove,
    required this.onReject,
  });
  final PendingBatch b;
  final bool off;
  final VoidCallback onApprove, onReject;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              b.username.isEmpty ? b.email : b.username,
              style: TypeScale.body.copyWith(
                fontWeight: FontWeight.w700,
                color: p.text,
              ),
            ),
            Text(
              '${b.links.length} ${b.links.length == 1 ? 'link' : 'links'} · '
              '${ago(DateTime.fromMillisecondsSinceEpoch(b.at))}',
              style: TypeScale.caption.copyWith(color: p.textMuted),
            ),
            for (final l in b.links)
              InkWell(
                onTap: () => openUrl(l.url),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: Sizes.minTouch),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TypeScale.body.copyWith(
                        fontSize: 12.5,
                        decoration: TextDecoration.underline,
                        color: p.text,
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: Space.xs),
            _Actions(
              yes: 'Approve',
              no: 'Reject',
              onYes: onApprove,
              onNo: onReject,
              off: off,
            ),
          ],
        ),
      ),
    );
  }
}

class _ContributorRow extends StatelessWidget {
  const _ContributorRow(this.g, {required this.off, required this.onRevoke});
  final Grant g;
  final bool off;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: AppCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    g.name.isEmpty ? g.email : g.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TypeScale.body.copyWith(
                      fontWeight: FontWeight.w700,
                      color: p.text,
                    ),
                  ),
                  Text(
                    g.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TypeScale.caption.copyWith(color: p.textMuted),
                  ),
                ],
              ),
            ),
            PillButton(
              label: 'Revoke',
              height: Sizes.minTouch,
              onPressed: off ? null : onRevoke,
            ),
          ],
        ),
      ),
    );
  }
}
