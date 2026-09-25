// Export your grades from the OLD CGPA Calculator site.
//
// Hive stores Course objects in IndexedDB as binary ArrayBuffers (prefix
// 0x90 0xA9, then type 32 = the Course adapter), so a plain JSON dump of
// IndexedDB loses the grades. This decodes those records properly.
//
// HOW TO USE
//   1. Open the old site in your browser.
//   2. Open DevTools (F12) -> Console.
//   3. Paste this whole file, press Enter.
//   4. The JSON is copied to your clipboard.
//   5. On the new site: Settings -> "Import from old site" -> paste -> Import.

(async () => {
  const P = r => new Promise((ok, err) => { r.onsuccess = () => ok(r.result); r.onerror = err; });
  const names = (await indexedDB.databases()).map(d => d.name);
  const td = new TextDecoder(), data = {};
  const dec = v => {
    if (!(v instanceof ArrayBuffer)) return v;
    const d = new DataView(v); let o = 2;
    const rd = () => {
      const t = d.getUint8(o++);
      if (t === 0) return null;
      if (t === 1 || t === 2) { const x = d.getFloat64(o, true); o += 8; return x; }
      if (t === 3) return d.getUint8(o++) !== 0;
      if (t === 4) { const n = d.getUint32(o, true); o += 4; const s = td.decode(new Uint8Array(v, o, n)); o += n; return s; }
      if (t === 32) { const n = d.getUint8(o++), f = {};
        for (let i = 0; i < n; i++) { const idx = d.getUint8(o++); f[idx] = rd(); }
        return { title: f[0], id: f[1], credits: f[2], grade1: f[3], grade2: f[4],
                 discipline: f[5], sem: f[6], elective: f[7] ?? 'CDC' }; }
      throw new Error('unknown Hive type ' + t);
    };
    return rd();
  };
  for (const box of ['settingsBox', 'coursesBox', 'offshootBox']) {
    const name = names.find(n => n.toLowerCase().endsWith(box.toLowerCase()));
    if (!name) { data[box] = []; continue; }
    const db = await P(indexedDB.open(name));
    const st = db.transaction('box').objectStore('box');
    const [ks, vs] = await Promise.all([P(st.getAllKeys()), P(st.getAll())]);
    data[box] = ks.map((k, i) => [k, dec(vs[i])]);
    db.close();
  }
  copy(JSON.stringify(data));
  console.log('copied', Object.fromEntries(Object.entries(data).map(([k, v]) => [k, v.length])));
})();
