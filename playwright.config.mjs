// DRAFT, not run yet.
import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "a11y",
  testMatch: "*.spec.mjs",
  use: { baseURL: "http://127.0.0.1:4173" },
  webServer: { command: "node a11y/serve.mjs", url: "http://127.0.0.1:4173", reuseExistingServer: false },
});
