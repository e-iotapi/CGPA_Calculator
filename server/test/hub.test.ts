import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { CampusHub, diffVersions } from "../src/hub";
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
});

describe("CampusHub", () => {
  it("hello carries the head and the uid's me", async () => {
    vi.mocked(readDoc).mockResolvedValue({ catalog: 9, contact: { name: "x" }, v: { "a/b": 4 } });
    const { connect } = makeHub();
    const ws = await connect("u1");
    expect(ws.sent).toEqual([{ t: "hello", head: { "a/b": 4 }, me: 0 }]);
    expect(readDoc).toHaveBeenCalledWith("heads/goa", expect.anything());
  });

  it("caches the head for 60s across hellos", async () => {
    vi.mocked(readDoc).mockResolvedValue({ v: { p: 1 } });
    const { connect } = makeHub();
    await connect("u1");
    await connect("u2");
    expect(readDoc).toHaveBeenCalledTimes(1);
    vi.setSystemTime(1_000_000 + 61_000);
    await connect("u3");
    expect(readDoc).toHaveBeenCalledTimes(2);
  });

  it("two pokes inside the window arm one alarm and cause one read", async () => {
    vi.mocked(readDoc).mockResolvedValue({ v: { p: 1 } });
    const { hub, connect, setAlarm } = makeHub();
    const ws = await connect("u1");
    vi.mocked(readDoc).mockClear();
    await hub.webSocketMessage(ws as any, JSON.stringify({ t: "poke", path: "p" }));
    await hub.webSocketMessage(ws as any, JSON.stringify({ t: "poke", path: "q" }));
    expect(setAlarm).toHaveBeenCalledTimes(1);
    expect(setAlarm).toHaveBeenCalledWith(1_000_000 + 1500);
    vi.mocked(readDoc).mockResolvedValue({ v: { p: 2 } });
    await hub.alarm();
    expect(readDoc).toHaveBeenCalledTimes(1);
  });

  it("a poke while an alarm is armed sets no new alarm", async () => {
    vi.mocked(readDoc).mockResolvedValue({});
    const { hub, connect, setAlarm } = makeHub();
    const ws = await connect("u1");
    const poke = (path: string) => hub.webSocketMessage(ws as any, JSON.stringify({ t: "poke", path }));
    await poke("p");
    vi.setSystemTime(1_000_000 + 1000);
    await poke("p");
    await poke("q");
    expect(setAlarm).toHaveBeenCalledTimes(1);
  });

  it("a poke right after the alarm fired re-arms, no sooner than the read gap", async () => {
    vi.mocked(readDoc).mockResolvedValue({});
    const { hub, connect, setAlarm, clearAlarm } = makeHub();
    const ws = await connect("u1");
    const poke = () => hub.webSocketMessage(ws as any, JSON.stringify({ t: "poke", path: "p" }));
    await poke();
    vi.setSystemTime(1_000_000 + 1500);
    clearAlarm();
    await hub.alarm();
    vi.setSystemTime(1_000_000 + 1600);
    await poke();
    expect(setAlarm).toHaveBeenCalledTimes(2);
    expect(setAlarm).toHaveBeenLastCalledWith(1_000_000 + 1500 + 20_000);
  });

  it("a failed hello read after the cache went old sends {}, not the old numbers", async () => {
    vi.mocked(readDoc).mockResolvedValueOnce({ v: { a: 1 } });
    const { hub, connect, ctx } = makeHub();
    await connect("u1");
    expect(ctx.storage.kv.get("campus")).toBe("goa");
    const put = vi.spyOn(ctx.storage, "put");
    vi.setSystemTime(1_000_000 + 61_000);
    vi.mocked(readDoc).mockRejectedValue(new Error("boom"));
    const w = await connect("u2");
    expect(w.sent[0].head).toEqual({});
    expect(put).not.toHaveBeenCalled(); // campus already stored
  });

  it("an existing alarm found after hibernation is not re-set", async () => {
    vi.mocked(readDoc).mockResolvedValue({});
    const { hub, ctx, connect, setAlarm } = makeHub();
    const ws = await connect("u1");
    await ctx.storage.setAlarm(1_000_000 + 900);
    setAlarm.mockClear();
    await hub.webSocketMessage(ws as any, JSON.stringify({ t: "poke", path: "p" }));
    expect(setAlarm).not.toHaveBeenCalled();
  });

  it("a failed hello read is not cached and does not seed what clients were told", async () => {
    vi.mocked(readDoc).mockRejectedValue(new Error("boom"));
    const { hub, connect } = makeHub();
    const w1 = await connect("u1");
    expect(w1.sent[0].head).toEqual({});
    vi.mocked(readDoc).mockResolvedValue({ v: { a: 1 } });
    const w2 = await connect("u2");
    expect(readDoc).toHaveBeenCalledTimes(2);
    expect(w2.sent[0].head).toEqual({ a: 1 });
    await hub.alarm();
    expect(w2.sent).toHaveLength(1); // last was seeded from the good read, so no diff
  });

  it("a failed hello read leaves last unseeded so the alarm broadcasts the full head", async () => {
    vi.mocked(readDoc).mockRejectedValue(new Error("boom"));
    const { hub, connect } = makeHub();
    const ws = await connect("u1");
    vi.mocked(readDoc).mockResolvedValue({ v: { a: 1 } });
    await hub.alarm();
    expect(ws.sent[1]).toEqual({ t: "head", v: { a: 1 } });
  });

  it("a failed alarm read retries in 5s, at most 3 times in a row", async () => {
    vi.mocked(readDoc).mockResolvedValue({ v: { a: 1 } });
    const { hub, connect, setAlarm } = makeHub();
    await connect("u1");
    vi.mocked(readDoc).mockRejectedValue(new Error("boom"));
    for (let i = 0; i < 3; i++) await hub.alarm();
    expect(setAlarm).toHaveBeenCalledTimes(3);
    expect(setAlarm).toHaveBeenLastCalledWith(1_000_000 + 5000);
    await hub.alarm();
    expect(setAlarm).toHaveBeenCalledTimes(3);
    // success resets the counter
    vi.mocked(readDoc).mockResolvedValue({ v: { a: 2 } });
    await hub.alarm();
    vi.mocked(readDoc).mockRejectedValue(new Error("boom"));
    await hub.alarm();
    expect(setAlarm).toHaveBeenCalledTimes(4);
  });

  it("alarm broadcasts only the diff, to every socket", async () => {
    vi.mocked(readDoc).mockResolvedValue({ v: { a: 1, b: 1 } });
    const { hub, connect } = makeHub();
    const w1 = await connect("u1");
    const w2 = await connect("u2");
    vi.mocked(readDoc).mockResolvedValue({ v: { a: 1, b: 2 } });
    await hub.alarm();
    expect(w1.sent[1]).toEqual({ t: "head", v: { b: 2 } });
    expect(w2.sent[1]).toEqual({ t: "head", v: { b: 2 } });
  });

  it("alarm with an unchanged head broadcasts nothing", async () => {
    vi.mocked(readDoc).mockResolvedValue({ v: { a: 1 } });
    const { hub, connect } = makeHub();
    const ws = await connect("u1");
    await hub.alarm();
    expect(ws.sent).toHaveLength(1);
  });

  it("alarm survives a Firestore error", async () => {
    vi.mocked(readDoc).mockResolvedValue({ v: { a: 1 } });
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
    vi.advanceTimersByTime(2_000);
    await hub.webSocketMessage(a2 as any, JSON.stringify({ t: "pokeMe" }));
    expect(a1.sent.slice(1)).toEqual([{ t: "me", v: 1 }, { t: "me", v: 2 }]);
    expect(a2.sent.slice(1)).toEqual([{ t: "me", v: 1 }, { t: "me", v: 2 }]);
    expect(b.sent).toHaveLength(1);
    const c = await connect("u1");
    expect(c.sent[0].me).toBe(2);
  });

  it("limits pokeMe per socket: another device of the same uid is not dropped", async () => {
    vi.mocked(readDoc).mockResolvedValue({});
    const { hub, connect } = makeHub();
    const phone = await connect("u1");
    const laptop = await connect("u1");
    await hub.webSocketMessage(phone as any, JSON.stringify({ t: "pokeMe" }));
    vi.advanceTimersByTime(500);
    await hub.webSocketMessage(laptop as any, JSON.stringify({ t: "pokeMe" }));
    await hub.webSocketMessage(phone as any, JSON.stringify({ t: "pokeMe" })); // same socket, too soon
    expect(phone.sent.slice(1)).toEqual([{ t: "me", v: 1 }, { t: "me", v: 2 }]);
  });

  it("drops a second pokeMe from the same socket within 2s", async () => {
    vi.mocked(readDoc).mockResolvedValue({});
    const { hub, connect } = makeHub();
    const a = await connect("u1");
    const b = await connect("u2");
    await hub.webSocketMessage(a as any, JSON.stringify({ t: "pokeMe" }));
    vi.advanceTimersByTime(1_999);
    await hub.webSocketMessage(a as any, JSON.stringify({ t: "pokeMe" }));
    await hub.webSocketMessage(b as any, JSON.stringify({ t: "pokeMe" }));
    expect(a.sent.slice(1)).toEqual([{ t: "me", v: 1 }]);
    expect(b.sent.slice(1)).toEqual([{ t: "me", v: 1 }]);
  });

  it("ignores frames over 1 KB", async () => {
    vi.mocked(readDoc).mockResolvedValue({});
    const { hub, connect } = makeHub();
    const ws = await connect("u1");
    await hub.webSocketMessage(ws as any, JSON.stringify({ t: "pokeMe", pad: "x".repeat(1024) }));
    expect(ws.sent).toHaveLength(1);
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
