// UI_OPT O5.1: long cards of rows build only what is on screen, and look
// like RowGroup.
import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:cgpa_calculator/shared/widgets/sliver_row_group.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _row(int i) =>
    SizedBox(height: 52, child: Center(child: Text('Row $i')));

Future<void> _pump(WidgetTester t, List<Widget> children) async {
  t.view.physicalSize = const Size(390, 640);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: AppPalette.light.materialTheme,
      home: PageFrame(
        header: const PageHeader(eyebrow: 'TEST', title: 'Rows'),
        children: children,
      ),
    ),
  );
}

void main() {
  testWidgets('SliverRowGroup builds only visible rows', (t) async {
    var built = 0;
    await _pump(t, [
      SliverRowGroup(
        count: 200,
        row: (_, i) {
          built++;
          return _row(i);
        },
      ),
    ]);
    expect(find.text('Row 0'), findsOneWidget);
    expect(find.text('Row 199'), findsNothing);
    expect(built, lessThan(20));
  });

  testWidgets('SliverRowGroup looks like RowGroup', (t) async {
    await _pump(t, [
      RowGroup(children: [for (var i = 0; i < 3; i++) _row(i)]),
      const SizedBox(height: 20),
      SliverRowGroup(count: 3, row: (_, i) => _row(i + 10)),
    ]);
    double top(String s) => t.getRect(find.text(s)).top;
    // The same rows, a hairline apart, in both.
    expect(top('Row 1') - top('Row 0'), top('Row 11') - top('Row 10'));
    expect(top('Row 2') - top('Row 1'), 53);
    final dividers = find.byType(Divider);
    expect(dividers, findsNWidgets(4));
    for (final d in t.widgetList<Divider>(dividers)) {
      expect((d.indent, d.endIndent, d.height), (15, 15, 1));
    }
  });
}
