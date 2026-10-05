// Cloudflare Pages Function: a failed sign-in, sent by the app
// (lib/core/diag/sign_in_log.dart), written to this deployment's real-time
// logs with where it came from. Holds no address; stores nothing.
export async function onRequestPost({ request }) {
  const body = (await request.text()).slice(0, 2000);
  let entry;
  try {
    entry = JSON.parse(body);
  } catch {
    return new Response(null, { status: 400 });
  }
  const cf = request.cf ?? {};
  console.log(JSON.stringify({ signin: entry, country: cf.country, colo: cf.colo, asn: cf.asOrganization }));
  return new Response(null, { status: 204 });
}
