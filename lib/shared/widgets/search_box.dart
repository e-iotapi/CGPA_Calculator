import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:flutter/material.dart';

/// A search field, 46 tall, radius 23 (§3.20).
class SearchBox extends StatelessWidget {
  const SearchBox({
    super.key,
    required this.controller,
    required this.hint,
    this.trailing,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final Widget? trailing;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    // Its own semantics node: results drawn under the box (the course
    // pickers) would otherwise regroup the field's semantics, and on the
    // web that swaps in a fresh, empty input, wiping what was typed.
    return Semantics(
      container: true,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(23),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 16, color: p.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                style: TypeScale.body.copyWith(fontSize: 13, color: p.text),
                cursorColor: p.text,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: hint,
                  hintStyle: TypeScale.body.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: p.textMuted,
                  ),
                ),
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}
