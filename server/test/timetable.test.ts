import { describe, it, expect, vi, beforeEach } from "vitest";
import worker, { builtMemo } from "../src/index";
import { readDoc } from "../src/firestore";
import { esc, fold } from "../src/timetable";

vi.mock("../src/firestore", () => ({ readDoc: vi.fn() }));

const env = { PROJECT_ID: "p", FIREBASE_SA: "{}" } as any;
const store = new Map<string, Response>();
const ctx = { waitUntil: (p: Promise<unknown>) => void p.catch(() => {}) } as unknown as ExecutionContext;
const call = (path: string, init?: RequestInit) => worker.fetch(new Request("https://w.example" + path, init), env, ctx);

// Invented data only.
const docs: Record<string, any> = {
  "timetable/goa|current": { sem: "2026-1", marker: 3 },
  "timetable/goa|2026-1": {
    sem: "2026-1", campus: "goa", chunks: 2, marker: 3, publishedAt: "2026-09-01T00:00:00Z",
    hours: { "1": [480, 540] }, examSlots: { FN: [570, 750] },
    events: [
      { from: "2026-08-03", title: "Instruction begins", kind: "term" },
      { from: "2026-09-05", to: "2026-09-06", title: "Break, with; odd\\chars", kind: "holiday" },
    ],
  },
  "timetable/goa|2026-1|0": { n: 0, courses: { "AAA F111": { t: "Intro, Widgets", sec: [], mid: { d: "2026-10-12", s: 570, e: 660 }, compre: { d: "2026-12-10", slot: "FN", s: 570, e: 750 } } } },
  "timetable/goa|2026-1|1": { n: 1, courses: { "BBB F211": { t: "Gadgets", sec: [] } } },
};

beforeEach(() => {
  store.clear();
  builtMemo.clear();
  vi.mocked(readDoc).mockReset();
  vi.mocked(readDoc).mockImplementation(async (p: string) => docs[p] ?? null);
  vi.stubGlobal("caches", {
    default: {
      match: async (r: Request) => store.get(r.url)?.clone(),
      put: async (r: Request, res: Response) => void store.set(r.url, res.clone()),
    },
  });
});

describe("GET /timetable/:campus.json", () => {
  it("merges meta and chunks, with the contract headers", async () => {
    const r = await call("/timetable/goa.json");
    expect(r.status).toBe(200);
    expect(r.headers.get("Cache-Control")).toBe("public, max-age=300");
    expect(r.headers.get("ETag")).toBe('"3"');
    const j: any = await r.json();
    expect(j).toMatchObject({ v: 1, campus: "goa", sem: "2026-1", marker: 3, publishedAt: Date.parse("2026-09-01T00:00:00Z") });
    expect(Object.keys(j.courses)).toEqual(["AAA F111", "BBB F211"]);
    expect(j.events).toHaveLength(2);
  });

  it("answers 304 to a matching ETag and reads Firestore once", async () => {
    await call("/timetable/goa.json");
    const n = vi.mocked(readDoc).mock.calls.length;
    expect(n).toBe(4); // current, meta, 2 chunks
    const r = await call("/timetable/goa.json", { headers: { "If-None-Match": '"3"' } });
    expect(r.status).toBe(304);
    expect(vi.mocked(readDoc).mock.calls.length).toBe(n);
  });

  it("serves from the edge copy when the isolate memo is cold", async () => {
    await call("/timetable/goa.json");
    await new Promise((r) => setTimeout(r, 0));
    builtMemo.clear();
    vi.mocked(readDoc).mockClear();
    expect(((await (await call("/timetable/goa.json")).json()) as any).marker).toBe(3);
    expect(readDoc).not.toHaveBeenCalled();
  });

  it("404 {error} when nothing is published, and does not cache it", async () => {
    vi.mocked(readDoc).mockResolvedValue(null);
    const r = await call("/timetable/goa.json");
    expect(r.status).toBe(404);
    expect(await r.json()).toEqual({ error: "not published" });
    await new Promise((r) => setTimeout(r, 0));
    expect(store.size).toBe(0);
    expect((await call("/timetable/mars.json")).status).toBe(404);
  });

  it("502 on a Firestore error", async () => {
    vi.mocked(readDoc).mockRejectedValue(new Error("boom"));
    expect((await call("/timetable/goa.json")).status).toBe(502);
  });
});

describe("GET /calendar/:campus.ics", () => {
  it("is RFC 5545 with academic events and every exam, CRLF throughout", async () => {
    const r = await call("/calendar/goa.ics");
    expect(r.status).toBe(200);
    expect(r.headers.get("Content-Type")).toBe("text/calendar; charset=utf-8");
    expect(r.headers.get("Cache-Control")).toBe("public, max-age=3600");
    const t = await r.text();
    expect(t.startsWith("BEGIN:VCALENDAR\r\n")).toBe(true);
    expect(t.endsWith("END:VCALENDAR\r\n")).toBe(true);
    expect(t.replace(/\r\n/g, "")).not.toMatch(/[\r\n]/);
    for (const l of t.split("\r\n")) expect(new TextEncoder().encode(l).length).toBeLessThanOrEqual(75);
    expect(t).toContain("PRODID:-//Pointer//Campus Calendar//EN");
    expect(t).toContain("X-WR-CALNAME:Goa academic calendar 2026-1");
    expect(t).toContain("REFRESH-INTERVAL;VALUE=DURATION:P1D");
    expect(t).toContain("BEGIN:VTIMEZONE\r\nTZID:Asia/Kolkata");
    // one-day event: DTEND exclusive next day; multi-day: to + 1
    expect(t).toContain("DTSTART;VALUE=DATE:20260803\r\nDTEND;VALUE=DATE:20260804");
    expect(t).toContain("DTSTART;VALUE=DATE:20260905\r\nDTEND;VALUE=DATE:20260907");
    expect(t).toContain("SUMMARY:Break\\, with\\; odd\\\\chars");
    expect(t).toContain("CATEGORIES:holiday");
    expect(t).toContain("DTSTART;TZID=Asia/Kolkata:20261012T093000\r\nDTEND;TZID=Asia/Kolkata:20261012T110000");
    expect(t).toContain("SUMMARY:AAA F111 Midsem\r\nDESCRIPTION:Intro\\, Widgets");
    expect(t).toContain("SUMMARY:AAA F111 Compre");
    expect(t).toContain("DTSTART;TZID=Asia/Kolkata:20261210T093000\r\nDTEND;TZID=Asia/Kolkata:20261210T123000");
    expect(t).not.toContain("BBB F211 Midsem");
    expect(t).toContain("DTSTAMP:20260901T000000Z");
    expect(t).toMatch(/UID:goa-2026-1-[0-9a-f]{40}@pointer/);
    expect(t).toContain("UID:goa-2026-1-AAA-F111-mid@pointer");
  });

  it("UIDs are stable across calls", async () => {
    const a = await (await call("/calendar/goa.ics")).text();
    builtMemo.clear();
    store.clear();
    const b = await (await call("/calendar/goa.ics")).text();
    expect(a).toBe(b);
  });

  it("404 when nothing is published", async () => {
    vi.mocked(readDoc).mockResolvedValue(null);
    expect((await call("/calendar/goa.ics")).status).toBe(404);
  });
});

describe("ics helpers", () => {
  it("escapes", () => expect(esc("a,b;c\\d\ne")).toBe("a\\,b\\;c\\\\d\\ne"));
  it("folds by octets without splitting a character", () => {
    const line = "SUMMARY:" + "é".repeat(60);
    const f = fold(line);
    const parts = f.split("\r\n");
    expect(parts.length).toBeGreaterThan(1);
    for (const p of parts) expect(new TextEncoder().encode(p).length).toBeLessThanOrEqual(75);
    expect(parts.slice(1).every((p) => p.startsWith(" "))).toBe(true);
    expect(parts.map((p, i) => (i ? p.slice(1) : p)).join("")).toBe(line);
  });
});
