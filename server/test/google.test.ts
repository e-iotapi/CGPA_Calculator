import { describe, it, expect, beforeEach, vi } from "vitest";

async function makeServiceAccountJson(): Promise<{ saJson: string; email: string }> {
  const keyPair = await crypto.subtle.generateKey(
    { name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" },
    true,
    ["sign", "verify"]
  );
  const pkcs8 = await crypto.subtle.exportKey("pkcs8", keyPair.privateKey);
  const b64 = btoa(String.fromCharCode(...new Uint8Array(pkcs8)));
  const pem = `-----BEGIN PRIVATE KEY-----\n${b64.match(/.{1,64}/g)!.join("\n")}\n-----END PRIVATE KEY-----\n`;
  const email = "test@test.iam.gserviceaccount.com";
  return { saJson: JSON.stringify({ client_email: email, private_key: pem }), email };
}

function decodeBase64Url(s: string): string {
  const b64 = s.replace(/-/g, "+").replace(/_/g, "/");
  const padded = b64 + "=".repeat((4 - (b64.length % 4)) % 4);
  return atob(padded);
}

describe("getAccessToken", () => {
  beforeEach(() => {
    vi.resetModules();
    vi.restoreAllMocks();
  });

  it("builds an RS256 JWT with the right header and claims", async () => {
    const { saJson, email } = await makeServiceAccountJson();
    const fetchMock = vi.fn(async () =>
      new Response(JSON.stringify({ access_token: "tok-1", expires_in: 3600 }), { status: 200 })
    );
    vi.stubGlobal("fetch", fetchMock);

    const { getAccessToken } = await import("../src/google");
    const now = Date.parse("2026-01-01T00:00:00Z");
    const token = await getAccessToken(saJson, now);
    expect(token).toBe("tok-1");

    expect(fetchMock).toHaveBeenCalledTimes(1);
    const [url, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(url).toBe("https://oauth2.googleapis.com/token");

    const params = new URLSearchParams(init.body as any);
    expect(params.get("grant_type")).toBe("urn:ietf:params:oauth:grant-type:jwt-bearer");
    const assertion = params.get("assertion")!;
    const [headerB64, claimsB64] = assertion.split(".");
    const header = JSON.parse(decodeBase64Url(headerB64));
    const claims = JSON.parse(decodeBase64Url(claimsB64));

    expect(header).toEqual({ alg: "RS256", typ: "JWT" });
    expect(claims.iss).toBe(email);
    expect(claims.scope).toBe("https://www.googleapis.com/auth/datastore");
    expect(claims.aud).toBe("https://oauth2.googleapis.com/token");
    expect(claims.exp - claims.iat).toBe(3600);
  });

  it("caches the token until 60s before expiry (fetch called once for two calls)", async () => {
    const { saJson } = await makeServiceAccountJson();
    const fetchMock = vi.fn(async () =>
      new Response(JSON.stringify({ access_token: "tok-2", expires_in: 3600 }), { status: 200 })
    );
    vi.stubGlobal("fetch", fetchMock);

    const { getAccessToken } = await import("../src/google");
    const now = Date.parse("2026-01-01T00:00:00Z");
    const t1 = await getAccessToken(saJson, now);
    const t2 = await getAccessToken(saJson, now + 1000);

    expect(t1).toBe("tok-2");
    expect(t2).toBe("tok-2");
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it("refetches once the cached token is within 60s of expiry", async () => {
    const { saJson } = await makeServiceAccountJson();
    const fetchMock = vi.fn(async () =>
      new Response(JSON.stringify({ access_token: "tok-3", expires_in: 3600 }), { status: 200 })
    );
    vi.stubGlobal("fetch", fetchMock);

    const { getAccessToken } = await import("../src/google");
    const now = Date.parse("2026-01-01T00:00:00Z");
    await getAccessToken(saJson, now);
    await getAccessToken(saJson, now + 3600_000 - 59_000);

    expect(fetchMock).toHaveBeenCalledTimes(2);
  });
});
