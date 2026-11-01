// DRAFT, not run yet. Must-pass gate: axe finds nothing serious or critical against WCAG 2.2 AA.
import { test, expect } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";

test("the page has no serious or critical accessibility findings", async ({ page }) => {
  await page.goto("/");
  const results = await new AxeBuilder({ page })
    .withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa", "wcag22aa"])
    .analyze();
  const blocking = results.violations.filter((v) => v.impact === "serious" || v.impact === "critical");
  expect(blocking.map((v) => v.id)).toEqual([]);
});
