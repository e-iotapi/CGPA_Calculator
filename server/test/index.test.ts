import { describe, it, expect, vi, beforeEach } from "vitest";
import worker, { headMemo } from "../src/index";
import { readDoc } from "../src/firestore";

vi.mock("../src/firestore", () => ({ readDoc: vi.fn() }));

const env = { PROJECT_ID: "p", FIREBASE_SA: "{}", ALLOWED_ORIGINS: "https://a.example,https://b.example" } as any;
const store = new Map<string, Response>();
const ctx = { waitUntil: (p: Promise<unknown>) => void p.catch(() => {}) } as unknown as ExecutionContext;
const call = (path: string, init?: RequestInit) =>
  worker.fetch(new Request("https://w.example" + path, init), env, ctx);

beforeEach(() => {
  store.clear();
  headMemo.clear();
  vi.mocked(readDoc).mockReset();
  vi.stubGlobal("caches", {
    default: {
      match: async (r: Request) => store.get(r.url)?.clone(),
      put: async (r: Request, res: Response) => void store.set(r.url, res.clone()),
    },
  });
});

describe("GET /heads/:campus", () => {
  it("404s on an unknown campus", async () => {
    expect((await call("/heads/mars")).status).toBe(404);
    expect(readDoc).not.toHaveBeenCalled();
  });

  it("reads once, then serves from the cache", async () => {
    vi.mocked(readDoc).mockResolvedValue({ goa: 3 });
    const a = await call("/heads/goa");
    expect(a.status).toBe(200);
    expect(a.headers.get("Cache-Control")).toBe("max-age=0");
    await new Promise((r) => setTimeout(r, 0));
    expect(store.get("https://w.example/heads/goa")!.headers.get("Cache-Control")).toBe("public, max-age=60");
    expect(await a.json()).toEqual({ goa: 3 });
    await new Promise((r) => setTimeout(r, 0));
    const b = await call("/heads/goa");
    expect(await b.json()).toEqual({ goa: 3 });
    expect(readDoc).toHaveBeenCalledTimes(1);
    expect(readDoc).toHaveBeenCalledWith("heads/goa", env);
  });

  it("with no working edge cache, reads once a minute per campus", async () => {
    vi.mocked(readDoc).mockResolvedValue({ goa: 3 });
    vi.stubGlobal("caches", { default: { match: async () => undefined, put: async () => {} } });
    for (let i = 0; i < 5; i++) expect(await (await call("/heads/goa")).json()).toEqual({ goa: 3 });
    expect(readDoc).toHaveBeenCalledTimes(1);
    headMemo.get("goa")!.at -= 61_000;
    await call("/heads/goa");
    expect(readDoc).toHaveBeenCalledTimes(2);
  });

  it("answers {} for a missing doc", async () => {
    vi.mocked(readDoc).mockResolvedValue(null);
    expect(await (await call("/heads/pilani")).json()).toEqual({});
  });

  it("502s on a Firestore error and does not cache", async () => {
    vi.mocked(readDoc).mockRejectedValue(new Error("boom"));
    expect((await call("/heads/dubai")).status).toBe(502);
    await new Promise((r) => setTimeout(r, 0));
    expect(store.size).toBe(0);
  });

  it("echoes an allowed origin only", async () => {
    vi.mocked(readDoc).mockResolvedValue({});
    const ok = await call("/heads/goa", { headers: { Origin: "https://b.example" } });
    expect(ok.headers.get("Access-Control-Allow-Origin")).toBe("https://b.example");
    store.clear();
    const bad = await call("/heads/goa", { headers: { Origin: "https://evil.example" } });
    expect(bad.headers.get("Access-Control-Allow-Origin")).toBeNull();
    expect(bad.headers.get("Vary")).toContain("Origin");
  });

  it("does not leak one origin's CORS header to another via the cache", async () => {
    vi.mocked(readDoc).mockResolvedValue({});
    await call("/heads/goa", { headers: { Origin: "https://a.example" } });
    await new Promise((r) => setTimeout(r, 0));
    const b = await call("/heads/goa", { headers: { Origin: "https://b.example" } });
    expect(b.headers.get("Access-Control-Allow-Origin")).toBe("https://b.example");
  });

  it("answers OPTIONS with 204", async () => {
    const r = await call("/heads/goa", { method: "OPTIONS", headers: { Origin: "https://a.example" } });
    expect(r.status).toBe(204);
    expect(r.headers.get("Access-Control-Allow-Origin")).toBe("https://a.example");
  });
});

describe("GET /live/:campus", () => {
  const verify = vi.hoisted(() => vi.fn());
  vi.mock("../src/token", () => ({ verifyIdToken: verify }));
  const fetchHub = vi.fn(async (_r: Request) => new Response("hub"));
  const hubEnv = {
    ...env,
    HUB: { idFromName: (n: string) => n, get: () => ({ fetch: fetchHub }) },
  } as any;
  const live = (path: string, headers: Record<string, string>) =>
    worker.fetch(new Request("https://w.example" + path, { headers }), hubEnv, ctx);
  const ws = { Upgrade: "websocket", "Sec-WebSocket-Protocol": "pointer, tok" };
  beforeEach(() => {
    verify.mockReset();
    fetchHub.mockClear();
  });

  it("404s on an unknown campus, 426s without an upgrade", async () => {
    expect((await live("/live/mars", ws)).status).toBe(404);
    expect((await live("/live/goa", { "Sec-WebSocket-Protocol": "pointer, tok" })).status).toBe(426);
  });

  it("401s on a missing or bad token", async () => {
    expect((await live("/live/goa", { Upgrade: "websocket", "Sec-WebSocket-Protocol": "pointer" })).status).toBe(401);
    verify.mockRejectedValue(new Error("bad token"));
    expect((await live("/live/goa", ws)).status).toBe(401);
    expect(fetchHub).not.toHaveBeenCalled();
  });

  it("forwards to the campus hub with X-Uid, overriding a spoofed one, without the token", async () => {
    verify.mockResolvedValue({ uid: "u9" });
    const r = await live("/live/goa", { ...ws, "X-Uid": "evil" });
    expect(await r.text()).toBe("hub");
    expect(verify).toHaveBeenCalledWith("tok", "p");
    const fwd = fetchHub.mock.calls[0][0];
    expect(fwd.headers.get("X-Uid")).toBe("u9");
    expect(fwd.headers.get("Sec-WebSocket-Protocol")).toBe("pointer");
    expect(new URL(fwd.url).pathname).toBe("/live/goa");
  });
});
