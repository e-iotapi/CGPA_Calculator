// The broadcast timetable (B8b): merge the Firestore meta + chunk docs into
// the one public JSON, and render the academic dates and exam slots as .ics.
import { readDoc, type Env } from "./firestore";

type Json = Record<string, any>;

/** The merged file the app reads, or null when nothing is published. */
export async function loadTimetable(campus: string, env: Env): Promise<Json | null> {
  const cur = await readDoc(`timetable/${campus}|current`, env);
  if (!cur || typeof cur.sem !== "string") return null;
  const base = `${campus}|${cur.sem}`;
  const meta = await readDoc(`timetable/${base}`, env);
  if (!meta) return null;
  const n = Number(meta.chunks ?? 0);
  const chunks = await Promise.all(Array.from({ length: n }, (_, i) => readDoc(`timetable/${base}|${i}`, env)));
  const courses: Json = {};
  for (const c of chunks) Object.assign(courses, (c?.courses as Json) ?? {});
  return {
    v: 1,
    campus,
    sem: meta.sem,
    publishedAt: typeof meta.publishedAt === "string" ? Date.parse(meta.publishedAt) : Number(meta.publishedAt ?? 0),
    marker: Number(meta.marker ?? cur.marker ?? 0),
    hours: meta.hours ?? {},
    examSlots: meta.examSlots ?? {},
    events: meta.events ?? [],
    courses,
  };
}

// ---- RFC 5545 ------------------------------------------------------------

const enc = new TextEncoder();

/** TEXT escaping: backslash, semicolon, comma, newline. */
export const esc = (s: string) => s.replace(/\\/g, "\\\\").replace(/;/g, "\\;").replace(/,/g, "\\,").replace(/\r?\n/g, "\\n");

/** One content line folded at 75 octets (never inside a character), CRLF-joined continuation. */
export function fold(line: string): string {
  const out: string[] = [];
  let cur = "";
  let bytes = 0;
  for (const ch of line) {
    const w = enc.encode(ch).length;
    if (bytes + w > (out.length ? 74 : 75)) {
      out.push(cur);
      cur = "";
      bytes = 0;
    }
    cur += ch;
    bytes += w;
  }
  out.push(cur);
  return out.join("\r\n ");
}

const ymd = (d: string) => d.replace(/-/g, "");
const stamp = (ms: number) => new Date(ms).toISOString().replace(/[-:]|\.\d{3}/g, "");
const nextDay = (d: string) => new Date(Date.parse(d + "T00:00:00Z") + 864e5).toISOString().slice(0, 10);
const hhmm = (m: number) => String(Math.floor(m / 60)).padStart(2, "0") + String(m % 60).padStart(2, "0") + "00";

async function sha1(s: string): Promise<string> {
  const h = await crypto.subtle.digest("SHA-1", enc.encode(s));
  return [...new Uint8Array(h)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

const TZ = [
  "BEGIN:VTIMEZONE",
  "TZID:Asia/Kolkata",
  "BEGIN:STANDARD",
  "DTSTART:19700101T000000",
  "TZOFFSETFROM:+0530",
  "TZOFFSETTO:+0530",
  "TZNAME:IST",
  "END:STANDARD",
  "END:VTIMEZONE",
];

export async function toIcs(t: Json): Promise<string> {
  const stampNow = stamp(Number(t.publishedAt) || 0);
  const name = String(t.campus).charAt(0).toUpperCase() + String(t.campus).slice(1);
  const lines = [
    "BEGIN:VCALENDAR",
    "VERSION:2.0",
    "PRODID:-//Pointer//Campus Calendar//EN",
    "CALSCALE:GREGORIAN",
    `X-WR-CALNAME:${esc(`${name} academic calendar ${t.sem}`)}`,
    "REFRESH-INTERVAL;VALUE=DURATION:P1D",
    "X-PUBLISHED-TTL:P1D",
    ...TZ,
  ];
  for (const e of (t.events ?? []) as Json[]) {
    const to = e.to ?? e.from;
    lines.push(
      "BEGIN:VEVENT",
      `UID:${t.campus}-${t.sem}-${await sha1(`${e.from}|${e.title}`)}@pointer`,
      `DTSTAMP:${stampNow}`,
      `DTSTART;VALUE=DATE:${ymd(e.from)}`,
      `DTEND;VALUE=DATE:${ymd(nextDay(to))}`,
      `SUMMARY:${esc(String(e.title))}`,
      `CATEGORIES:${esc(String(e.kind))}`,
      "END:VEVENT",
    );
  }
  for (const [id, c] of Object.entries((t.courses ?? {}) as Json)) {
    for (const [tag, label, x] of [["mid", "Midsem", c.mid], ["comp", "Compre", c.compre]] as const) {
      if (!x) continue;
      lines.push(
        "BEGIN:VEVENT",
        `UID:${t.campus}-${t.sem}-${id.replace(/\s+/g, "-")}-${tag}@pointer`,
        `DTSTAMP:${stampNow}`,
        `DTSTART;TZID=Asia/Kolkata:${ymd(x.d)}T${hhmm(x.s)}`,
        `DTEND;TZID=Asia/Kolkata:${ymd(x.d)}T${hhmm(x.e)}`,
        `SUMMARY:${esc(`${id} ${label}`)}`,
        `DESCRIPTION:${esc(String(c.t ?? ""))}`,
        "CATEGORIES:exam",
        "END:VEVENT",
      );
    }
  }
  lines.push("END:VCALENDAR");
  return lines.map(fold).join("\r\n") + "\r\n";
}
