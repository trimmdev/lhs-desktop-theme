// Bake pixel-perfect wallpaper stills at any resolution.
//   npm i playwright   (browsers: npx playwright install chromium)
//   node tools/bake-stills.mjs [WxH ...]     e.g. node tools/bake-stills.mjs 3840x2160 1920x1080
// No args = the full standard set. Moods: pass --moods dusk,dawn,night,day (default dusk).
import { chromium } from "playwright";
import { pathToFileURL } from "url";
import { mkdirSync } from "fs";
import { dirname, join } from "path";
import { fileURLToPath } from "url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const html = join(root, "wallpaper", "lhs-dusk.html");
const out = join(root, "stills");
mkdirSync(out, { recursive: true });

const DEFAULT = ["1366x768","1600x900","1920x1080","1920x1200","2560x1080","2560x1440",
  "2560x1600","2880x1800","3440x1440","3840x1600","3840x2160","5120x1440","5120x2880",
  "7680x4320","1080x1920","1440x2560"];

const args = process.argv.slice(2);
const moodsIdx = args.indexOf("--moods");
const moods = moodsIdx >= 0 ? args.splice(moodsIdx, 2)[1].split(",") : ["dusk"];
const sizes = args.length ? args : DEFAULT;

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 100, height: 100 }, deviceScaleFactor: 1 });
for (const s of sizes) {
  const [w, h] = s.split("x").map(Number);
  for (const mood of moods) {
    await page.setViewportSize({ width: w, height: h });
    await page.goto(pathToFileURL(html).href + `?still=1${mood === "dusk" ? "" : `&mood=${mood}`}`);
    await page.waitForFunction("window.__ready === true", null, { timeout: 60000 });
    await page.screenshot({ path: join(out, `lhs-${mood}-${s}.png`) });
    console.log(`lhs-${mood}-${s}.png`);
  }
}
await browser.close();
