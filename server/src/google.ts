// Mints and caches a Google OAuth2 access token for a service account using
// the RS256 JWT-bearer flow (no external JWT library needed — Workers ship
// Web Crypto, which is all RS256 signing requires).

interface ServiceAccountJson {
  client_email: string;
  private_key: string;
}

interface TokenCache {
  token: string;
  expiresAt: number; // ms epoch
}

let cache: TokenCache | null = null;

function base64url(bytes: ArrayBuffer | string): string {
  const data = typeof bytes === "string" ? new TextEncoder().encode(bytes) : new Uint8Array(bytes);
  let binary = "";
  for (const byte of data) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem.replace(/-----BEGIN PRIVATE KEY-----/, "").replace(/-----END PRIVATE KEY-----/, "").replace(/\s+/g, "");
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

async function signJwt(sa: ServiceAccountJson, now: number): Promise<string> {
  const iat = Math.floor(now / 1000);
  const exp = iat + 3600;
  const encodedHeader = base64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const encodedClaims = base64url(
    JSON.stringify({
      iss: sa.client_email,
      scope: "https://www.googleapis.com/auth/datastore",
      aud: "https://oauth2.googleapis.com/token",
      iat,
      exp,
    })
  );
  const signingInput = `${encodedHeader}.${encodedClaims}`;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const signature = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(signingInput));
  return `${signingInput}.${base64url(signature)}`;
}

export async function getAccessToken(saJson: string, now: number = Date.now()): Promise<string> {
  if (cache && cache.expiresAt - 60_000 > now) {
    return cache.token;
  }

  const sa: ServiceAccountJson = JSON.parse(saJson);
  const assertion = await signJwt(sa, now);

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!res.ok) {
    throw new Error(`token request failed: ${res.status}`);
  }

  const data = (await res.json()) as { access_token: string; expires_in: number };
  cache = { token: data.access_token, expiresAt: now + data.expires_in * 1000 };
  return cache.token;
}
