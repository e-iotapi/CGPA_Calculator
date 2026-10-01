import { readDoc, type Env } from "./firestore";

const CAMPUSES = new Set(["goa", "hyderabad", "pilani", "dubai"]);

// CORS is added per request, after the cache, so cached bodies are origin-agnostic.
function withCors(res: Response, req: Request, env: Env): Response {
  const out = new Response(res.body, res);
  const origin = req.headers.get("Origin");
  if (origin && (env.ALLOWED_ORIGINS ?? "").split(",").map((s) => s.trim()).includes(origin)) {
    out.headers.set("Access-Control-Allow-Origin", origin);
    out.headers.set("Access-Control-Allow-Methods", "GET, OPTIONS");
    out.headers.append("Vary", "Origin");
  }
  return out;
}

export default {
  async fetch(req: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    if (req.method === "OPTIONS") return withCors(new Response(null, { status: 204 }), req, env);
    const m = req.method === "GET" ? new URL(req.url).pathname.match(/^\/heads\/([^/]+)$/) : null;
    if (!m || !CAMPUSES.has(m[1])) return withCors(new Response("not found", { status: 404 }), req, env);

    const cache = caches.default;
    const key = new Request(new URL(req.url).origin + `/heads/${m[1]}`);
    const hit = await cache.match(key);
    if (hit) return withCors(hit, req, env);

    let doc: Record<string, unknown> | null;
    try {
      doc = await readDoc(`heads/${m[1]}`, env);
    } catch {
      return withCors(new Response("upstream error", { status: 502 }), req, env);
    }
    const res = new Response(JSON.stringify(doc ?? {}), {
      headers: { "Content-Type": "application/json", "Cache-Control": "public, max-age=60" },
    });
    ctx.waitUntil(cache.put(key, res.clone()));
    return withCors(res, req, env);
  },
};
