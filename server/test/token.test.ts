import { describe, it, expect, beforeEach, vi } from "vitest";

const PROJECT = "demo-proj";
const NOW = Date.parse("2026-01-01T00:00:00Z");
const SEC = Math.floor(NOW / 1000);

function b64url(data: string | ArrayBuffer): string {
  const bytes = typeof data === "string" ? new TextEncoder().encode(data) : new Uint8Array(data);
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function genKey() {
  return crypto.subtle.generateKey(
    { name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" },
    true,
    ["sign", "verify"]
  );
}

async function sign(priv: CryptoKey, claims: Record<string, unknown>, kid = "k1"): Promise<string> {
  const input = `${b64url(JSON.stringify({ alg: "RS256", kid, typ: "JWT" }))}.${b64url(JSON.stringify(claims))}`;
  const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", priv, new TextEncoder().encode(input));
  return `${input}.${b64url(sig)}`;
}

const good = (over: Record<string, unknown> = {}) => ({
  iss: `https://securetoken.google.com/${PROJECT}`,
  aud: PROJECT,
  sub: "uid-1",
  email: "a@b.c",
  iat: SEC - 10,
  exp: SEC + 3600,
  ...over,
});

async function setup() {
  const kp = await genKey();
  const jwk = { ...(await crypto.subtle.exportKey("jwk", kp.publicKey)), kid: "k1", alg: "RS256", use: "sig" };
  const fetchMock = vi.fn(
    async () =>
      new Response(JSON.stringify({ keys: [jwk] }), { status: 200, headers: { "Cache-Control": "public, max-age=3600" } })
  );
  vi.stubGlobal("fetch", fetchMock);
  const { verifyIdToken } = await import("../src/token");
  return { kp, fetchMock, verifyIdToken };
}

describe("verifyIdToken", () => {
  beforeEach(() => {
    vi.resetModules();
    vi.restoreAllMocks();
  });

  it("accepts a valid token and returns uid + email", async () => {
    const { kp, verifyIdToken } = await setup();
    const t = await sign(kp.privateKey, good());
    expect(await verifyIdToken(t, PROJECT, NOW)).toEqual({ uid: "uid-1", email: "a@b.c" });
  });

  it("rejects an expired token", async () => {
    const { kp, verifyIdToken } = await setup();
    const t = await sign(kp.privateKey, good({ exp: SEC - 1 }));
    await expect(verifyIdToken(t, PROJECT, NOW)).rejects.toThrow(/bad token: expired/);
  });

  it("rejects a wrong audience", async () => {
    const { kp, verifyIdToken } = await setup();
    const t = await sign(kp.privateKey, good({ aud: "other" }));
    await expect(verifyIdToken(t, PROJECT, NOW)).rejects.toThrow(/bad token: aud/);
  });

  it("rejects a wrong issuer", async () => {
    const { kp, verifyIdToken } = await setup();
    const t = await sign(kp.privateKey, good({ iss: "https://securetoken.google.com/other" }));
    await expect(verifyIdToken(t, PROJECT, NOW)).rejects.toThrow(/bad token: iss/);
  });

  it("rejects an iat too far in the future and an empty sub", async () => {
    const { kp, verifyIdToken } = await setup();
    await expect(verifyIdToken(await sign(kp.privateKey, good({ iat: SEC + 301 })), PROJECT, NOW)).rejects.toThrow(
      /bad token: iat/
    );
    await expect(verifyIdToken(await sign(kp.privateKey, good({ sub: "" })), PROJECT, NOW)).rejects.toThrow(
      /bad token: sub/
    );
  });

  it("rejects a bad signature (signed by a different key)", async () => {
    const { verifyIdToken } = await setup();
    const other = await genKey();
    const t = await sign(other.privateKey, good());
    await expect(verifyIdToken(t, PROJECT, NOW)).rejects.toThrow(/bad token: signature/);
  });

  it("rejects an unknown kid and malformed tokens", async () => {
    const { kp, verifyIdToken } = await setup();
    await expect(verifyIdToken(await sign(kp.privateKey, good(), "nope"), PROJECT, NOW)).rejects.toThrow(/bad token: kid/);
    await expect(verifyIdToken("garbage", PROJECT, NOW)).rejects.toThrow(/bad token/);
  });

  it("caches the JWKS per max-age", async () => {
    const { kp, fetchMock, verifyIdToken } = await setup();
    const t = await sign(kp.privateKey, good({ exp: SEC + 7200 }));
    await verifyIdToken(t, PROJECT, NOW);
    await verifyIdToken(t, PROJECT, NOW + 1000);
    expect(fetchMock).toHaveBeenCalledTimes(1);
    await verifyIdToken(t, PROJECT, NOW + 3600_000 + 1);
    expect(fetchMock).toHaveBeenCalledTimes(2);
  });
});
