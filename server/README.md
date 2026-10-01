# pointer-heads

Cloudflare Worker that reads Firestore via the REST API using a service-account token.

## Owner setup

1. Create a service account with the **Datastore Viewer** role only (no write access).
2. `cd server && npx wrangler secret put FIREBASE_SA` — paste the full service-account JSON key when prompted.
3. `npx wrangler deploy`.

Staging (its own Worker, `pointer-heads-staging`) uses `[env.staging]` in `wrangler.toml`:
`npx wrangler secret put FIREBASE_SA --env staging` (a service account of the staging project), then `npx wrangler deploy --env staging`.

`PROJECT_ID` is per environment, in `wrangler.toml`: `cgpa-web` for production, `pointer-staging` for staging. It must match the Firebase project of the ID tokens and of the `FIREBASE_SA` key.

Note: the edge cache (`caches.default`) only works on a custom-domain route, not on `workers.dev`.

## Development

```
npm i
npx vitest run
```
