import 'dart:io';

import 'package:flutter/services.dart';

/// Loads the app's real fonts into the test engine. Without this every glyph
/// is a font-size square, so width checks are meaningless.
Future<void> loadAppFonts() async {
  Future<void> load(String family, String path) async {
    final bytes = File(path).readAsBytesSync();
    await (FontLoader(family)
      ..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  }

  await load('Montserrat', 'fonts/Montserrat-SemiBold.ttf');
  // flutter_tester lives at <root>/bin/cache/artifacts/engine/<platform>/.
  final flutterRoot =
      Platform.environment['FLUTTER_ROOT'] ??
      File(
        Platform.resolvedExecutable,
      ).parent.parent.parent.parent.parent.parent.path;
  await load(
    'MaterialIcons',
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
}
