// UI_OPT O3.1: Home saves a setting only when that setting changes.
import 'package:cgpa_calculator/features/semester/home_persist.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('each change saves only what it changed', () {
    expect(writesFor(HomeChange.semester), [HomeWrite.sem]);
    expect(writesFor(HomeChange.sort), [HomeWrite.sort]);
    expect(writesFor(HomeChange.profile), [HomeWrite.profile]);
  });

  test('a plain rebuild saves nothing', () {
    expect(writesFor(HomeChange.rebuild), isEmpty);
  });
}
