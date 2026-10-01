import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { CampusHub, diffVersions, allow } from "../src/hub";
import { readDoc } from "../src/firestore";

vi.mock("../src/firestore", () => ({ readDoc: vi.fn() }));

class FakeWs {
  sent: any[] = [];
  constructor(public tags: string[]) {}
  send(s: string) {
    this.sent.push(JSON.parse(s));
  }
}

function makeHub() {
  const kv = new Map<string, unknown>();
  const users = new Map<string, number>();
  const sockets: FakeWs[] = [];
  let alarm: number | null = null;
  const setAlarm = vi.fn(async (t: number) => void (alarm = t));
  const ctx = {
    storage: {
      kv,
      get: async (k: string) => kv.get(k),
      put: async (k: string, v: unknown) => void kv.set(k, v),
      getAlarm: async () => alarm,
      setAlarm,
      sql: {
        exec: (q: string, ...p: any[]) => {
          if (/^\s*CREATE/i.test(q)) return { toArray: () => [] };
          if (/^\s*INSERT/i.test(q)) {
            users.set(p[0], (users.get(p[0]) ?? 0) + 1);
            return { toArray: () => [] };
          }
          if (/^\s*SELECT/i.test(q)) return { toArray: () => (users.has(p[0]) ? [{ v: users.get(p[0]) }] : []) };
          throw new Error("unexpected sql " + q);
        },
      },
    },
    getWebSockets: (tag?: string) => sockets.filter((s) => !tag || s.tags.includes(tag)),
    getTags: (ws: FakeWs) => ws.tags,
    blockConcurrencyWhile: async (f: () => Promise<void>) => f(),
  };
  const hub = new CampusHub(ctx as any, {} as any);
  const connect = async (uid: string) => {
    const ws = new FakeWs([uid]);
    sockets.push(ws);
    await hub.sendHello(ws as any, uid, "goa");
    return ws;
  };
  return { hub, ctx, connect, setAlarm, clearAlarm: () => void (alarm = null) };
}

beforeEach(() => {
  vi.mocked(readDoc).mockReset();
  vi.useFakeTimers();
  vi.setSystemTime(1_000_000);
});
afterEach(() => vi.useRealTimers());

describe("pure helpers", () => {
  it("diffVersions returns only moved or new paths", () => {
    expect(diffVersions({ a: 1, b: 2 }, { a: 1, b: 3, c: 1 })).toEqual({ b: 3, c: 1 });
    expect(diffVersions({ a: 1 }, { a: 1 })).toEqual({});
    expect(diffVersions({}, { a: 1 })).toEqual({ a: 1 });
  });

  it("allow() admits one per key per window", () => {
    const m = new Map<string, number>();
    expect(allow(m, "x", 0, 2000)).toBe(true);
    expect(allow(m, "x", 1999, 2000)).toBe(false);
    expect(allow(m, "y", 1999, 2000)).toBe(true);
    expect(allow(m, "x", 2000, 2000)).toBe(true);
  });
});

describe("CampusHub", () => {
  it("hello carries the head and the uid's me", async () => {
    vi.mocked(readDoc).mockResolvedValue({ "a/b": 4 });
    const { connect } = makeHub();
    const ws = await connect("u1");
    expect(ws.sent).toEqual([{ t: "hello", head: { "a/b": 4 }, me: 0 }]);
    expect(readDoc).toHaveBeenCalledWith("heads/goa", expect.anything());
  });

  it("caches the head for 60s across hellos", async () => {
    vi.mocked(readDoc).mockResolvedValue({ p: 1 });
    const { connect } = makeHub();
    await connect("u1");
    await connect("u2");
    expect(readDoc).toHaveBeenCalledTimes(1);
    vi.setSystemTime(1_000_000 + 61_000);
    await connect("u3");
    expect(readDoc).toHaveBeenCalledTimes(2);
  });

  it("two pokes inside the window arm one alarm and cause one read", async () => {
    vi.mocked(readDoc).mockResolvedValue({ p: 1 });
    const { hub, connect, setAlarm } = makeHub();
    const ws = await connect("u1");
    vi.mocked(readDoc).mockClear();
    await hub.webSocketMessage(ws as any, JSON.stringify({ t: "poke", path: "p" }));
    await hub.webSocketMessage(ws as any, JSON.stringify({ t: "poke", path: "q" }));
    expect(setAlarm).toHaveBeenCalledTimes(1);
    expect(setAlarm).toHaveBeenCalledWith(1_000_000 + 1500);
    vi.mocked(readDoc).mockResolvedValue({ p: 2 });
    await hub.alarm();
    expect(readDoc).toHaveBeenCalledTimes(1);
  });

  it("rate-limits repeat pokes of one path to 1 per 2s", async () => {
    vi.mocked(readDoc).mockResolvedValue({});
    const { hub, connect, setAlarm, clearAlarm } = makeHub();
    const ws = await connect("u1");
    const poke = () => hub.webSocketMessage(ws as any, JSON.stringify({ t: "poke", path: "p" }));
    await poke();
    clearAlarm();
    vi.setSystemTime(1_000_000 + 1000);
    await poke();
    expect(setAlarm).toHaveBeenCalledTimes(1);
    vi.setSystemTime(1_000_000 + 2000);
    await poke();
    expect(setAlarm).toHaveBeenCalledTimes(2);
  });

  it("alarm broadcasts only the diff, to every socket", async () => {
    vi.mocked(readDoc).mockResolvedValue({ a: 1, b: 1 });
    const { hub, connect } = makeHub();
    const w1 = await connect("u1");
    const w2 = await connect("u2");
    vi.mocked(readDoc).mockResolvedValue({ a: 1, b: 2 });
    await hub.alarm();
    expect(w1.sent[1]).toEqual({ t: "head", v: { b: 2 } });
    expect(w2.sent[1]).toEqual({ t: "head", v: { b: 2 } });
  });

  it("alarm with an unchanged head broadcasts nothing", async () => {
    vi.mocked(readDoc).mockResolvedValue({ a: 1 });
    const { hub, connect } = makeHub();
    const ws = await connect("u1");
    await hub.alarm();
    expect(ws.sent).toHaveLength(1);
  });

  it("alarm survives a Firestore error", async () => {
    vi.mocked(readDoc).mockResolvedValue({ a: 1 });
    const { hub, connect } = makeHub();
    const ws = await connect("u1");
    vi.mocked(readDoc).mockRejectedValue(new Error("boom"));
    await expect(hub.alarm()).resolves.toBeUndefined();
    expect(ws.sent).toHaveLength(1);
  });

  it("pokeMe bumps and reaches only that uid's sockets", async () => {
    vi.mocked(readDoc).mockResolvedValue({});
    const { hub, connect } = makeHub();
    const a1 = await connect("u1");
    const a2 = await connect("u1");
    const b = await connect("u2");
    await hub.webSocketMessage(a1 as any, JSON.stringify({ t: "pokeMe" }));
    await hub.webSocketMessage(a2 as any, JSON.stringify({ t: "pokeMe" }));
    expect(a1.sent.slice(1)).toEqual([{ t: "me", v: 1 }, { t: "me", v: 2 }]);
    expect(a2.sent.slice(1)).toEqual([{ t: "me", v: 1 }, { t: "me", v: 2 }]);
    expect(b.sent).toHaveLength(1);
    const c = await connect("u1");
    expect(c.sent[0].me).toBe(2);
  });

  it("ignores junk messages", async () => {
    vi.mocked(readDoc).mockResolvedValue({});
    const { hub, connect, setAlarm } = makeHub();
    const ws = await connect("u1");
    await hub.webSocketMessage(ws as any, "not json");
    await hub.webSocketMessage(ws as any, new ArrayBuffer(2));
    await hub.webSocketMessage(ws as any, JSON.stringify({ t: "poke", path: 5 }));
    await hub.webSocketMessage(ws as any, JSON.stringify({ t: "nope" }));
    expect(setAlarm).not.toHaveBeenCalled();
    expect(ws.sent).toHaveLength(1);
  });
});
