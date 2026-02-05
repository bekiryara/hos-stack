/* eslint-disable no-console */
/**
 * Export brand -> model lists for Arabam "motosiklet".
 *
 * Writes:
 * - catalog/manifests/categories/vehicle-motosiklet-brands.json
 * - catalog/manifests/vehicle-motosiklet-models.arabam.tr.json
 * - catalog/manifests/schema/vehicle-motosiklet-models.json
 *
 * Usage:
 *   node scripts/arabam-export-motosiklet-models.js --write
 */

const fs = require("fs");
const path = require("path");

const FACETS_ENDPOINT = "https://www.arabam.com/listing/GetFacets?url=";
const BASE = "https://www.arabam.com/";

function parseArgs(argv) {
  return { write: argv.includes("--write") };
}

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

async function fetchFacets(rel, { timeoutMs = 25000, retries = 3 } = {}) {
  const pageUrl = BASE + String(rel || "").replace(/^\/+/, "");
  const req = FACETS_ENDPOINT + encodeURIComponent(pageUrl);

  for (let attempt = 1; attempt <= retries; attempt++) {
    const ac = new AbortController();
    const t = setTimeout(() => ac.abort(), timeoutMs);
    try {
      const res = await fetch(req, { headers: { accept: "application/json,text/plain,*/*" }, signal: ac.signal });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      return await res.json();
    } catch (e) {
      if (attempt === retries) throw e;
      await sleep(250 * attempt);
    } finally {
      clearTimeout(t);
    }
  }
  throw new Error("unreachable");
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

function brandSlugFromRelativeUrl(rel) {
  const parts = String(rel || "").split("?")[0].split("#")[0].split("/").filter(Boolean);
  const idx = parts.indexOf("motosiklet");
  if (idx >= 0 && idx + 1 < parts.length) return parts[idx + 1];
  return parts[parts.length - 1] || "";
}

async function mapLimit(items, limit, mapper) {
  const results = new Array(items.length);
  let next = 0;
  async function worker() {
    while (true) {
      const i = next++;
      if (i >= items.length) return;
      results[i] = await mapper(items[i], i);
    }
  }
  const workers = Array.from({ length: Math.min(limit, items.length) }, () => worker());
  await Promise.all(workers);
  return results;
}

async function main() {
  const args = parseArgs(process.argv);
  const repoRoot = path.resolve(__dirname, "..");
  const manifestsRoot = path.join(repoRoot, "catalog", "manifests");

  const rootRel = "ikinci-el/motosiklet";
  const root = await fetchFacets(rootRel);
  const brands = subcategories(root)
    .map((x) => ({
      name: typeof x?.Name === "string" ? x.Name.trim() : "",
      rel: typeof x?.RelativeUrl === "string" ? x.RelativeUrl.trim() : "",
      isBrand: x?.IsBrand === true,
    }))
    .filter((b) => b.isBrand && b.name && b.rel);

  const orderedBrands = [...brands].sort((a, b) => String(a.name).localeCompare(String(b.name), "tr"));

  // Build categories
  const categories = [];
  let sortOrder = 10;
  for (const b of orderedBrands) {
    const brandSlug = brandSlugFromRelativeUrl(b.rel);
    categories.push({
      slug: `motosiklet-${brandSlug}`,
      parent_slug: "motosiklet",
      title: b.name,
      status: "active",
      sort_order: sortOrder,
    });
    sortOrder += 10;
  }

  // Build model dict (category_slug -> models[])
  const dict = {};
  const concurrency = 8;
  await mapLimit(orderedBrands, concurrency, async (b) => {
    const brandSlug = brandSlugFromRelativeUrl(b.rel);
    const catSlug = `motosiklet-${brandSlug}`;
    const bo = await fetchFacets(b.rel);
    const models = sortTr(
      uniq(
        subcategories(bo)
          .map((m) => (typeof m?.Name === "string" ? m.Name.trim() : ""))
          .filter(Boolean)
      )
    );
    dict[catSlug] = models;
    console.log(`models ${catSlug} = ${models.length}`);
  });

  const outModels = {
    source: "arabam.com GetFacets (motosiklet)",
    generated_at: new Date().toISOString(),
    stats: {
      brand_categories_total: Object.keys(dict).length,
      models_total: Object.values(dict).reduce((a, v) => a + (Array.isArray(v) ? v.length : 0), 0),
    },
    brand_slug_to_models: dict,
  };

  const schema = {
    schema_version: 1,
    category_slugs: Object.keys(dict).sort((a, b) => String(a).localeCompare(String(b), "tr")),
    fields: [
      { attribute_key: "city", ui_component: "select", required: false, filter_mode: "exact", rules: null, rules_ref: "cities.tr.json", sort_order: 5, applies_to_transaction_modes: null },

      {
        attribute_key: "vehicle_model",
        ui_component: "select",
        required: false,
        filter_mode: "exact",
        rules: null,
        rules_ref: { type: "vehicle_models_by_brand_slug", path: "vehicle-motosiklet-models.arabam.tr.json" },
        sort_order: 20,
        applies_to_transaction_modes: null,
      },

      { attribute_key: "vehicle_year", ui_component: "number", required: false, filter_mode: "range", rules: { min: 1950, max: 2035 }, sort_order: 30, applies_to_transaction_modes: null },
      { attribute_key: "vehicle_fuel_type", ui_component: "select", required: false, filter_mode: "exact", rules: null, rules_ref: "rules/vehicle/by_category/motosiklet/vehicle_fuel_type.tr.json", sort_order: 40, applies_to_transaction_modes: null },
      { attribute_key: "vehicle_transmission", ui_component: "select", required: false, filter_mode: "exact", rules: null, rules_ref: "rules/vehicle/by_category/motosiklet/vehicle_transmission.tr.json", sort_order: 50, applies_to_transaction_modes: null },
      { attribute_key: "vehicle_color", ui_component: "select", required: false, filter_mode: "exact", rules: null, rules_ref: "rules/vehicle/by_category/motosiklet/vehicle_color.tr.json", sort_order: 56, applies_to_transaction_modes: null },
      { attribute_key: "vehicle_condition", ui_component: "select", required: false, filter_mode: "exact", rules: null, rules_ref: "rules/vehicle/by_category/motosiklet/vehicle_condition.tr.json", sort_order: 58, applies_to_transaction_modes: null },
      { attribute_key: "vehicle_seller_type", ui_component: "select", required: false, filter_mode: "exact", rules: null, rules_ref: "rules/vehicle/by_category/motosiklet/vehicle_seller_type.tr.json", sort_order: 59, applies_to_transaction_modes: null },

      { attribute_key: "vehicle_km", ui_component: "number", required: false, filter_mode: "range", rules: { min: 0, max: 2000000 }, sort_order: 60, applies_to_transaction_modes: null },
      { attribute_key: "vehicle_swap", ui_component: "boolean", required: false, filter_mode: "exact", rules: null, sort_order: 65, applies_to_transaction_modes: null },
      { attribute_key: "vehicle_listing_age", ui_component: "select", required: false, filter_mode: "exact", rules: null, rules_ref: "rules/vehicle/by_category/motosiklet/vehicle_listing_age.tr.json", sort_order: 66, applies_to_transaction_modes: null },

      { attribute_key: "vehicle_price", ui_component: "number", required: false, filter_mode: "range", rules: { min: 0, max: 1000000000 }, sort_order: 70, applies_to_transaction_modes: ["sale"] },
    ],
  };

  console.log("\nsummary brand_categories_total=" + outModels.stats.brand_categories_total);
  console.log("summary models_total=" + outModels.stats.models_total);

  if (!args.write) {
    console.log("\nDry-run: use --write to write manifests.");
    return;
  }

  const catPath = path.join(manifestsRoot, "categories", "vehicle-motosiklet-brands.json");
  fs.writeFileSync(catPath, JSON.stringify(categories, null, 2) + "\n", "utf8");
  console.log("wrote " + catPath);

  const modelPath = path.join(manifestsRoot, "vehicle-motosiklet-models.arabam.tr.json");
  fs.writeFileSync(modelPath, JSON.stringify(outModels, null, 2) + "\n", "utf8");
  console.log("wrote " + modelPath);

  const schemaPath = path.join(manifestsRoot, "schema", "vehicle-motosiklet-models.json");
  fs.writeFileSync(schemaPath, JSON.stringify(schema, null, 2) + "\n", "utf8");
  console.log("wrote " + schemaPath);
}

main().catch((e) => {
  console.error("ERROR: " + (e?.message || String(e)));
  process.exit(1);
});

