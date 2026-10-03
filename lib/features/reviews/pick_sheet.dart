import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/shared/widgets/card_row.dart';
import 'package:cgpa_calculator/shared/widgets/search_box.dart';
import 'package:flutter/material.dart';

/// A bottom sheet of [options] (value, label), the [selected] one ticked, with
/// a search box when [searchHint] is set. Returns the choice in a record, so a
/// null value (such as "All professors") differs from dismissing the sheet.
Future<({T value})?> pickSheet<T>(
  BuildContext context, {
  required String title,
  required List<(T, String)> options,
  T? selected,
  String? searchHint,
}) => showModalBottomSheet<({T value})>(
  context: context,
  isScrollControlled: true,
  builder:
      (_) => _PickSheet<T>(
        title: title,
        options: options,
        selected: selected,
        searchHint: searchHint,
      ),
);

class _PickSheet<T> extends StatefulWidget {
  const _PickSheet({
    required this.title,
    required this.options,
    required this.selected,
    required this.searchHint,
  });
  final String title;
  final List<(T, String)> options;
  final T? selected;
  final String? searchHint;

  @override
  State<_PickSheet<T>> createState() => _PickSheetState<T>();
}

class _PickSheetState<T> extends State<_PickSheet<T>> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final q = _q.text.trim().toLowerCase();
    final rows = [
      for (final o in widget.options)
        if (q.isEmpty || o.$2.toLowerCase().contains(q)) o,
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
                  onChanged: (_) => setState(() {}),
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
