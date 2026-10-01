import { describe, it, expect, vi, beforeEach } from "vitest";
import worker from "../src/index";
import { readDoc } from "../src/firestore";

vi.mock("../src/firestore", () => ({ readDoc: vi.fn() }));

const env = { PROJECT_ID: "p", FIREBASE_SA: "{}", ALLOWED_ORIGINS: "https://a.example,https://b.example" };
const store = new Map<string, Response>();
const ctx = { waitUntil: (p: Promise<unknown>) => void p.catch(() => {}) } as unknown as ExecutionContext;
const call = (path: string, init?: RequestInit) =>
  worker.fetch(new Request("https://w.example" + path, init), env, ctx);

beforeEach(() => {
  store.clear();
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
    expect(a.headers.get("Cache-Control")).toBe("public, max-age=60");
    expect(await a.json()).toEqual({ goa: 3 });
    await new Promise((r) => setTimeout(r, 0));
    const b = await call("/heads/goa");
    expect(await b.json()).toEqual({ goa: 3 });
    expect(readDoc).toHaveBeenCalledTimes(1);
    expect(readDoc).toHaveBeenCalledWith("heads/goa", env);
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
