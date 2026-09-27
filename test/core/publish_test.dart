import 'package:cgpa_calculator/core/catalog/catalog.dart';
import 'package:cgpa_calculator/core/catalog/publish.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('edits apply to the next version, and the diff puts credits first', () {
    final live = catalog;
    final some = live.chartNew.firstWhere((c) => c.credits == 3);
    final other = live.master.firstWhere(
      (m) => m.id != some.id && !live.retired.contains(m.id),
    );
    final next = applyEdits(live, [
      CourseEdit(id: some.id, credits: 4),
      CourseEdit(id: other.id, title: 'Renamed', retired: true),
      const CourseEdit(id: 'ZZ F999', title: 'New Thing', credits: 2),
    ]);
    expect(next.version, live.version + 1);
    expect(next.chartNew.firstWhere((c) => c.id == some.id).credits, 4);
    expect(next.retired, contains(other.id));

    final d = diffCatalog(live, next);
    expect(d.credits.single.id, some.id);
    expect(d.credits.single.from, 3);
    expect(d.credits.single.to, 4);
    expect(d.retired.single.id, other.id);
    expect(d.cosmetic.map((c) => c.what), contains('New course'));
    expect(
      d.cosmetic.where((c) => c.id == other.id).single.what,
      startsWith('Title'),
    );

    // It survives the bundle round trip.
    final back = Catalog.fromJson(next.toJson());
    expect(diffCatalog(next, back).isEmpty, isTrue);
  });

  test('un-retiring is listed, not hidden', () {
    final live = catalog;
    if (live.retired.isEmpty) return;
    final id = live.retired.first;
    final next = applyEdits(live, [CourseEdit(id: id, retired: false)]);
    expect(next.retired, isNot(contains(id)));
    expect(diffCatalog(live, next).cosmetic.single.what, 'Back on offer');
  });
}
