import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/core/resources/resource.dart';
import 'package:cgpa_calculator/core/storage/cache_boxes.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';

/// Bookmarked links (owner, 2026-10-06): kept on this device like starred
/// courses, a copy of each so the Bookmarked page needs no read.
final bookmarks = ValueNotifier<Map<String, Resource>>(_read());

const _key = 'pref.bookmarks';

Box? get _box => Hive.isBoxOpen(deviceBoxName) ? Hive.box(deviceBoxName) : null;

Map<String, Resource> _read() {
  try {
    return {
      for (final e in ((_box?.get(_key) as Map?) ?? const {}).entries)
        '${e.key}': Resource.fromMap(e.value as Map, '${e.key}'),
    };
  } on Object {
    return {};
  }
}

/// Bookmarks [r], or removes it. The disk write is not awaited (UI path).
void toggleBookmark(Resource r) {
  final m = {...bookmarks.value};
  if (m.remove(r.id) == null) m[r.id] = r;
  bookmarks.value = m;
  _box?.put(_key, {for (final e in m.entries) e.key: e.value.toMap()});
}

/// The bookmark button on a link row.
class BookmarkButton extends StatelessWidget {
  const BookmarkButton(this.r, {super.key});
  final Resource r;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: bookmarks,
    builder: (context, m, _) {
      final on = m.containsKey(r.id);
      final p = AppPalette.of(context);
      return SizedBox.square(
        dimension: 44,
        child: IconButton(
          tooltip: on ? 'Remove bookmark' : 'Bookmark',
          icon: Icon(
            on ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            size: 19,
            color: on ? p.text : p.textMuted,
          ),
          onPressed: () => toggleBookmark(r),
        ),
      );
    },
  );
}
