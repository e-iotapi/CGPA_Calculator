// U3: Offshoot optional. Real MyHomePage cannot be pumped (needs FirebaseAuth),
// so the id mapping and swipe rule are unit tests, the nav is a stand-in built
// the way home_page.dart builds it, and the Settings switch is the real view.
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/features/settings/settings_view.dart';
import 'package:cgpa_calculator/home_page.dart';
import 'package:cgpa_calculator/shared/layout/responsive.dart';
import 'package:cgpa_calculator/shared/widgets/app_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _labels = {
  0: 'More',
  1: 'Actual',
  2: 'Expected',
  3: 'Compare',
  4: 'Offshoot',
};

class _Nav extends StatefulWidget {
  const _Nav({required this.offshoot, required this.log});
  final bool offshoot;
  final List<String> log;
  @override
  State<_Nav> createState() => _NavState();
}

class _NavState extends State<_Nav> {
  int selected = 1;
  @override
  Widget build(BuildContext context) {
    final ids = homeNavIds(widget.offshoot);
    return ResponsiveScaffold(
      selectedIndex: ids.indexOf(selected),
      onSelected: (i) {
        final id = ids[i];
        if (id == 0) return widget.log.add('more');
        setState(() => selected = id);
        widget.log.add('profile $id');
      },
      destinations: [
        for (final id in ids)
          NavDestination(icon: Icons.circle, label: _labels[id]!),
      ],
      body: const SizedBox(),
    );
  }
}

Widget _app(Widget home) =>
    MaterialApp(theme: AppPalette.light.materialTheme, home: home);

// Pill: unselected items are tooltips; the rail and selected pill show text.
Finder _nav(String l) {
  final tip = find.byTooltip(l);
  return tip.evaluate().isNotEmpty ? tip.first : find.text(l).first;
}

// By semantics: the selected pill drops its text when the label does not fit.
bool _has(String l) =>
    find.bySemanticsLabel(RegExp('^$l\$')).evaluate().isNotEmpty;

void main() {
  test('ids keep the profile numbers; More is id 0 and always last', () {
    expect(homeNavIds(true), [1, 2, 3, 4, 0]);
    expect(homeNavIds(false), [1, 2, 3, 0]);
  });

  test('a swipe skips the hidden profile: Compare is the last one', () {
    expect(homeNextProfile(3, 1, true), 4);
    expect(homeNextProfile(3, 1, false), isNull);
    expect(homeNextProfile(4, 1, true), isNull);
    expect(homeNextProfile(1, -1, false), isNull);
    expect(homeNextProfile(2, 1, false), 3);
    expect(homeNextProfile(3, -1, false), 2);
  });

  for (final w in [320.0, 600.0, 1200.0]) {
    for (final on in [true, false]) {
      testWidgets('nav at $w with Offshoot ${on ? 'shown' : 'hidden'}', (
        t,
      ) async {
        t.view.physicalSize = Size(w, 900);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final sem = t.ensureSemantics();
        final log = <String>[];
        await t.pumpWidget(_app(_Nav(offshoot: on, log: log)));
        expect(
          [
            for (final l in _labels.values)
              if (_has(l)) l,
          ].length,
          on ? 5 : 4,
        );
        expect(_has('Offshoot'), on);
        await t.tap(_nav('Compare'));
        await t.pump();
        await t.tap(_nav('More'));
        expect(log, ['profile 3', 'more']);
        sem.dispose();
      });
    }
  }

  group('Settings switch', () {
    Widget view({bool? on, ValueChanged<bool>? change}) => _app(
      SettingsView(
        name: 'Sid',
        email: 'f20220000@goa.bits-pilani.ac.in',
        discipline: 'B3A7',
        batch: 24,
        isDark: false,
        profiles: const ['Actual', 'Expected', 'P3'],
        onClose: () {},
        onPickDiscipline: (_) {},
        onTheme: (_) {},
        onRenameProfile: (_) {},
        onExport: () {},
        onImportOld: () {},
        onReport: () {},
        onReset: () {},
        onSignOut: () {},
        campus: 'Goa',
        showOffshoot: on ?? true,
        onShowOffshoot: change,
      ),
    );

    testWidgets('row is absent without a handler', (t) async {
      await t.pumpWidget(view());
      expect(find.text('Show Offshoot tab'), findsNothing);
    });

    testWidgets('on by default; a tap asks to hide, no write before it', (
      t,
    ) async {
      final calls = <bool>[];
      await t.pumpWidget(view(change: calls.add));
      await t.scrollUntilVisible(
        find.text('Show Offshoot tab'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(calls, isEmpty);
      expect(t.widget<Switch>(find.byType(Switch)).value, true);
      await t.tap(find.text('Show Offshoot tab'));
      expect(calls, [false]);
    });
  });
}
