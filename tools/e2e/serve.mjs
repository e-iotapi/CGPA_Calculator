// A plain static server for the Flutter web build, with an SPA fallback
// (usePathUrlStrategy means routes like /representatives have no matching
// file) so Playwright can navigate straight to any of the app's paths.
import { createServer } from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '..',
  '..',
  'build',
  'web',
);
const port = Number(process.env.PORT ?? 5050);

const mime = {
  '.html': 'text/html',
  '.js': 'application/javascript',
  '.mjs': 'application/javascript',
  '.json': 'application/json',
  '.css': 'text/css',
  '.wasm': 'application/wasm',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.webp': 'image/webp',
  '.woff2': 'font/woff2',
  '.ttf': 'font/ttf',
};

createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);
  let filePath = path.join(root, decodeURIComponent(url.pathname));
  try {
    if ((await stat(filePath)).isDirectory()) {
      filePath = path.join(filePath, 'index.html');
    }
  } catch {
    filePath = path.join(root, 'index.html');
  }
  try {
    const data = await readFile(filePath);
    res.writeHead(200, {
      'Content-Type': mime[path.extname(filePath)] ?? 'application/octet-stream',
    });
    res.end(data);
  } catch {
    res.writeHead(404);
    res.end('Not found');
  }
}).listen(port, '127.0.0.1', () => {
  console.log(`Serving ${root} on http://127.0.0.1:${port}`);
});
