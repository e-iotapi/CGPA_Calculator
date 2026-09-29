import 'package:cgpa_calculator/core/reviews/review.dart';
import 'package:cgpa_calculator/core/reviews/review_store.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ids are pseudonymous and stable', () {
    expect(hashedId('uid1', 'CS F111'), hashedId('uid1', 'CS F111'));
    expect(hashedId('uid1', 'CS F111'), isNot(hashedId('uid2', 'CS F111')));
    expect(hashedId('uid1', 'CS F111'), matches(RegExp(r'^[0-9a-f]{64}$')));
  });

  test('withHelpful bumps the count and keeps everything else', () {
    const r = Review(
      id: 'x',
      courseId: 'CS F111',
      stars: 4,
      recommend: true,
      campus: 'goa',
      term: '2026-1',
      helpful: 2,
    );
    final bumped = r.withHelpful(3);
    expect(bumped.helpful, 3);
    expect(bumped.stars, r.stars);
    expect(bumped.id, r.id);
  });

  test('stats add up; empty stats say nothing', () {
    const a = ReviewStats(count: 2, starSum: 9, recommendCount: 2);
    const b = ReviewStats(count: 2, starSum: 5, recommendCount: 0);
    expect((a + b).average, 3.5);
    expect((a + b).recommendPercent, 50);
    expect(const ReviewStats().average, isNull);
    expect(statsId('goa', 'p1'), 'goa_p1');
  });

  test('post, edit, vote, hide and unhide move the counters', () async {
    final db = FakeFirebaseFirestore();
    final roles = RoleStore(db, me: 'p@goa.bits-pilani.ac.in', myName: 'P');
    final me = ReviewStore(db, uid: 'u1', roles: roles);
    final other = ReviewStore(db, uid: 'u2', roles: roles);

    Future<ReviewStats> course() => me.stats('CS F111', 'goa');
    Future<ReviewStats> prof() =>
        me.stats('CS F111', 'goa', professorIds: ['p1']);

    await me.save(
      courseId: 'CS F111',
      campus: 'goa',
      term: '2025-1',
      professorId: 'p1',
      stars: 4,
      recommend: true,
      text: '  Fair grading.  ',
    );
    var r = (await me.mine('CS F111'))!;
    expect(r.id, hashedId('u1', 'CS F111'));
    expect(r.text, 'Fair grading.');
    expect((await course()).count, 1);
    expect((await prof()).average, 4);

    await me.save(
      courseId: 'CS F111',
      campus: 'goa',
      term: '2025-1',
      professorId: 'p1',
      stars: 2,
      recommend: false,
      before: r,
    );
    r = (await me.mine('CS F111'))!;
    expect(r.text, isNull);
    expect((await course()).count, 1);
    expect((await course()).average, 2);
    expect((await prof()).recommendPercent, 0);

    expect(await other.vote(r), isTrue);
    expect((await me.mine('CS F111'))!.helpful, 1);
    final by = await me.byProfessor('CS F111', 'goa');
    expect(by.keys, ['p1']);
    expect((await me.mostReviewed('goa')).single.courseId, 'CS F111');

    await me.hide(r, 'Names a person');
    r = (await me.mine('CS F111'))!;
    expect(r.hidden, isTrue);
    expect(r.reason, 'Names a person');
    expect((await course()).count, 0);
    final hidden = await me.moderation('goa', 'CS', hidden: true);
    expect(hidden.single.id, r.id);

    await me.unhide(r);
    r = (await me.mine('CS F111'))!;
    expect((await course()).count, 1);
    expect((await db.collection('audit').get()).docs, hasLength(2));
  });
}
