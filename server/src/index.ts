import { readDoc, type Env } from "./firestore";
import { verifyIdToken } from "./token";

export { CampusHub } from "./hub";

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

// Token rides in Sec-WebSocket-Protocol ("pointer, <idToken>"); the hub only ever sees the verified uid.
async function liveSocket(campus: string, req: Request, env: Env): Promise<Response> {
  if (!CAMPUSES.has(campus)) return new Response("not found", { status: 404 });
  if (req.headers.get("Upgrade") !== "websocket") return new Response("expected websocket", { status: 426 });
  const [proto, token] = (req.headers.get("Sec-WebSocket-Protocol") ?? "").split(",").map((s) => s.trim());
  if (proto !== "pointer" || !token) return new Response("unauthorized", { status: 401 });
  let uid: string;
  try {
    uid = (await verifyIdToken(token, env.PROJECT_ID)).uid;
  } catch {
    return new Response("unauthorized", { status: 401 });
  }
  const fwd = new Request(req);
  fwd.headers.set("X-Uid", uid);
  fwd.headers.set("Sec-WebSocket-Protocol", "pointer");
  return env.HUB.get(env.HUB.idFromName(campus)).fetch(fwd);
}

export default {
  async fetch(req: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    if (req.method === "OPTIONS") return withCors(new Response(null, { status: 204 }), req, env);
    const live = req.method === "GET" ? new URL(req.url).pathname.match(/^\/live\/([^/]+)$/) : null;
    if (live) return liveSocket(live[1], req, env);
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
