import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/bottom_action.dart';
import 'package:cgpa_calculator/shared/widgets/card_label.dart';
import 'package:cgpa_calculator/shared/widgets/card_row.dart';
import 'package:cgpa_calculator/shared/widgets/code_badge.dart';
import 'package:cgpa_calculator/shared/widgets/count_badge.dart';
import 'package:cgpa_calculator/shared/widgets/grade_chip.dart';
import 'package:cgpa_calculator/shared/widgets/notice.dart';
import 'package:cgpa_calculator/shared/widgets/outlined_pill.dart';
import 'package:cgpa_calculator/shared/widgets/pill_button.dart';
import 'package:cgpa_calculator/shared/widgets/search_box.dart';
import 'package:cgpa_calculator/shared/widgets/segmented.dart';
import 'package:cgpa_calculator/shared/widgets/stat_card.dart';
import 'package:cgpa_calculator/shared/widgets/tag_badge.dart';
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

  group('T3.2: pills and tags hug their text; equal tab rows', () {
    testWidgets('a TierTag in a Wrap is narrower than 100', (t) async {
      await t.pumpWidget(_host(const Wrap(children: [TierTag('OWNER')])));
      expect(t.getSize(find.byType(TierTag)).width, lessThan(100));
    });

    testWidgets('ChoicePills(equal: true) gives equal-width children', (
      t,
    ) async {
      await t.pumpWidget(
        _host(
          ChoicePills<int>(
            values: const [1, 2, 3, 4],
            selected: 1,
            label: (v) => '$v',
            onSelected: (_) {},
            equal: true,
          ),
        ),
      );
      final widths =
          [1, 2, 3, 4]
              .map((v) => t.getSize(find.widgetWithText(Expanded, '$v')).width)
              .toList();
      expect(widths.toSet().length, 1);
    });
  });

  group('T3.3: mint, not dark green', () {
    testWidgets("TierTag(strong: false)'s fill is hero", (t) async {
      await t.pumpWidget(_host(const TierTag('PRESIDENT')));
      final container = t.widget<Container>(
        find.descendant(
          of: find.byType(TierTag),
          matching: find.byType(Container),
        ),
      );
      expect(
        (container.decoration as BoxDecoration).color,
        AppPalette.light.hero,
      );
    });
  });

  group('T3.7: CountBadge', () {
    testWidgets('waiting tone fills with noticeTone', (t) async {
      await t.pumpWidget(_host(const CountBadge('3')));
      final container = t.widget<Container>(
        find.descendant(
          of: find.byType(CountBadge),
          matching: find.byType(Container),
        ),
      );
      expect(
        (container.decoration as BoxDecoration).color,
        AppPalette.light.noticeTone.fill,
      );
    });
  });

  group('T3.9: small helpers', () {
    test('ago() pluralises minutes and hours', () {
      final now = DateTime(2026, 9, 28, 12, 0);
      expect(
        ago(now.subtract(const Duration(minutes: 1)), now: now),
        '1 minute ago',
      );
      expect(
        ago(now.subtract(const Duration(minutes: 5)), now: now),
        '5 minutes ago',
      );
      expect(
        ago(now.subtract(const Duration(hours: 1)), now: now),
        '1 hour ago',
      );
      expect(
        ago(now.subtract(const Duration(hours: 3)), now: now),
        '3 hours ago',
      );
    });

    testWidgets('LabelRow at 200 wide with a 150-wide trailing stacks', (
      t,
    ) async {
      await t.pumpWidget(
        _host(
          LabelRow(
            label: const Text('TAKEN BY, THIS TERM'),
            trailing: const SizedBox(width: 150, height: 30),
          ),
          width: 200,
        ),
      );
      await t.pump();
      await t.pump();
      expect(find.byType(Column), findsWidgets);
      final row = t.widgetList(find.byType(Row));
      // No Row directly holding both the label and the trailing SizedBox.
      expect(
        row.any(
          (w) =>
              (w as Row).children.length == 3 && w.children.first is Expanded,
        ),
        isFalse,
      );
    });

    testWidgets('NameEmail keeps the email to one line at 320, 200% text', (
      t,
    ) async {
      await t.pumpWidget(
        MaterialApp(
          theme: AppPalette.light.materialTheme,
          builder:
              (c, child) => MediaQuery(
                data: MediaQuery.of(
                  c,
                ).copyWith(textScaler: TextScaler.linear(2)),
                child: child!,
              ),
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: const NameEmail(
                'Siddharth Mishra',
                'f20230456@goa.bits-pilani.ac.in',
              ),
            ),
          ),
        ),
      );
      // Rows show the short campus form (T9.1, the user's choice).
      final text = t.widget<Text>(find.text('f20230456@goa'));
      expect(text.maxLines, 1);
      expect(t.takeException(), isNull);
    });

    test('shortEmail drops the domain', () {
      expect(shortEmail('f20230456@goa.bits-pilani.ac.in'), 'f20230456@goa');
    });
  });

  group('T3.10: shared parts', () {
    testWidgets('CardLabel upper-cases its text', (t) async {
      await t.pumpWidget(_host(const CardLabel('structure')));
      expect(find.text('STRUCTURE'), findsOneWidget);
    });

    testWidgets('SegmentedPair reports the tapped side', (t) async {
      var picked = 0;
      await t.pumpWidget(
        _host(
          SegmentedPair<int>(
            a: (0, 'One mark'),
            b: (1, 'Several parts'),
            value: 0,
            onChanged: (v) => picked = v,
          ),
        ),
      );
      await t.tap(find.text('Several parts'));
      expect(picked, 1);
    });

    testWidgets('SegmentedTrack reports the tapped tab', (t) async {
      var picked = '';
      await t.pumpWidget(
        _host(
          SegmentedTrack<String>(
            tabs: const [('all', 'All'), ('mine', 'Mine')],
            value: 'all',
            onChanged: (v) => picked = v,
          ),
        ),
      );
      await t.tap(find.text('Mine'));
      expect(picked, 'mine');
    });

    testWidgets('TagBadge upper-cases its text', (t) async {
      await t.pumpWidget(_host(const TagBadge('yours', tone: TagTone.yours)));
      expect(find.text('YOURS'), findsOneWidget);
    });

    testWidgets('Notice(warning: true) tones its icon differently', (t) async {
      await t.pumpWidget(
        _host(Notice(text: const TextSpan(text: 'careful'), warning: true)),
      );
      final icon = t.widget<Icon>(find.byType(Icon));
      expect(icon.color, AppPalette.light.behind);
    });

    testWidgets('CardRow shows a chevron only without trailing, taps through', (
      t,
    ) async {
      var taps = 0;
      await t.pumpWidget(
        _host(
          Column(
            children: [
              CardRow(title: 'Grading scheme', onTap: () => taps++),
              const CardDivider(),
              const CardRow(title: 'Credits', trailing: Text('4')),
            ],
          ),
        ),
      );
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      await t.tap(find.text('Grading scheme'));
      expect(taps, 1);
    });

    testWidgets('CodeBadge(empty) shows a dashed slot, no text', (t) async {
      await t.pumpWidget(_host(const CodeBadge('', tone: CodeTone.empty)));
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('SearchBox shows its hint and reports typed text', (t) async {
      final c = TextEditingController();
      String? typed;
      await t.pumpWidget(
        _host(
          SearchBox(
            controller: c,
            hint: 'Search courses',
            onChanged: (v) => typed = v,
          ),
        ),
      );
      expect(find.text('Search courses'), findsOneWidget);
      await t.enterText(find.byType(TextField), 'thermo');
      expect(typed, 'thermo');
    });

    testWidgets('BottomAction.heightOf grows with a caption', (t) async {
      late BuildContext ctx;
      await t.pumpWidget(
        _host(
          Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(
        BottomAction.heightOf(ctx, hasCaption: true),
        greaterThan(BottomAction.heightOf(ctx)),
      );
    });

    testWidgets('CompactField(official) shows the tag, not a text field', (
      t,
    ) async {
      await t.pumpWidget(
        _host(
          CompactField(c: TextEditingController(text: '9.2'), official: true),
        ),
      );
      expect(find.text('OFFICIAL'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('AppTextField(labelAbove) puts the label above the box', (
      t,
    ) async {
      await t.pumpWidget(
        _host(
          AppTextField(
            controller: TextEditingController(),
            label: 'course code',
            labelAbove: true,
          ),
        ),
      );
      expect(find.text('COURSE CODE'), findsOneWidget);
    });

    testWidgets('PrimaryButton(tall: true) is 56 high', (t) async {
      await t.pumpWidget(
        _host(PrimaryButton(label: 'Save', onPressed: () {}, tall: true)),
      );
      expect(t.getSize(find.byType(PrimaryButton)).height, 56);
    });

    testWidgets('OutlinedPill reports taps', (t) async {
      var taps = 0;
      await t.pumpWidget(
        _host(OutlinedPill(label: 'Filter', onPressed: () => taps++)),
      );
      await t.tap(find.text('Filter'));
      expect(taps, 1);
    });
  });

  group('T3.5: friendly errors', () {
    test('problem() never leaks the raw exception text', () {
      final text = problem(
        Exception(
          '[cloud_firestore/failed-precondition] The query requires an '
          'index. You can create it here: https://console.firebase.google.com/…',
        ),
      );
      expect(text, isNot(contains('http')));
    });

    testWidgets('Loaded shows Try again on error, and retries on tap', (
      t,
    ) async {
      var calls = 0;
      await t.pumpWidget(
        MaterialApp(
          theme: AppPalette.light.materialTheme,
          home: Scaffold(
            body: Loaded<int>(
              load: () async {
                calls++;
                throw Exception('boom');
              },
              builder: (context, data, reload) => Text('$data'),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('Try again'), findsOneWidget);
      await t.tap(find.text('Try again'));
      await t.pumpAndSettle();
      expect(calls, 2);
    });
  });
}
