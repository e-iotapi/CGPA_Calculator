# pointer-heads

Cloudflare Worker that reads Firestore via the REST API using a service-account token.

## Owner setup

1. Create a service account with the **Datastore Viewer** role only (no write access).
2. `cd server && npx wrangler secret put FIREBASE_SA` — paste the full service-account JSON key when prompted.
3. `npx wrangler deploy`.

## Development

```
npm i
npx vitest run
```
