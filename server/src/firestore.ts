import { getAccessToken } from "./google";

export interface Env {
  PROJECT_ID: string;
  FIREBASE_SA: string;
  ALLOWED_ORIGINS?: string;
  HUB: DurableObjectNamespace;
}

export type FirestoreValue =
  | { nullValue: null }
  | { booleanValue: boolean }
  | { integerValue: string }
  | { doubleValue: number }
  | { stringValue: string }
  | { timestampValue: string }
  | { mapValue: { fields?: Record<string, FirestoreValue> } }
  | { arrayValue: { values?: FirestoreValue[] } };

export interface FirestoreDoc {
  name?: string;
  fields?: Record<string, FirestoreValue>;
}

export function decodeValue(v: FirestoreValue): unknown {
  if ("nullValue" in v) return null;
  if ("booleanValue" in v) return v.booleanValue;
  if ("integerValue" in v) return Number(v.integerValue);
  if ("doubleValue" in v) return v.doubleValue;
  if ("stringValue" in v) return v.stringValue;
  if ("timestampValue" in v) return v.timestampValue;
  if ("mapValue" in v) {
    const fields = v.mapValue.fields ?? {};
    const out: Record<string, unknown> = {};
    for (const [k, fv] of Object.entries(fields)) out[k] = decodeValue(fv);
    return out;
  }
  if ("arrayValue" in v) {
    return (v.arrayValue.values ?? []).map(decodeValue);
  }
  return undefined;
}

export function decodeDoc(doc: FirestoreDoc): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(doc.fields ?? {})) out[k] = decodeValue(v);
  return out;
}

export async function readDoc(path: string, env: Env): Promise<Record<string, unknown> | null> {
  const token = await getAccessToken(env.FIREBASE_SA);
  const url = `https://firestore.googleapis.com/v1/projects/${env.PROJECT_ID}/databases/(default)/documents/${path}`;
  const res = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
  if (res.status === 404) return null;
  if (!res.ok) throw new Error(`firestore read failed: ${res.status}`);
  const doc = (await res.json()) as FirestoreDoc;
  return decodeDoc(doc);
}
