// Code checks for a rendered screen: each problem comes back as one line of
// text, so an agent reads a report instead of a screenshot. Lines hold no
// node ids or timings, so the same screen gives the same lines on every run
// and ui_check.py can diff them against the accepted baseline.
//
// Kinds (the first word of every line):
//   contrast    text below WCAG AA against the colour painted behind it
//               (disabled controls are exempt, as in WCAG)
//   tap         a tappable target smaller than 44 × 44
//   unlabeled   a tappable target with no label or tooltip
//   dead        announced as an enabled button, but has no tap action
//   truncated   text cut short by maxLines / an ellipsis
//   word-break  a word wrapped mid-word ("Rem" / "ove")
//   off-edge    text painted past the right edge of the screen
//   overlap     two visible texts drawn over each other
//   stretch     a pill or badge that should hug its label fills the width
//   anim        frames still being scheduled after the screen settled
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/shared/widgets/code_badge.dart';
import 'package:cgpa_calculator/shared/widgets/count_badge.dart';
import 'package:cgpa_calculator/shared/widgets/count_pill.dart';
import 'package:cgpa_calculator/shared/widgets/grade_chip.dart';
import 'package:cgpa_calculator/shared/widgets/outlined_pill.dart';
import 'package:cgpa_calculator/shared/widgets/pill_button.dart';
import 'package:cgpa_calculator/shared/widgets/retired_tag.dart';
import 'package:cgpa_calculator/shared/widgets/tag_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Widgets that size to their label; one wider than [_stretchShare] of the
/// screen has been stretched by its parent.
const hugging = <Type>[
  CountPill,
  TagBadge,
  CodeBadge,
  CountBadge,
  GradeChip,
  RetiredTag,
  TierTag,
  ScopeChip,
  OutlinedPill,
  PillButton,
];

const _stretchShare = 0.8;

/// Writes `<dir>/<stem>.png` (the first RepaintBoundary) and `<dir>/<stem>.json`
/// holding this frame's layout [errors] and its [uiIssues].
Future<void> recordRender(
  WidgetTester t,
  String dir,
  String stem,
  List<String> errors,
) async {
  await t.runAsync(() async {
    final img = await captureImage(
      t.element(find.byType(RepaintBoundary).first),
    );
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/$stem.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
  final issues = await uiIssues(t);
  File('$dir/$stem.json').writeAsStringSync(
    const JsonEncoder.withIndent(
      ' ',
    ).convert({'errors': errors, 'issues': issues}),
  );
}

/// Every problem on the screen now showing, one line each, sorted.
/// Call after the screen has settled and before the next pumpWidget.
Future<List<String>> uiIssues(WidgetTester t) async {
  final out = <String>{};
  // First, before semantics asks for a frame of its own.
  if (t.binding.hasScheduledFrame) {
    out.add('anim: frames still scheduled after settling');
  }
  final screen = t.view.physicalSize / t.view.devicePixelRatio;

  final texts = <RenderParagraph>[];
  _order = 0;
  _covers.clear();
  _textOrder.clear();
  final faint = <(String, String)>[];
  for (final view in t.binding.renderViews) {
    _walkRender(view, screen, false, out, texts);
    final shot = await _shoot(t, view);
    if (shot != null) {
      for (final p in texts) {
        final line = _contrast(p, shot);
        if (line != null) faint.add((_clip(p.text.toPlainText()), line));
      }
    }
    _overlaps(texts, out);
    texts.clear();
  }

  for (final type in hugging) {
    for (final e in find.byType(type, skipOffstage: true).evaluate()) {
      final box = e.renderObject;
      if (box is! RenderBox || !box.hasSize) continue;
      final w = box.size.width;
      if (w > screen.width * _stretchShare) {
        out.add(
          'stretch: $type "${_textIn(e)}" ${w.round()} of '
          '${screen.width.round()} wide',
        );
      }
    }
  }

  final disabled = <String>[];
  final semantics = t.ensureSemantics();
  try {
    await t.pump();
    for (final view in t.binding.renderViews) {
      final root = view.owner?.semanticsOwner?.rootSemanticsNode;
      if (root != null) _walkSemantics(root, out, disabled);
    }
    // WCAG exempts disabled controls from contrast.
    for (final (text, line) in faint) {
      if (!disabled.any((d) => d.contains(text))) out.add(line);
    }
    for (final (kind, guideline) in [
      ('tap', iOSTapTargetGuideline),
      ('unlabeled', labeledTapTargetGuideline),
    ]) {
      final r = await guideline.evaluate(t);
      if (!r.passed) out.addAll(_lines(kind, r.reason ?? ''));
    }
  } finally {
    semantics.dispose();
  }
  return out.toList()..sort();
}

void _walkRender(
  RenderObject o,
  Size screen,
  bool sideways,
  Set<String> out,
  List<RenderParagraph> texts, [
  Rect? seen,
]) {
  seen ??= Offset.zero & screen;
  if (o is RenderOffstage && o.offstage) return;
  // Laid out but not shown: a closed dropdown's other items, a faded hint.
  if (o is RenderOpacity && o.opacity == 0) return;
  if (o is RenderAnimatedOpacity && o.opacity.value == 0) return;
  _order++;
  if (o is RenderBox && o.hasSize && o.attached && _opaque(o)) {
    _covers.add((
      _order,
      MatrixUtils.transformRect(o.getTransformTo(null), Offset.zero & o.size),
    ));
  }
  // A chip or tag (rounded, at most 30 tall) spanning the screen around a
  // short label has been stretched by its parent, whatever widget made it.
  if (o is RenderDecoratedBox &&
      o.hasSize &&
      o.size.height <= 30 &&
      o.size.width > screen.width * _stretchShare &&
      o.decoration is BoxDecoration &&
      (o.decoration as BoxDecoration).borderRadius != null) {
    final inner = <RenderParagraph>[];
    void find(RenderObject c) {
      if (c is RenderParagraph) inner.add(c);
      c.visitChildren(find);
    }

    o.visitChildren(find);
    if (inner.length == 1 &&
        inner.first.hasSize &&
        inner.first.size.width < o.size.width * 0.4) {
      out.add(
        'stretch: chip "${_clip(inner.first.text.toPlainText())}" '
        '${o.size.width.round()} of ${screen.width.round()} wide',
      );
    }
  }
  if (o is RenderIndexedStack) {
    var k = 0;
    final shown = o.index;
    o.visitChildren((c) {
      if (k++ == shown) _walkRender(c, screen, sideways, out, texts, seen);
    });
    return;
  }
  if (o is RenderViewportBase && o.hasSize && o.attached) {
    // A scroll view shows only its own box; rows past it are laid out
    // ahead of scrolling but nobody sees them.
    seen = seen.intersect(
      MatrixUtils.transformRect(o.getTransformTo(null), Offset.zero & o.size),
    );
    if (axisDirectionToAxis(o.axisDirection) == Axis.horizontal) {
      sideways = true;
    }
  }
  if (o is RenderParagraph && o.hasSize && o.attached) {
    final box = MatrixUtils.transformRect(
      o.getTransformTo(null),
      Offset.zero & o.size,
    );
    final text = _clip(o.text.toPlainText());
    if (text.isNotEmpty && box.overlaps(seen)) {
      texts.add(o);
      _textOrder[o] = _order;
      if (o.didExceedMaxLines) out.add('truncated: "$text"');
      if (_brokenWord(o) case final w?) {
        out.add('word-break: "$w" split across lines in "$text"');
      }
      if (!sideways && box.right > screen.width + 0.5) {
        out.add('off-edge: "$text" ends at ${box.right.round()}');
      }
    }
  }
  o.visitChildren((c) => _walkRender(c, screen, sideways, out, texts, seen));
}

// Paint order of the current walk: a box painted after a text, over it, and
// opaque, hides it.
var _order = 0;
final _covers = <(int, Rect)>[];
final _textOrder = <RenderParagraph, int>{};

bool _opaque(RenderBox o) {
  Color? c;
  if (o is RenderDecoratedBox && o.decoration is BoxDecoration) {
    c = (o.decoration as BoxDecoration).color;
  } else if (o is RenderPhysicalShape) {
    c = o.color;
  } else if (o is RenderPhysicalModel) {
    c = o.color;
  } else if (o.runtimeType.toString() == '_RenderColoredBox') {
    // ColoredBox's render object is private; its color getter is public.
    c = (o as dynamic).color as Color;
  }
  return c != null && c.a > 0.99;
}

bool _hidden(RenderParagraph p, Offset at) {
  final mine = _textOrder[p] ?? 0;
  return _covers.any((c) => c.$1 > mine && c.$2.contains(at));
}

/// Two pieces of visible text drawn over each other (a bar without a
/// background over scrolled text, a label run into another).
void _overlaps(List<RenderParagraph> texts, Set<String> out) {
  final boxes = [
    for (final p in texts)
      if (p.attached)
        (
          p,
          MatrixUtils.transformRect(
            p.getTransformTo(null),
            Offset.zero & p.size,
          ).deflate(1),
        ),
  ];
  for (var i = 0; i < boxes.length; i++) {
    for (var j = i + 1; j < boxes.length; j++) {
      final (a, ra) = boxes[i];
      final (b, rb) = boxes[j];
      final hit = ra.intersect(rb);
      if (hit.width <= 2 || hit.height <= 2) continue;
      final small = min(ra.width * ra.height, rb.width * rb.height);
      if (hit.width * hit.height < small * 0.2) continue;
      if (_hidden(a, hit.center) || _hidden(b, hit.center)) continue;
      out.add(
        'overlap: "${_clip(a.text.toPlainText())}" over '
        '"${_clip(b.text.toPlainText())}"',
      );
    }
  }
}

/// The first word [p] wraps in the middle of ("Rem" / "ove"), if any.
String? _brokenWord(RenderParagraph p) {
  final plain = p.text.toPlainText();
  for (final m in RegExp(r'[A-Za-z]{2,}').allMatches(plain)) {
    final boxes = p.getBoxesForSelection(
      TextSelection(baseOffset: m.start, extentOffset: m.end),
    );
    if (boxes.map((b) => b.top.round()).toSet().length > 1) return m[0];
  }
  return null;
}

/// The view as RGBA at logical pixels, so global offsets index it.
typedef _Shot = ({ByteData rgba, int width, int height});

Future<_Shot?> _shoot(WidgetTester t, RenderView view) async {
  final layer = view.debugLayer;
  if (layer is! OffsetLayer) return null;
  return t.binding.runAsync(() async {
    final ratio = 1 / view.flutterView.devicePixelRatio;
    final img = await layer.toImage(view.paintBounds, pixelRatio: ratio);
    final rgba = await img.toByteData();
    final shot = (rgba: rgba!, width: img.width, height: img.height);
    img.dispose();
    return shot;
  });
}

/// WCAG AA for [p]: its own colour against the commonest colour in a
/// 2 px ring just outside its box, where no glyph is drawn. Flutter's
/// textContrastGuideline guesses both colours from the pixels inside the
/// box and misreads text boxed tightly (a lone "T", an ellipsized label);
/// the canaries hold this one to catching faint text without that false
/// alarm.
String? _contrast(RenderParagraph p, _Shot shot) {
  final style = p.text.style;
  final fg = style?.color;
  final text = _clip(p.text.toPlainText());
  if (fg == null || fg.a < 0.1 || text.isEmpty || !p.attached) return null;
  final screen =
      Offset.zero & Size(shot.width.toDouble(), shot.height.toDouble());
  final box = MatrixUtils.transformRect(
    p.getTransformTo(null),
    Offset.zero & p.size,
  );
  final inner = box.intersect(screen);
  final outer = box.inflate(2).intersect(screen);
  if (inner.width < 2 || inner.height < 2) return null;
  final counts = <int, List<int>>{};
  for (var y = outer.top.floor(); y < outer.bottom.ceil(); y++) {
    for (var x = outer.left.floor(); x < outer.right.ceil(); x++) {
      if (inner.contains(Offset(x + 0.5, y + 0.5))) continue;
      final i = (y * shot.width + x) * 4;
      final r = shot.rgba.getUint8(i);
      final g = shot.rgba.getUint8(i + 1);
      final b = shot.rgba.getUint8(i + 2);
      final sum = counts.putIfAbsent(r << 16 | g << 8 | b, () => [0]);
      sum[0]++;
    }
  }
  if (counts.isEmpty) return null;
  final top = counts.entries.reduce((a, b) => a.value[0] >= b.value[0] ? a : b);
  final bg = Color(0xFF000000 | top.key);
  final ratio = _ratio(Color.alphaBlend(fg, bg), bg);
  final size = p.textScaler.scale(style?.fontSize ?? 14);
  final bold = (style?.fontWeight?.value ?? 400) >= 700;
  final needs = size >= 18 || (size >= 14 && bold) ? 3.0 : 4.5;
  if (ratio >= needs - 0.05) return null;
  return 'contrast: "$text" ${ratio.toStringAsFixed(2)}:1, needs $needs '
      '(${size.toStringAsFixed(1)} px)';
}

double _ratio(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

void _walkSemantics(SemanticsNode n, Set<String> out, List<String> disabled) {
  if (n.isInvisible || n.isMergedIntoParent) return;
  final d = n.getSemanticsData();
  final f = d.flagsCollection;
  if (f.isEnabled == ui.Tristate.isFalse) disabled.add(_clip(d.label));
  if (f.isButton &&
      !f.isHidden &&
      f.isEnabled != ui.Tristate.isFalse &&
      !d.hasAction(ui.SemanticsAction.tap)) {
    out.add('dead: button "${_clip(d.label)}" has no tap action');
  }
  n.visitChildren((c) {
    _walkSemantics(c, out, disabled);
    return true;
  });
}

/// Turns a guideline's reason, one SemanticsNode after another, into
/// stable lines: the label and the numbers, no ids.
Iterable<String> _lines(String kind, String reason) sync* {
  final parts = reason.split(RegExp(r'(?=SemanticsNode#\d+)'));
  for (final p in parts) {
    if (!p.startsWith('SemanticsNode#')) continue;
    final label = RegExp(r'label: "([^"]*)"').firstMatch(p)?.group(1) ?? '';
    final tip = RegExp(r'tooltip: "([^"]*)"').firstMatch(p)?.group(1) ?? '';
    final name = _clip(label.isNotEmpty ? label : tip);
    switch (kind) {
      case 'tap':
        final m = RegExp(r'found Size\(([\d.]+), ([\d.]+)\)').firstMatch(p);
        final w = double.tryParse(m?.group(1) ?? '')?.round();
        final h = double.tryParse(m?.group(2) ?? '')?.round();
        yield 'tap: "$name" ${w}x$h';
      default:
        final r = RegExp(r'Rect\.fromLTRB\(([\d.]+), ([\d.]+)').firstMatch(p);
        final x = double.tryParse(r?.group(1) ?? '')?.round();
        final y = double.tryParse(r?.group(2) ?? '')?.round();
        yield '$kind: tappable at ($x, $y) has no label';
    }
  }
}

String _textIn(Element e) {
  final buf = StringBuffer();
  void visit(Element c) {
    final w = c.widget;
    if (w is Text) buf.write(w.data ?? w.textSpan?.toPlainText() ?? '');
    if (w is RichText) buf.write(w.text.toPlainText());
    if (buf.isEmpty) c.visitChildren(visit);
  }

  visit(e);
  return _clip(buf.toString());
}

String _clip(String s) {
  final one = s.replaceAll('\n', ' ').trim();
  return one.length > 40 ? '${one.substring(0, 40)}…' : one;
}
