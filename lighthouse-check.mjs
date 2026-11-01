// DRAFT, not run yet. Should-pass gate, on mobile: 90+ in all four categories, LCP 2.5 s or less, CLS 0.1 or less.
// A miss exits 1; the workflow logs it and never blocks, and the reviewer writes a reason.
import lighthouse from "lighthouse";
import * as chromeLauncher from "chrome-launcher";
import { server, PORT } from "./a11y/serve.mjs";

await new Promise((resolve) => server.listen(PORT, "127.0.0.1", resolve));
const chrome = await chromeLauncher.launch({ chromeFlags: ["--headless=new", "--no-sandbox"] });
let misses = [];
try {
  const { lhr } = await lighthouse(`http://127.0.0.1:${PORT}/`, {
    port: chrome.port,
    output: "json",
    onlyCategories: ["performance", "accessibility", "best-practices", "seo"],
  });
  for (const [name, category] of Object.entries(lhr.categories)) {
    const score = Math.round((category.score ?? 0) * 100);
    console.log(`${name}: ${score}`);
    if (score < 90) misses.push(`${name} ${score}`);
  }
  const lcp = lhr.audits["largest-contentful-paint"].numericValue;
  const cls = lhr.audits["cumulative-layout-shift"].numericValue;
  console.log(`LCP: ${Math.round(lcp)} ms, CLS: ${cls}`);
  if (lcp > 2500) misses.push(`LCP ${Math.round(lcp)} ms`);
  if (cls > 0.1) misses.push(`CLS ${cls}`);
} finally {
  await chrome.kill();
  server.close();
}
if (misses.length) {
  console.log(`Below target: ${misses.join(", ")}`);
  process.exit(1);
}
