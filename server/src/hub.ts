import { DurableObject } from "cloudflare:workers";
import { readDoc, type Env } from "./firestore";

type Versions = Record<string, number>;

const HEAD_TTL_MS = 60_000;
const ALARM_DELAY_MS = 1_500;
const POKE_GAP_MS = 2_000;

/** Paths in `next` whose version differs from `prev` (new paths count as moved). */
export function diffVersions(prev: Versions, next: Versions): Versions {
  const out: Versions = {};
  for (const [k, v] of Object.entries(next)) if (prev[k] !== v) out[k] = v;
  return out;
}

/** True (and records `now`) if `key` has not been admitted in the last `gap` ms. */
export function allow(seen: Map<string, number>, key: string, now: number, gap: number): boolean {
  const t = seen.get(key);
  if (t !== undefined && now - t < gap) return false;
  seen.set(key, now);
  return true;
}

const numbersOnly = (d: Record<string, unknown> | null): Versions =>
  Object.fromEntries(Object.entries(d ?? {}).filter(([, v]) => typeof v === "number")) as Versions;

export class CampusHub extends DurableObject<Env> {
  private cache: { head: Versions; at: number } | null = null;
  private last: Versions | null = null; // what clients were last told
  private pokes = new Map<string, number>();

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
    const now = Date.now();
    if (this.cache && now - this.cache.at < HEAD_TTL_MS) head = this.cache.head;
    else {
      try {
        head = numbersOnly(await readDoc(`heads/${campus}`, this.env));
      } catch {
        head = this.cache?.head ?? {};
      }
      this.cache = { head, at: now };
    }
    this.last ??= (await this.ctx.storage.get<Versions>("last")) ?? head;
    ws.send(JSON.stringify({ t: "hello", head, me: this.me(uid) }));
  }

  private me(uid: string): number {
    const rows = this.ctx.storage.sql.exec("SELECT v FROM users WHERE uid = ?", uid).toArray();
    return rows.length ? Number(rows[0].v) : 0;
  }

  async webSocketMessage(ws: WebSocket, raw: string | ArrayBuffer): Promise<void> {
    if (typeof raw !== "string") return;
    let msg: { t?: unknown; path?: unknown };
    try {
      msg = JSON.parse(raw);
    } catch {
      return;
    }
    if (msg.t === "poke" && typeof msg.path === "string" && msg.path.length <= 256) {
      const now = Date.now();
      if (!allow(this.pokes, msg.path, now, POKE_GAP_MS)) return;
      if ((await this.ctx.storage.getAlarm()) === null) await this.ctx.storage.setAlarm(now + ALARM_DELAY_MS);
    } else if (msg.t === "pokeMe") {
      const uid = this.ctx.getTags(ws)[0];
      this.ctx.storage.sql.exec(
        "INSERT INTO users (uid, v) VALUES (?, 1) ON CONFLICT(uid) DO UPDATE SET v = v + 1",
        uid
      );
      const out = JSON.stringify({ t: "me", v: this.me(uid) });
      for (const s of this.ctx.getWebSockets(uid)) s.send(out);
    }
  }

  async alarm(): Promise<void> {
    const campus = await this.ctx.storage.get<string>("campus");
    if (!campus) return;
    let next: Versions;
    try {
      next = numbersOnly(await readDoc(`heads/${campus}`, this.env));
    } catch {
      return; // ponytail: no retry; the next poke re-arms the alarm
    }
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
