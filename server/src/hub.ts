import { DurableObject } from "cloudflare:workers";
import { readDoc, type Env } from "./firestore";

type Versions = Record<string, number>;

const HEAD_TTL_MS = 60_000;
const ALARM_DELAY_MS = 1_500;
const MIN_READ_GAP_MS = 5_000;
const RETRY_MS = 5_000;
const POKE_ME_GAP_MS = 2_000;
const MAX_FRAME = 1024;
const MAX_RETRIES = 3;

/** Paths in `next` whose version differs from `prev` (new paths count as moved). */
export function diffVersions(prev: Versions, next: Versions): Versions {
  const out: Versions = {};
  for (const [k, v] of Object.entries(next)) if (prev[k] !== v) out[k] = v;
  return out;
}

/** The head doc's `v` map (marker path -> version), numbers only; other head fields never leave. */
const markers = (d: Record<string, unknown> | null): Versions => {
  const v = d?.v;
  if (!v || typeof v !== "object") return {};
  return Object.fromEntries(Object.entries(v).filter(([, n]) => typeof n === "number")) as Versions;
};

export class CampusHub extends DurableObject<Env> {
  private cache: { head: Versions; at: number } | null = null;
  private last: Versions | null = null; // what clients were last told
  private armed = false; // an alarm is pending (in memory; re-checked via getAlarm after hibernation)
  private lastReadAt = 0;
  private retries = 0;
  private pokeMeAt = new Map<string, number>(); // uid -> last admitted pokeMe

  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    ctx.storage.sql.exec("CREATE TABLE IF NOT EXISTS users (uid TEXT PRIMARY KEY, v INTEGER NOT NULL DEFAULT 0)");
  }

  async fetch(req: Request): Promise<Response> {
    const campus = new URL(req.url).pathname.split("/").pop()!;
    const uid = req.headers.get("X-Uid");
    if (!uid || req.headers.get("Upgrade") !== "websocket") return new Response("expected websocket", { status: 426 });
    const { 0: client, 1: server } = new WebSocketPair();
    this.ctx.acceptWebSocket(server, [uid]);
    await this.sendHello(server, uid, campus);
    return new Response(null, { status: 101, webSocket: client, headers: { "Sec-WebSocket-Protocol": "pointer" } });
  }

  async sendHello(ws: WebSocket, uid: string, campus: string): Promise<void> {
    await this.ctx.storage.put("campus", campus);
    let head: Versions;
    let good: Versions | null = null; // a head that really came from Firestore
    const now = Date.now();
    if (this.cache && now - this.cache.at < HEAD_TTL_MS) head = good = this.cache.head;
    else {
      try {
        head = good = markers(await readDoc(`heads/${campus}`, this.env));
        this.cache = { head, at: now };
      } catch {
        head = this.cache?.head ?? {};
      }
    }
    this.last ??= (await this.ctx.storage.get<Versions>("last")) ?? good;
    ws.send(JSON.stringify({ t: "hello", head, me: this.me(uid) }));
  }

  private me(uid: string): number {
    const rows = this.ctx.storage.sql.exec("SELECT v FROM users WHERE uid = ?", uid).toArray();
    return rows.length ? Number(rows[0].v) : 0;
  }

  async webSocketMessage(ws: WebSocket, raw: string | ArrayBuffer): Promise<void> {
    if (typeof raw !== "string" || raw.length > MAX_FRAME) return;
    let msg: { t?: unknown; path?: unknown };
    try {
      msg = JSON.parse(raw);
    } catch {
      return;
    }
    if (msg.t === "poke" && typeof msg.path === "string" && msg.path.length <= 256) {
      // ponytail: reads are capped at one per MIN_READ_GAP_MS (~17k/day per campus under abuse); no per-path limit
      if (this.armed) return;
      this.armed = true;
      if ((await this.ctx.storage.getAlarm()) !== null) return;
      const now = Date.now();
      await this.ctx.storage.setAlarm(Math.max(now + ALARM_DELAY_MS, this.lastReadAt + MIN_READ_GAP_MS));
    } else if (msg.t === "pokeMe") {
      const uid = this.ctx.getTags(ws)[0];
      const now = Date.now();
      if (now - (this.pokeMeAt.get(uid) ?? -Infinity) < POKE_ME_GAP_MS) return;
      if (this.pokeMeAt.size > 1000) this.pokeMeAt.clear(); // ponytail: crude bound; resets limits for everyone
      this.pokeMeAt.set(uid, now);
      this.ctx.storage.sql.exec(
        "INSERT INTO users (uid, v) VALUES (?, 1) ON CONFLICT(uid) DO UPDATE SET v = v + 1",
        uid
      );
      const out = JSON.stringify({ t: "me", v: this.me(uid) });
      for (const s of this.ctx.getWebSockets(uid)) s.send(out);
    }
  }

  async alarm(): Promise<void> {
    this.armed = false;
    this.lastReadAt = Date.now();
    const campus = await this.ctx.storage.get<string>("campus");
    if (!campus) return;
    let next: Versions;
    try {
      next = markers(await readDoc(`heads/${campus}`, this.env));
    } catch {
      if (this.retries++ < MAX_RETRIES) {
        this.armed = true;
        await this.ctx.storage.setAlarm(Date.now() + RETRY_MS);
      }
      return;
    }
    this.retries = 0;
    this.cache = { head: next, at: Date.now() };
    const prev = this.last ?? (await this.ctx.storage.get<Versions>("last")) ?? {};
    const diff = diffVersions(prev, next);
    this.last = next;
    await this.ctx.storage.put("last", next);
    if (!Object.keys(diff).length) return;
    const out = JSON.stringify({ t: "head", v: diff });
    for (const s of this.ctx.getWebSockets()) s.send(out);
  }

  webSocketClose(ws: WebSocket, code: number): void {
    try {
      ws.close(code === 1005 ? 1000 : code);
    } catch {}
  }
}
