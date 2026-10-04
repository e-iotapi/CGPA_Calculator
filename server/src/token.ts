// Verifies Firebase Auth ID tokens (RS256 JWTs) with Web Crypto against
// Google's published JWKS; no JWT library needed.

const JWKS_URL = "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com";

interface Jwks {
  keys: (JsonWebKey & { kid: string })[];
}

// ponytail: per-isolate cache; an unknown kid after rotation waits for max-age expiry.
let jwksCache: { jwks: Jwks; expiresAt: number } | null = null;

const bad = (reason: string) => new Error(`bad token: ${reason}`);

function decode(part: string): Uint8Array {
  const b64 = part.replace(/-/g, "+").replace(/_/g, "/");
  const bin = atob(b64 + "=".repeat((4 - (b64.length % 4)) % 4));
  return Uint8Array.from(bin, (c) => c.charCodeAt(0));
}

const decodeJson = (part: string) => JSON.parse(new TextDecoder().decode(decode(part)));

async function getJwks(now: number): Promise<Jwks> {
  if (jwksCache && jwksCache.expiresAt > now) return jwksCache.jwks;
  const res = await fetch(JWKS_URL);
  if (!res.ok) throw bad(`jwks fetch ${res.status}`);
  const jwks = (await res.json()) as Jwks;
  const maxAge = Number(/max-age=(\d+)/.exec(res.headers.get("Cache-Control") ?? "")?.[1] ?? 0);
  jwksCache = { jwks, expiresAt: now + maxAge * 1000 };
  return jwks;
}

export async function verifyIdToken(
  token: string,
  projectId: string,
  now: number = Date.now()
): Promise<{ uid: string; email?: string }> {
  const parts = token.split(".");
  if (parts.length !== 3) throw bad("malformed");
  let header: { alg?: string; kid?: string };
  let claims: Record<string, any>;
  try {
    header = decodeJson(parts[0]);
    claims = decodeJson(parts[1]);
  } catch {
    throw bad("malformed");
  }
  if (header.alg !== "RS256") throw bad("alg");

  const jwk = (await getJwks(now)).keys.find((k) => k.kid === header.kid);
  if (!jwk) throw bad("kid");
  const key = await crypto.subtle.importKey(
    "jwk",
    jwk,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["verify"]
  );
  const ok = await crypto.subtle.verify(
    "RSASSA-PKCS1-v1_5",
    key,
    decode(parts[2]),
    new TextEncoder().encode(`${parts[0]}.${parts[1]}`)
  );
  if (!ok) throw bad("signature");

  const sec = now / 1000;
  if (claims.iss !== `https://securetoken.google.com/${projectId}`) throw bad("iss");
  if (claims.aud !== projectId) throw bad("aud");
  if (typeof claims.exp !== "number" || claims.exp <= sec) throw bad("expired");
  if (typeof claims.iat !== "number" || claims.iat > sec + 300) throw bad("iat");
  if (typeof claims.sub !== "string" || !claims.sub) throw bad("sub");

  return { uid: claims.sub, email: claims.email };
}
