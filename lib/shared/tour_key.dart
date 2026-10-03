import 'package:flutter/widgets.dart';

final _keys = <String, GlobalKey>{};

/// The one [GlobalKey] the guided tour uses for control [id]. Put it on a
/// single widget at a time (`KeyedSubtree(key: tourKey('x'), child: ...)`);
/// a control that exists once per Home profile passes that [profile], so the
/// outgoing and incoming pages of a profile switch never share a key.
GlobalKey tourKey(String id, [int? profile]) => _keys.putIfAbsent(
  profile == null ? id : '$id|$profile',
  () => GlobalKey(debugLabel: 'tour:$id'),
);

/// Where [key]'s widget is on screen, or null when it is not mounted, not
/// laid out, or has no area (a slot that is currently empty).
Rect? tourRect(GlobalKey key) {
  final box = key.currentContext?.findRenderObject();
  if (box is! RenderBox || !box.attached || !box.hasSize || box.size.isEmpty) {
    return null;
  }
  return box.localToGlobal(Offset.zero) & box.size;
}
