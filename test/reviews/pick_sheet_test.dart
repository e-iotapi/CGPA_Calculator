import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/features/reviews/pick_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('typing brings in matches from beyond the listed options', (
    t,
  ) async {
    final asked = <String>[];
    ({String? value})? picked;
    await t.pumpWidget(
      MaterialApp(
        theme: AppPalette.light.materialTheme,
        home: Builder(
          builder:
              (context) => TextButton(
                onPressed: () async {
                  picked = await pickSheet<String?>(
                    context,
                    title: 'Professor',
                    searchHint: 'Search professors',
                    options: const [(null, 'Not sure'), ('cs1', 'Cee Ess')],
                    more: (q) async {
                      asked.add(q);
                      return const [('ec1', 'Eko Nomist'), ('cs1', 'Cee Ess')];
                    },
                  );
                },
                child: const Text('open'),
              ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'e');
    await t.pump(const Duration(milliseconds: 400));
    expect(asked, isEmpty, reason: 'one letter asks nothing');
    await t.enterText(find.byType(TextField), 'ek');
    await t.pump(const Duration(milliseconds: 400));
    await t.pump();
    expect(asked, ['ek']);
    expect(find.text('Eko Nomist'), findsOneWidget);
    expect(find.text('Cee Ess'), findsNothing, reason: 'listed, filtered out');
    await t.tap(find.text('Eko Nomist'));
    await t.pumpAndSettle();
    expect(picked?.value, 'ec1');
  });
}
