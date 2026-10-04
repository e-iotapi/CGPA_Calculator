import 'dart:async';

import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/shared/widgets/card_row.dart';
import 'package:cgpa_calculator/shared/widgets/search_box.dart';
import 'package:flutter/material.dart';

/// A bottom sheet of [options] (value, label), the [selected] one ticked, with
/// a search box when [searchHint] is set. Returns the choice in a record, so a
/// null value (such as "All professors") differs from dismissing the sheet.
/// [more], with a search box, adds matches from beyond [options] as the
/// person types (two letters or more).
Future<({T value})?> pickSheet<T>(
  BuildContext context, {
  required String title,
  required List<(T, String)> options,
  T? selected,
  String? searchHint,
  Future<List<(T, String)>> Function(String query)? more,
}) => showModalBottomSheet<({T value})>(
  context: context,
  isScrollControlled: true,
  builder:
      (_) => _PickSheet<T>(
        title: title,
        options: options,
        selected: selected,
        searchHint: searchHint,
        more: more,
      ),
);

class _PickSheet<T> extends StatefulWidget {
  const _PickSheet({
    required this.title,
    required this.options,
    required this.selected,
    required this.searchHint,
    this.more,
  });
  final String title;
  final List<(T, String)> options;
  final T? selected;
  final String? searchHint;
  final Future<List<(T, String)>> Function(String query)? more;

  @override
  State<_PickSheet<T>> createState() => _PickSheetState<T>();
}

class _PickSheetState<T> extends State<_PickSheet<T>> {
  final _q = TextEditingController();
  var _more = <(T, String)>[];
  Timer? _wait;

  @override
  void dispose() {
    _wait?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _changed(String _) {
    setState(() {});
    final more = widget.more;
    if (more == null) return;
    _wait?.cancel();
    final q = _q.text.trim();
    if (q.length < 2) {
      setState(() => _more = []);
      return;
    }
    _wait = Timer(const Duration(milliseconds: 300), () async {
      try {
        final found = await more(q);
        if (mounted && _q.text.trim() == q) setState(() => _more = found);
      } catch (_) {
        // Offline: the listed options still filter.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final q = _q.text.trim().toLowerCase();
    final listed = [
      for (final o in widget.options)
        if (q.isEmpty || o.$2.toLowerCase().contains(q)) o,
    ];
    final values = {for (final o in widget.options) o.$1};
    final rows = [
      ...listed,
      for (final o in _more)
        if (!values.contains(o.$1)) o,
    ];
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          10,
          16,
          Space.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              const SizedBox(height: Space.sm),
              Semantics(
                header: true,
                child: Text(
                  widget.title,
                  style: TypeScale.title.copyWith(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (widget.searchHint != null) ...[
                const SizedBox(height: Space.sm),
                SearchBox(
                  controller: _q,
                  hint: widget.searchHint!,
                  onChanged: _changed,
                ),
              ],
              const SizedBox(height: Space.sm),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: rows.length,
                  itemBuilder:
                      (context, i) => CardRow(
                        title: rows[i].$2,
                        titleLines: 2,
                        trailing:
                            rows[i].$1 == widget.selected
                                ? Icon(Icons.check_rounded, color: p.text)
                                : null,
                        onTap:
                            () =>
                                Navigator.of(context).pop((value: rows[i].$1)),
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
