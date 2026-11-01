// DRAFT, not run yet. Serves public/ on this machine only, for the accessibility and Lighthouse checks.
import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { extname, join, normalize } from "node:path";

const TYPES = { ".html": "text/html; charset=utf-8", ".png": "image/png", ".css": "text/css", ".js": "text/javascript" };
export const PORT = 4173;

export const server = createServer(async (req, res) => {
  const path = normalize(new URL(req.url, "http://localhost").pathname);
  const file = join("public", path.endsWith("/") ? join(path, "index.html") : path);
  try {
    const body = await readFile(file);
    res.writeHead(200, { "content-type": TYPES[extname(file)] ?? "application/octet-stream" });
    res.end(body);
  } catch {
    res.writeHead(404);
    res.end();
  }
});

if (process.argv[1]?.endsWith("serve.mjs")) server.listen(PORT, "127.0.0.1");
