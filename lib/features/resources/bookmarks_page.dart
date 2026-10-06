import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/features/resources/bookmarks.dart';
import 'package:cgpa_calculator/features/resources/resources_page.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:flutter/material.dart';

/// Every link bookmarked on this device, newest first.
class BookmarksPage extends StatelessWidget {
  const BookmarksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return ValueListenableBuilder(
      valueListenable: bookmarks,
      builder: (context, m, _) {
        final saved = m.values.toList().reversed.toList();
        return PageFrame(
          header: const PageHeader(eyebrow: 'RESOURCES', title: 'Bookmarked'),
          children: [
            if (saved.isEmpty)
              const Note(
                'Tap the bookmark on any link, in a course, a degree or a '
                'search, to keep it here.',
              )
            else
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final (i, r) in saved.indexed) ...[
                      if (i > 0)
                        Divider(height: 1, indent: 15, color: p.divider),
                      LinkRow(
                        r: r,
                        tag:
                            r.courseIds.isEmpty
                                ? r.department
                                : r.courseIds.first,
                      ),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
