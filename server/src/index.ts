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
  }
  out.headers.append("Vary", "Origin");
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

const HEAD_MEMO_MS = 60_000;
export const headMemo = new Map<string, { body: string; at: number }>();

export default {
  async fetch(req: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    if (req.method === "OPTIONS") return withCors(new Response(null, { status: 204 }), req, env);
    const live = req.method === "GET" ? new URL(req.url).pathname.match(/^\/live\/([^/]+)$/) : null;
    if (live) return liveSocket(live[1], req, env);
    const m = req.method === "GET" ? new URL(req.url).pathname.match(/^\/heads\/([^/]+)$/) : null;
    if (!m || !CAMPUSES.has(m[1])) return withCors(new Response("not found", { status: 404 }), req, env);

    // In-isolate memo first, so Firestore reads stay bounded at about one a minute per isolate
    // and campus even where caches.default is a no-op (workers.dev).
    const reply = (body: string) =>
      withCors(new Response(body, { headers: { "Content-Type": "application/json", "Cache-Control": "max-age=0" } }), req, env);
    const memo = headMemo.get(m[1]);
    if (memo && Date.now() - memo.at < HEAD_MEMO_MS) return reply(memo.body);

    const cache = caches.default;
    const key = new Request(new URL(req.url).origin + `/heads/${m[1]}`);
    const hit = await cache.match(key);
    if (hit) {
      const body = await hit.text();
      headMemo.set(m[1], { body, at: Date.now() });
      return reply(body);
    }

    let doc: Record<string, unknown> | null;
    try {
      doc = await readDoc(`heads/${m[1]}`, env);
    } catch {
      return withCors(new Response("upstream error", { status: 502 }), req, env);
    }
    const body = JSON.stringify(doc ?? {});
    headMemo.set(m[1], { body, at: Date.now() });
    // The edge copy lives 60 s; the browser is told max-age=0 so it always asks the edge.
    ctx.waitUntil(
      cache.put(key, new Response(body, { headers: { "Content-Type": "application/json", "Cache-Control": "public, max-age=60" } }))
    );
    return reply(body);
  },
};
