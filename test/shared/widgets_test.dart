import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/shared/widgets/grade_chip.dart';
import 'package:cgpa_calculator/shared/widgets/pill_button.dart';
import 'package:cgpa_calculator/shared/widgets/stat_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {double width = 320}) => MaterialApp(
  theme: AppPalette.light.materialTheme,
  home: Scaffold(body: Center(child: SizedBox(width: width, child: child))),
);

void main() {
  testWidgets('long title ellipsizes and the grade chip stays on screen', (
    t,
  ) async {
    await t.pumpWidget(
      _host(
        const Row(
          children: [
            Expanded(
              child: Text(
                'Principles of Programming Languages and Their Very Long '
                'Subtitle That Goes On',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            GradeChip('B-'),
          ],
        ),
      ),
    );
    expect(t.takeException(), isNull);
    final chip = t.getRect(find.byType(GradeChip));
    expect(chip.right, lessThanOrEqualTo(t.view.physicalSize.width));
  });

  testWidgets('two stat cards fit side by side at 320px', (t) async {
    await t.pumpWidget(
      _host(
        const Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'SGPA',
                value: '9.17',
                caption: '24 credits · 4-1',
                hero: true,
              ),
            ),
            SizedBox(width: 11),
            Expanded(
              child: StatCard(
                label: 'CGPA',
                value: '7.71',
                caption: '158 credits',
              ),
            ),
          ],
        ),
      ),
    );
    expect(t.takeException(), isNull);
    expect(find.text('9.17'), findsOneWidget);
    expect(find.text('7.71'), findsOneWidget);
  });

  testWidgets('icon pill announces its label and reports taps', (t) async {
    var taps = 0;
    await t.pumpWidget(
      _host(
        Center(
          child: PillButton.icon(
            icon: Icons.download_rounded,
            semanticLabel: 'Export gradesheet',
            onPressed: () => taps++,
          ),
        ),
      ),
    );
    await t.tap(find.bySemanticsLabel('Export gradesheet'));
    expect(taps, 1);
  });

  testWidgets('a labelled pill hugs its label instead of stretching', (
    t,
  ) async {
    await t.pumpWidget(
      _host(Wrap(children: [PillButton(label: '4 - 1', onPressed: () {})])),
    );
    expect(t.getSize(find.byType(PillButton)).width, lessThan(120));
  });
}
