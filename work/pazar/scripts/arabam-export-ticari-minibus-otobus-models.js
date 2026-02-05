/* eslint-disable no-console */
/**
 * Export models for ticari-arac subtypes: minibus-midibus, otobus.
 *
 * Creates:
 * - catalog/manifests/categories/vehicle-ticari-minibus-otobus.json
 * - catalog/manifests/vehicle-ticari-minibus-otobus-models.arabam.tr.json
 *
 * Adds brand categories like:
 *   ticari-arac-minibus-midibus-ford-otosan
 *   ticari-arac-otobus-mercedes-benz
 *
 * Models are taken from SelectedCategory.SubCategories names on brand pages.
 *
 * Usage:
 *   node scripts/arabam-export-ticari-minibus-otobus-models.js --write
 */

const fs = require("fs");
const path = require("path");

const FACETS_ENDPOINT = "https://www.arabam.com/listing/GetFacets?url=";
const BASE = "https://www.arabam.com/";

function parseArgs(argv) {
  const out = { write: false };
  for (let i = 2; i < argv.length; i++) {
    if (argv[i] === "--write") out.write = true;
  }
  return out;
}

async function fetchJsonByRelativeUrl(rel, timeoutMs = 25000) {
  const pageUrl = BASE + String(rel || "").replace(/^\/+/, "");
  const req = FACETS_ENDPOINT + encodeURIComponent(pageUrl);
  const ac = new AbortController();
  const t = setTimeout(() => ac.abort(), timeoutMs);
  try {
    const res = await fetch(req, {
      headers: { accept: "application/json,text/plain,*/*" },
      signal: ac.signal,
    });
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

function slugFromRelativeUrl(rel) {
  const parts = String(rel || "")
    .split("?")[0]
    .split("#")[0]
    .split("/")
    .filter(Boolean);
  return parts.length ? parts[parts.length - 1] : "";
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

async function exportSubtype(subtypeKey, subtypeTitle, subtypeRel) {
  const o = await fetchJsonByRelativeUrl(subtypeRel);
  const brands = subcategories(o).map((x) => ({
    name: x?.Name,
    rel: x?.RelativeUrl,
    brandSlug: slugFromRelativeUrl(x?.RelativeUrl),
  }));

  const cleanBrands = brands
    .filter((b) => typeof b.name === "string" && b.name.trim() && typeof b.rel === "string" && b.rel.trim())
    .map((b) => ({ ...b, name: b.name.trim(), rel: b.rel.trim(), brandSlug: b.brandSlug.trim() }));

  const dict = {}; // category_slug -> models[]
  const brandCats = [];

  for (const b of cleanBrands) {
    const brandCatSlug = `ticari-arac-${subtypeKey}-${b.brandSlug}`;
    brandCats.push({ slug: brandCatSlug, title: b.name, rel: b.rel });

    const bo = await fetchJsonByRelativeUrl(b.rel);
    const models = sortTr(
      uniq(
        subcategories(bo)
          .map((x) => (typeof x?.Name === "string" ? x.Name.trim() : ""))
          .filter((x) => x)
      )
    );
    if (models.length > 0) {
      dict[brandCatSlug] = models;
      console.log(`models ${brandCatSlug} = ${models.length}`);
    } else {
      console.log(`models ${brandCatSlug} = 0 (skip)`);
    }
  }

  return {
    subtypeKey,
    subtypeTitle,
    subtypeRel,
    brandCategories: brandCats,
    modelDict: dict,
  };
}

async function main() {
  const args = parseArgs(process.argv);
  const repoRoot = path.resolve(__dirname, "..");
  const manifestsRoot = path.join(repoRoot, "catalog", "manifests");

  const exports = [];
  exports.push(await exportSubtype("minibus-midibus", "Minibüs & Midibüs", "ikinci-el/ticari-arac/minibus-midibus"));
  exports.push(await exportSubtype("otobus", "Otobüs", "ikinci-el/ticari-arac/otobus"));

  // Build categories manifest rows
  const categories = [];
  for (const ex of exports) {
    categories.push({
      slug: `ticari-arac-${ex.subtypeKey}`,
      parent_slug: "ticari-arac",
      title: ex.subtypeTitle,
      status: "active",
      sort_order: ex.subtypeKey === "otobus" ? 20 : 10,
    });
    let order = 10;
    for (const b of ex.brandCategories) {
      categories.push({
        slug: b.slug,
        parent_slug: `ticari-arac-${ex.subtypeKey}`,
        title: b.title,
        status: "active",
        sort_order: order,
      });
      order += 10;
    }
  }

  // Merge model dicts
  const brand_slug_to_models = {};
  for (const ex of exports) {
    for (const [k, v] of Object.entries(ex.modelDict)) {
      brand_slug_to_models[k] = v;
    }
  }

  const outModels = {
    source: "arabam.com GetFacets (ticari-arac minibus-midibus + otobus)",
    generated_at: new Date().toISOString(),
    stats: {
      brand_categories_total: Object.keys(brand_slug_to_models).length,
      models_total: Object.values(brand_slug_to_models).reduce((a, v) => a + (Array.isArray(v) ? v.length : 0), 0),
    },
    brand_slug_to_models,
  };

  console.log("\nsummary categories_rows=" + categories.length);
  console.log("summary brand_categories_with_models=" + Object.keys(brand_slug_to_models).length);
  console.log("summary models_total=" + outModels.stats.models_total);

  if (!args.write) {
    console.log("\nDry-run: use --write to write manifests.");
    return;
  }

  const catPath = path.join(manifestsRoot, "categories", "vehicle-ticari-minibus-otobus.json");
  fs.writeFileSync(catPath, JSON.stringify(categories, null, 2) + "\n", "utf8");
  console.log("wrote " + catPath);

  const modelPath = path.join(manifestsRoot, "vehicle-ticari-minibus-otobus-models.arabam.tr.json");
  fs.writeFileSync(modelPath, JSON.stringify(outModels, null, 2) + "\n", "utf8");
  console.log("wrote " + modelPath);
}

main().catch((e) => {
  console.error("ERROR: " + (e?.message || String(e)));
  process.exit(1);
});

