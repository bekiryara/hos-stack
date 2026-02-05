/* eslint-disable no-console */
/**
 * Backfill missing otomobil model lists using arabam.com GetFacets.
 *
 * Strategy (controlled):
 * - Read brands from `catalog/manifests/categories/vehicle-otomobil-brands.json`
 * - Read model dictionary `catalog/manifests/vehicle-otomobil-models.autoevolution.tr.json`
 * - For each brand slug where `brand_slug_to_models[slug]` is missing/empty:
 *     fetch `GetFacets?url=https://www.arabam.com/ikinci-el/otomobil/<brand>`
 *     extract `Data.Facets[0].SelectedCategory.SubCategories[*].Name` as models
 *     store sorted list back into `brand_slug_to_models[slug]`
 * - Update stats + unmatched list in the dictionary JSON.
 *
 * Usage (dry-run):
 *   node scripts/arabam-backfill-otomobil-models.js
 *
 * Apply (writes file):
 *   node scripts/arabam-backfill-otomobil-models.js --write
 */

const fs = require("fs");
const path = require("path");

const FACETS_ENDPOINT = "https://www.arabam.com/listing/GetFacets?url=";
const BRAND_PAGE_PREFIX = "https://www.arabam.com/ikinci-el/otomobil/";

function parseArgs(argv) {
  const out = { write: false };
  for (let i = 2; i < argv.length; i++) {
    if (argv[i] === "--write") out.write = true;
  }
  return out;
}

async function fetchJson(url, timeoutMs = 25000) {
  const ac = new AbortController();
  const t = setTimeout(() => ac.abort(), timeoutMs);
  try {
    const res = await fetch(url, {
      method: "GET",
      headers: {
        accept: "application/json,text/plain,*/*",
        "user-agent": "Mozilla/5.0 (compatible; catalog-import-bot/1.0)",
      },
      signal: ac.signal,
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    return await res.json();
  } finally {
    clearTimeout(t);
  }
}

function extractModelsFromGetFacets(data) {
  const d = data?.Data || data?.data || {};
  const sub = d?.Facets?.[0]?.SelectedCategory?.SubCategories || [];
  if (!Array.isArray(sub)) return [];
  const names = sub
    .map((x) => (typeof x?.Name === "string" ? x.Name.trim() : ""))
    .filter((x) => x.length > 0);
  // De-dup preserve order
  const seen = new Set();
  const out = [];
  for (const n of names) {
    if (seen.has(n)) continue;
    seen.add(n);
    out.push(n);
  }
  // Sort for stable UX
  out.sort((a, b) => a.localeCompare(b, "tr"));
  return out;
}

function nowIso() {
  return new Date().toISOString();
}

async function main() {
  const args = parseArgs(process.argv);
  const repoRoot = path.resolve(__dirname, "..");
  const manifestsRoot = path.join(repoRoot, "catalog", "manifests");
  const brandsPath = path.join(manifestsRoot, "categories", "vehicle-otomobil-brands.json");
  const dictPath = path.join(manifestsRoot, "vehicle-otomobil-models.autoevolution.tr.json");

  const brands = JSON.parse(fs.readFileSync(brandsPath, "utf8"));
  const dict = JSON.parse(fs.readFileSync(dictPath, "utf8"));
  const map = dict.brand_slug_to_models || {};
  if (typeof map !== "object" || Array.isArray(map) || map === null) {
    throw new Error("vehicle-otomobil-models...json must contain brand_slug_to_models object.");
  }

  const targets = [];
  for (const b of brands) {
    const slug = b?.slug;
    if (typeof slug !== "string" || !slug.startsWith("otomobil-")) continue;
    const arr = map[slug];
    if (Array.isArray(arr) && arr.length > 0) continue;
    targets.push({ slug, title: b?.title || slug });
  }

  console.log("brands_total=" + brands.length);
  console.log("targets_missing_models=" + targets.length);

  const filled = [];
  const failed = [];
  for (const t of targets) {
    const brandKey = t.slug.replace(/^otomobil-/, "");
    const pageUrl = BRAND_PAGE_PREFIX + brandKey;
    const reqUrl = FACETS_ENDPOINT + encodeURIComponent(pageUrl);
    try {
      const data = await fetchJson(reqUrl);
      const models = extractModelsFromGetFacets(data);
      if (models.length === 0) {
        failed.push({ slug: t.slug, title: t.title, reason: "no models in response" });
        continue;
      }
      map[t.slug] = models;
      filled.push({ slug: t.slug, title: t.title, count: models.length });
      console.log("filled " + t.slug + " count=" + models.length);
    } catch (e) {
      failed.push({ slug: t.slug, title: t.title, reason: e?.message || String(e) });
    }
  }

  // Recompute stats + unmatched list based on brand manifests
  const unmatched = [];
  let matchedCount = 0;
  let totalModels = 0;
  for (const b of brands) {
    const slug = b?.slug;
    if (typeof slug !== "string") continue;
    const arr = map[slug];
    const len = Array.isArray(arr) ? arr.length : 0;
    totalModels += len;
    if (len > 0) {
      matchedCount++;
    } else {
      unmatched.push({ slug, title: b?.title || slug });
    }
  }

  dict.brand_slug_to_models = map;
  dict.generated_at = nowIso();
  dict.stats = dict.stats || {};
  dict.stats.brands_matched = matchedCount;
  dict.stats.brands_unmatched = unmatched.length;
  dict.stats.automobiles_kept = totalModels;
  dict.stats.arabam_backfilled_brands = filled.length;
  dict.unmatched_tr_brands = unmatched;
  dict.notes = Array.isArray(dict.notes) ? dict.notes : [];
  dict.notes.push(
    `Backfilled missing brand model lists from arabam.com GetFacets SelectedCategory.SubCategories at ${dict.generated_at}. Only applied when existing list was empty.`
  );

  console.log("\nsummary:");
  console.log("- filled=" + filled.length);
  console.log("- failed=" + failed.length);
  console.log("- now_unmatched=" + unmatched.length);

  if (!args.write) {
    console.log("\nDry-run: no files written. Use --write to update model dictionary.");
    if (failed.length) {
      console.log("failed_samples=" + JSON.stringify(failed.slice(0, 10), null, 2));
    }
    return;
  }

  fs.writeFileSync(dictPath, JSON.stringify(dict, null, 2) + "\n", "utf8");
  console.log("\nwrote " + dictPath);
  if (failed.length) {
    console.log("failed=" + JSON.stringify(failed, null, 2));
  }
}

main().catch((e) => {
  console.error("ERROR: " + (e?.message || String(e)));
  process.exit(1);
});

