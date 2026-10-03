// --commit against the Firestore emulator: the writes land as planned, and a second run adds nothing.
// Skipped unless an emulator is up:
//   /tmp/pointer-heavy.sh firebase emulators:exec --only firestore --project demo-pointer \
//     "FIRESTORE_EMULATOR_HOST=localhost:8085 node --test tools/timetable/commit.emu.test.mjs"
import assert from 'node:assert/strict';
import { test } from 'node:test';

import { apply, connect, makePlan, readLive } from './extract.mjs';

const sec = (...names) => ({ type: 'L', no: 1, instructors: names.map((name) => ({ name, ic: false })), slots: [{ day: 'M', start: '09:00', end: '09:50' }] });
const mk = () => ({
  sem: '2026-1', campus: 'goa', unparsed: [], conflicts: [], events: [],
  hours: { periods: { 1: ['09:00', '09:50'] }, compre: { FN: ['10:00', '13:00'] } },
  courses: {
    'BIO F111': { title: 'GENERAL BIOLOGY', sections: [sec('Dr. Alder Quill')] },
    'ZZZ F202': { title: 'BETA OF THINGS', credits: 4, sections: [sec('R. Aduri', 'Cedar Vale')] },
  },
});

test('commit on the emulator, then again: the second run has nothing to write', { skip: !process.env.FIRESTORE_EMULATOR_HOST }, async () => {
  const args = { campus: 'goa', sem: '2026-1', input: 't', project: 'demo-pointer' };
  const asset = JSON.parse((await import('node:fs')).readFileSync(new URL('../../assets/catalog.json', import.meta.url), 'utf8'));
  const fs = connect(args);
  const db = fs.getFirestore();
  // A professor the PDF spells differently: unsure, so first it is left alone, then linked by answer.
  await db.doc('professors/exist1').set({ name: 'Raviprasad Aduri', campus: 'goa', department: 'BIO', aliases: [], nameTokens: [], mergedIds: [], active: true });
  // Staff already set this offering.
  await db.doc('courses/BIO F111/offerings/goa_2026-27-1').set({ courseId: 'BIO F111', campus: 'goa', term: '2026-27-1', components: [], professors: ['staffpick'] });

  const run = async (answers) => {
    const out = mk();
    const plan = makePlan(args, out, await readLive(fs, args, Object.keys(out.courses), '2026-27-1'), answers, asset);
    await apply(fs, plan.batches);
    return plan;
  };
  const first = await run({});
  assert.equal(first.res.entries.filter((e) => e.status === 'unsure').length, 1);
  assert.equal(first.offerings.kept.length, 1);
  assert.equal((await db.doc('courses/BIO F111/offerings/goa_2026-27-1').get()).data().professors[0], 'staffpick');
  assert.equal((await db.doc('courses/ZZZ F202/offerings/goa_2026-27-1').get()).exists, false); // waits on the unsure name

  const second = await run({ 'R. Aduri': 'exist1' });
  assert.ok(second.batches.length > 0);
  assert.deepEqual((await db.doc('professors/exist1').get()).data().aliases, ['R. Aduri']);
  const off = (await db.doc('courses/ZZZ F202/offerings/goa_2026-27-1').get()).data();
  assert.equal(off.professors.length, 2);
  assert.equal(off.src, 'timetable');

  const third = await run({ 'R. Aduri': 'exist1' });
  assert.deepEqual(third.batches, [], 'nothing left to write');

  // Markers: catalogue v2 and the heads, timetable once, professors per department.
  const marker = (await db.doc('catalog/marker').get()).data();
  assert.equal(marker.version, asset.version + 1);
  const bundle = JSON.parse((await db.doc(`catalog/v${marker.version}`).get()).data().json);
  assert.deepEqual(bundle.master.at(-1).slice(0, 3), ['ZZZ F202', 'Beta of Things', 4]);
  assert.equal(bundle.master.length, asset.master.length + 1);
  const head = (await db.doc('heads/goa').get()).data();
  assert.equal(head.catalog, marker.version);
  assert.equal(head.v.timetable, 2); // run 2 republished with the Aduri link
  assert.equal((await db.doc('heads/dubai').get()).data().catalog, marker.version);
  assert.ok(head.offerings['ZZZ F202|2026-27-1'] >= 1);
  const tt = (await db.doc('timetable/goa|2026-1').get()).data();
  assert.equal(tt.marker, 2);
  assert.equal((await db.doc('timetable/goa|current').get()).data().sem, '2026-1');
  assert.ok(Object.keys((await db.doc('timetable/goa|2026-1|0').get()).data().courses).includes('ZZZ F202'));
  // Cedar Vale was created once, with the shape ProfessorStore.add writes.
  const cedar = (await db.collection('professors').where('name', '==', 'Cedar Vale').get()).docs;
  assert.equal(cedar.length, 1);
  assert.equal(cedar[0].data().department, 'GEN');
  assert.equal(cedar[0].data().src, 'timetable');
});
