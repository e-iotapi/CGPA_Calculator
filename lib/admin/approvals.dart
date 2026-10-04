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
import 'package:cgpa_calculator/features/contribute/contribute_widgets.dart' show SheetButton;
import 'package:cgpa_calculator/features/resources/resources_page.dart'
    show resourceStore;
import 'package:cgpa_calculator/features/setup/campus_pick_page.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/notice.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:cgpa_calculator/shared/widgets/segmented.dart';
import 'package:flutter/material.dart';

typedef _Data = ({
  List<ContributorRequest> requests,
  List<PendingBatch> batches,
  List<Grant> contributors,
});

/// Presets on the Reason sheet when links are rejected.
const reasonPresets = ['Needs access', 'Wrong course', 'Not useful', 'Other'];

/// Presets when an application is declined.
const declinePresets = [
  'Not a good fit',
  'Broken or private link',
  'Wrong department or course',
  'Duplicate of an existing link',
];

/// Asks why: a preset or a note, then Send. Null when dismissed.
Future<String?> askReason(
  BuildContext context, {
  required String title,
  String? subtitle,
  List<String> presets = reasonPresets,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  builder: (_) => ReasonSheet(title: title, subtitle: subtitle, presets: presets),
);

class ReasonSheet extends StatefulWidget {
  const ReasonSheet({
    super.key,
    required this.title,
    this.subtitle,
    this.presets = reasonPresets,
  });
  final String title;
  final String? subtitle;
  final List<String> presets;

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
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            10,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 30,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: p.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: TypeScale.title.copyWith(
                            fontSize: 21,
                            letterSpacing: -0.5,
                            color: p.text,
                          ),
                        ),
                        if (widget.subtitle != null)
                          Text(
                            widget.subtitle!,
                            style: TypeScale.caption.copyWith(
                              fontSize: 11.5,
                              color: p.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Material(
                    color: p.chipFill,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.pop(context),
                      child: SizedBox.square(
                        dimension: 44,
                        child: Icon(Icons.close_rounded, size: 20, color: p.text),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Cap('REASON · THEY SEE THIS'),
              const SizedBox(height: 10),
              ChoicePills<String>(
                small: true,
                values: widget.presets,
                selected: _preset,
                label: (s) => s,
                onSelected:
                    (s) => setState(() {
                      _preset = _preset == s ? null : s;
                      _error = null;
                    }),
              ),
              const SizedBox(height: 12),
              _Cap('NOTE · THEY SEE IT'),
              const SizedBox(height: 5),
              AppTextField(
                controller: _note,
                label: 'Say what to fix',
                fill: p.surface,
                error: _error,
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: 28),
              Row(
                spacing: 10,
                children: [
                  Expanded(
                    child: SheetButton('Cancel', onTap: () => Navigator.pop(context)),
                  ),
                  Expanded(
                    child: SheetButton(
                      'Send',
                      onTap: _send,
                      fill: p.rejectedTone.text,
                      fg: p.background,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cap extends StatelessWidget {
  const _Cap(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TypeScale.label.copyWith(
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
      color: AppPalette.of(context).textMuted,
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
    final why = await askReason(
      context,
      title: 'Decline ${r.name.isEmpty ? r.email : r.name}',
      subtitle: r.email,
      presets: declinePresets,
    );
    if (why == null || !mounted) return;
    await _run(1, () => _contrib.decline(r, reason: why), 'Declined');
  }

  Future<void> _reject(PendingBatch b) async {
    final n = b.links.length;
    final why = await askReason(
      context,
      title: 'Reject $n ${n == 1 ? 'link' : 'links'}',
      subtitle: '${b.username.isEmpty ? b.email : b.username} · ${b.dept}',
    );
    if (why == null || !mounted) return;
    await _run(
      b.links.length,
      () => _rejectBatch(b, why),
      b.links.length == 1 ? 'Link rejected' : 'Links rejected',
    );
  }

  Future<void> _revoke(Grant g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _RevokeDialog(g.name.isEmpty ? g.email : g.name),
    );
    if (ok != true || !mounted) return;
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
            SegmentedTrack<bool>(
              height: 44,
              tabs: [
                (false, 'Applications · ${d.requests.length}'),
                (true, 'Links · ${d.batches.length}'),
              ],
              value: _links,
              onChanged: (v) => setState(() => _links = v),
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
              _ApproveAll(
                off: off,
                onTap:
                    () =>
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
                const Note(
                  'Approvers are not named; everyone else sees usernames only.',
                ),
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

class _ApproveAll extends StatelessWidget {
  const _ApproveAll({required this.off, required this.onTap});
  final bool off;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Opacity(
      opacity: off ? .5 : 1,
      child: Material(
        color: p.hero,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: off ? null : onTap,
          child: SizedBox(
            height: 46,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_rounded, size: 18, color: p.onHero),
                const SizedBox(width: 6),
                Text(
                  'Approve all',
                  style: TypeScale.body.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: p.onHero,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A board card (radius 20, 12 / 14 padding) holding its content.
class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: AppCard(
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: children,
      ),
    ),
  );
}

/// The name, a muted line under it, and an optional tag at the right.
class _Head extends StatelessWidget {
  const _Head(this.title, this.sub, {this.tag, this.tone});
  final String title, sub;
  final String? tag;
  final GradeTone? tone;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Row(
      spacing: 8,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TypeScale.body.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: p.text,
                ),
              ),
              Text(
                sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TypeScale.caption.copyWith(
                  fontSize: 10.5,
                  height: 1.45,
                  color: p.textMuted,
                ),
              ),
            ],
          ),
        ),
        if (tag != null)
          Container(
            height: 20,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: (tone ?? GradeTone(p.chipFill, p.icon)).fill,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              tag!,
              style: TypeScale.label.copyWith(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: (tone ?? GradeTone(p.chipFill, p.icon)).text,
              ),
            ),
          ),
      ],
    );
  }
}

/// Two equal 42-tall pills: the refusal outlined, the approval in ink.
class _Duo extends StatelessWidget {
  const _Duo({
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
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    Widget pill(String label, VoidCallback tap, bool ink) => Expanded(
      child: Opacity(
        opacity: off ? .5 : 1,
        child: Material(
          color: ink ? p.inverse : p.surface,
          shape: StadiumBorder(
            side: ink ? BorderSide.none : BorderSide(color: p.outline),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: off ? null : tap,
            child: SizedBox(
              height: 42,
              child: Center(
                child: Text(
                  label,
                  style: TypeScale.body.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: ink ? p.onInverse : p.text,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return Row(spacing: 8, children: [pill(no, onNo, false), pill(yes, onYes, true)]);
  }
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
  Widget build(BuildContext context) => _Card(
    children: [
      _Head(
        r.name.isEmpty ? r.email : r.name,
        '${r.email} · ${ago(DateTime.fromMillisecondsSinceEpoch(r.createdAt))}',
      ),
      _Duo(
        yes: 'Approve',
        no: 'Decline',
        onYes: onApprove,
        onNo: onDecline,
        off: off,
      ),
    ],
  );
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
    final n = b.links.length;
    final used = DateTime.now().millisecondsSinceEpoch - b.at;
    final left =
        ((contributorWindow.inMilliseconds - used) /
                Duration.millisecondsPerDay)
            .ceil()
            .clamp(0, 15);
    // ponytail: "urgent" is three days or fewer, a guess at the board's 2.
    final urgent = left <= 3;
    return _Card(
      children: [
        _Head(
          '${b.username.isEmpty ? b.email : b.username} · $n ${n == 1 ? 'link' : 'links'}',
          '${b.dept} Department · $left ${left == 1 ? 'day' : 'days'} left',
          tag: urgent ? 'URGENT' : 'WAITING',
          tone: urgent ? p.rejectedTone : p.waitingTone,
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final l in b.links)
              InkWell(
                onTap: () => openUrl(l.url),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 28),
                  child: Row(
                    spacing: 6,
                    children: [
                      Icon(Icons.link_rounded, size: 14, color: p.accent),
                      Expanded(
                        child: Text(
                          l.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TypeScale.body.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: p.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        _Duo(
          yes: 'Approve',
          no: 'Reject',
          onYes: onApprove,
          onNo: onReject,
          off: off,
        ),
      ],
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
    final at = g.grantedAt;
    return _Card(
      children: [
        Row(
          spacing: 8,
          children: [
            Expanded(
              child: _Head(
                g.name.isEmpty ? g.email : g.name,
                at == null ? g.email : 'approved ${shortDay(at)}',
              ),
            ),
            Opacity(
              opacity: off ? .5 : 1,
              child: Material(
                color: Colors.transparent,
                shape: StadiumBorder(side: BorderSide(color: p.outline)),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: off ? null : onRevoke,
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    child: Text(
                      'Revoke',
                      style: TypeScale.body.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: p.rejectedTone.text,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RevokeDialog extends StatelessWidget {
  const _RevokeDialog(this.name);
  final String name;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Dialog(
      backgroundColor: p.background,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: p.rejectedTone.fill,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.person_outline_rounded,
                  size: 20,
                  color: p.rejectedTone.text,
                ),
              ),
            ),
            Semantics(
              header: true,
              child: Text(
                'Revoke $name?',
                style: TypeScale.title.copyWith(
                  fontSize: 18,
                  letterSpacing: -0.3,
                  height: 1.25,
                  color: p.text,
                ),
              ),
            ),
            Text(
              'They can’t add or edit links any more. Links they published '
              'stay up, and their points stay. They can apply again.',
              style: TypeScale.caption.copyWith(
                fontSize: 12,
                height: 1.45,
                color: p.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            SheetButton(
              'Revoke',
              onTap: () => Navigator.pop(context, true),
              fill: p.rejectedTone.text,
              fg: p.background,
            ),
            SheetButton(
              'Keep contributor',
              onTap: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
  }
}
