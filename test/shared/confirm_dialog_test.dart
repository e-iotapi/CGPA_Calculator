import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/shared/widgets/confirm_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<bool?> _ask(WidgetTester t, String tap, {AppPalette? theme}) async {
  bool? result;
  await t.pumpWidget(
    MaterialApp(
      theme: (theme ?? AppPalette.light).materialTheme,
      home: Builder(
        builder:
            (c) => TextButton(
              onPressed:
                  () async =>
                      result = await confirmDialog(
                        c,
                        title: 'Clear grades?',
                        body: 'Every grade in this semester is cleared.',
                        action: 'Clear',
                      ),
              child: const Text('open'),
            ),
      ),
    ),
  );
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
  if (theme != null) {
    expect(t.widget<Text>(find.text('Clear grades?')).style?.color, theme.text);
  }
  await t.tap(find.text(tap));
  await t.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('Cancel is false', (t) async {
    expect(await _ask(t, 'Cancel'), isFalse);
  });

  testWidgets('the action is true', (t) async {
    expect(await _ask(t, 'Clear'), isTrue);
  });

  testWidgets('dark theme text is the dark palette\'s', (t) async {
    expect(await _ask(t, 'Cancel', theme: AppPalette.dark), isFalse);
  });
}
