/* eslint-disable no-console */
/**
 * Export Car (otomobil) brand -> model lists from arabam.com.
 *
 * Arabam structure:
 * - /ikinci-el/otomobil -> brands (SelectedCategory.SubCategories)
 * - /ikinci-el/otomobil/<brand> -> models (SelectedCategory.SubCategories)
 *
 * Writes:
 * - catalog/manifests/vehicle-otomobil-models.arabam.tr.json
 *
 * Usage:
 *   node scripts/arabam-export-otomobil-models.js --write
 */

const fs = require("fs");
const path = require("path");

const FACETS_ENDPOINT = "https://www.arabam.com/listing/GetFacets?url=";
const BASE = "https://www.arabam.com/";
const ROOT_REL = "ikinci-el/otomobil";

function parseArgs(argv) {
  return { write: argv.includes("--write"), concurrency: 6 };
}

async function fetchFacets(rel, timeoutMs = 25000) {
  const pageUrl = BASE + String(rel || "").replace(/^\/+/, "");
  const req = FACETS_ENDPOINT + encodeURIComponent(pageUrl);
  const ac = new AbortController();
  const t = setTimeout(() => ac.abort(), timeoutMs);
  try {
    const res = await fetch(req, { headers: { accept: "application/json,text/plain,*/*" }, signal: ac.signal });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    return await res.json();
  } finally {
    clearTimeout(t);
  }
}

function subcategories(o) {
  const sub = o?.Data?.Facets?.[0]?.SelectedCategory?.SubCategories || [];
  return Array.isArray(sub) ? sub : [];
}

function uniq(list) {
  const seen = new Set();
  const out = [];
  for (const x of list) {
    if (!x || seen.has(x)) continue;
    seen.add(x);
    out.push(x);
  }
  return out;
}

function sortTr(list) {
  return [...list].sort((a, b) => String(a).localeCompare(String(b), "tr"));
}

function translitTr(s) {
  return String(s || "")
    .replace(/ğ/g, "g")
    .replace(/Ğ/g, "g")
    .replace(/ü/g, "u")
    .replace(/Ü/g, "u")
    .replace(/ş/g, "s")
    .replace(/Ş/g, "s")
    .replace(/ı/g, "i")
    .replace(/İ/g, "i")
    .replace(/ö/g, "o")
    .replace(/Ö/g, "o")
    .replace(/ç/g, "c")
    .replace(/Ç/g, "c");
}

function slugifyKey(s) {
  return translitTr(String(s || ""))
    .trim()
    .toLowerCase()
    .replace(/_+/g, "-")
    .replace(/[^a-z0-9\-]+/g, "-")
    .replace(/-+/g, "-")
    .replace(/^-|-$/g, "");
}

function lastPathSegment(rel) {
  const parts = String(rel || "").split("?")[0].split("#")[0].split("/").filter(Boolean);
  return parts[parts.length - 1] || "";
}

async function mapLimit(items, limit, fn) {
  const results = new Array(items.length);
  let nextIndex = 0;
  let running = 0;

  return await new Promise((resolve, reject) => {
    const launch = () => {
      while (running < limit && nextIndex < items.length) {
        const idx = nextIndex++;
        running++;
        Promise.resolve(fn(items[idx], idx))
          .then((res) => {
            results[idx] = res;
            running--;
            if (nextIndex >= items.length && running === 0) resolve(results);
            else launch();
          })
          .catch(reject);
      }
    };
    launch();
  });
}

async function main() {
  const args = parseArgs(process.argv);
  const repoRoot = path.resolve(__dirname, "..");
  const manifestsRoot = path.join(repoRoot, "catalog", "manifests");

  // Read current category whitelist (so we keep slugs stable)
  const catsPath = path.join(manifestsRoot, "categories", "vehicle-otomobil-brands.json");
  const cats = JSON.parse(fs.readFileSync(catsPath, "utf8"));
  const catSlugs = new Set((Array.isArray(cats) ? cats : []).map((x) => String(x.slug || "")).filter(Boolean));

  const root = await fetchFacets(ROOT_REL);
  const brands = subcategories(root)
    .map((x) => ({
      name: typeof x?.Name === "string" ? x.Name.trim() : "",
      rel: typeof x?.RelativeUrl === "string" ? x.RelativeUrl.trim().replace(/^\/+/, "") : "",
      seg: lastPathSegment(typeof x?.RelativeUrl === "string" ? x.RelativeUrl : ""),
    }))
    .filter((b) => b.name && b.rel);

  const orderedBrands = sortTr(uniq(brands.map((b) => b.name))).map((name) => brands.find((b) => b.name === name));

  console.log("arabam_brands=" + orderedBrands.length);

  const mapped = await mapLimit(orderedBrands, args.concurrency, async (b) => {
    const seg = b.seg || b.name;
    const brandSlug = slugifyKey(seg);
    const catSlug = `otomobil-${brandSlug}`;

    const bo = await fetchFacets(b.rel);
    const models = sortTr(
      uniq(
        subcategories(bo)
          .map((m) => (typeof m?.Name === "string" ? m.Name.trim() : ""))
          .filter(Boolean)
      )
    );

    const inWhitelist = catSlugs.has(catSlug);
    return { catSlug, brandName: b.name, rel: b.rel, models, inWhitelist };
  });

  const dict = {};
  const missingWhitelist = [];
  const extraWhitelist = [];

  for (const r of mapped) {
    if (!r.inWhitelist) missingWhitelist.push({ slug: r.catSlug, title: r.brandName, rel: r.rel });
    dict[r.catSlug] = r.models;
  }

  for (const s of [...catSlugs]) {
    if (!dict[s]) extraWhitelist.push(s);
  }

  const out = {
    source: "arabam.com GetFacets (ikinci-el/otomobil brand pages SelectedCategory.SubCategories)",
    generated_at: new Date().toISOString(),
    stats: {
      brands_seen: orderedBrands.length,
      brands_with_models: mapped.filter((r) => r.models.length > 0).length,
      brands_without_models: mapped.filter((r) => r.models.length === 0).length,
      models_total: mapped.reduce((a, r) => a + r.models.length, 0),
      whitelist_categories_total: catSlugs.size,
      whitelist_extra_slugs: extraWhitelist.length,
      whitelist_missing_slugs: missingWhitelist.length,
    },
    notes: [
      "Keys are otomobil brand category slugs (otomobil-<brand>). Values are model labels from Arabam SelectedCategory.SubCategories.",
      "This file is intended to be used with rules_ref type vehicle_models_by_brand_slug for vehicle_model dropdown.",
    ],
    whitelist_extra_slugs: extraWhitelist,
    whitelist_missing_slugs: missingWhitelist,
    brand_slug_to_models: dict,
  };

  console.log("models_total=" + out.stats.models_total);
  console.log("brands_with_models=" + out.stats.brands_with_models + " brands_without_models=" + out.stats.brands_without_models);
  if (out.stats.whitelist_extra_slugs) console.log("whitelist_extra_slugs=" + out.stats.whitelist_extra_slugs);
  if (out.stats.whitelist_missing_slugs) console.log("whitelist_missing_slugs=" + out.stats.whitelist_missing_slugs);

  if (!args.write) {
    console.log("\nDry-run: use --write to write manifest.");
    return;
  }

  const outPath = path.join(manifestsRoot, "vehicle-otomobil-models.arabam.tr.json");
  fs.writeFileSync(outPath, JSON.stringify(out, null, 2) + "\n", "utf8");
  console.log("wrote " + outPath);
}

main().catch((e) => {
  console.error("ERROR: " + (e?.message || String(e)));
  process.exit(1);
});

