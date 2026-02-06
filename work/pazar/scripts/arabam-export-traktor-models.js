/* eslint-disable no-console */
/**
 * Export Tractor (traktor) brands + models from arabam.com.
 *
 * Arabam structure:
 * - /ikinci-el/traktor -> brands (SelectedCategory.SubCategories)
 * - /ikinci-el/traktor/<brand> -> models (SelectedCategory.SubCategories)
 *
 * Writes:
 * - catalog/manifests/categories/vehicle-traktor-brands.json
 * - catalog/manifests/vehicle-traktor-models.arabam.tr.json
 * - catalog/manifests/schema/vehicle-traktor-models.json            (model dropdown)
 * - catalog/manifests/schema/vehicle-traktor-brands-no-models.json  (model text for sparse brands)
 *
 * Usage:
 *   node scripts/arabam-export-traktor-models.js --write
 */

const fs = require("fs");
const path = require("path");

const FACETS_ENDPOINT = "https://www.arabam.com/listing/GetFacets?url=";
const BASE = "https://www.arabam.com/";
const ROOT_REL = "ikinci-el/traktor";

function parseArgs(argv) {
  return { write: argv.includes("--write") };
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

function lastPathSegment(rel) {
  const parts = String(rel || "").split("?")[0].split("#")[0].split("/").filter(Boolean);
  return parts[parts.length - 1] || "";
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

function tractorLeafFields(modelField) {
  return [
    { attribute_key: "city", ui_component: "select", required: false, filter_mode: "exact", rules: null, rules_ref: "cities.tr.json", sort_order: 5, applies_to_transaction_modes: null },
    modelField,
    { attribute_key: "vehicle_year", ui_component: "number", required: false, filter_mode: "range", rules: { min: 1950, max: 2035 }, sort_order: 30, applies_to_transaction_modes: null },
    { attribute_key: "vehicle_cylinder_count", ui_component: "select", required: false, filter_mode: "exact", rules: null, rules_ref: "rules/vehicle/by_category/traktor/vehicle_cylinder_count.tr.json", sort_order: 32, applies_to_transaction_modes: null },
    { attribute_key: "vehicle_tractor_type", ui_component: "select", required: false, filter_mode: "exact", rules: null, rules_ref: "rules/vehicle/by_category/traktor/vehicle_tractor_type.tr.json", sort_order: 33, applies_to_transaction_modes: null },
    { attribute_key: "vehicle_tractor_cabin", ui_component: "select", required: false, filter_mode: "exact", rules: null, rules_ref: "rules/vehicle/by_category/traktor/vehicle_tractor_cabin.tr.json", sort_order: 34, applies_to_transaction_modes: null },
    { attribute_key: "vehicle_working_hours", ui_component: "number", required: false, filter_mode: "range", rules: { min: 0, max: 50000 }, sort_order: 35, applies_to_transaction_modes: null },
    { attribute_key: "vehicle_drive_type", ui_component: "select", required: false, filter_mode: "exact", rules: null, rules_ref: "rules/vehicle/by_category/traktor/vehicle_drive_type.tr.json", sort_order: 57, applies_to_transaction_modes: null },
    { attribute_key: "vehicle_condition", ui_component: "select", required: false, filter_mode: "exact", rules: null, rules_ref: "rules/vehicle/by_category/traktor/vehicle_condition.tr.json", sort_order: 58, applies_to_transaction_modes: null },
    { attribute_key: "vehicle_seller_type", ui_component: "select", required: false, filter_mode: "exact", rules: null, rules_ref: "rules/vehicle/by_category/traktor/vehicle_seller_type.tr.json", sort_order: 59, applies_to_transaction_modes: null },
    { attribute_key: "vehicle_listing_age", ui_component: "select", required: false, filter_mode: "exact", rules: null, rules_ref: "rules/vehicle/by_category/traktor/vehicle_listing_age.tr.json", sort_order: 66, applies_to_transaction_modes: null },
    { attribute_key: "vehicle_price", ui_component: "number", required: false, filter_mode: "range", rules: { min: 0, max: 1000000000 }, sort_order: 70, applies_to_transaction_modes: ["sale"] },
  ];
}

async function main() {
  const args = parseArgs(process.argv);
  const repoRoot = path.resolve(__dirname, "..");
  const manifestsRoot = path.join(repoRoot, "catalog", "manifests");

  const root = await fetchFacets(ROOT_REL);
  const brands = subcategories(root)
    .map((x) => ({
      name: typeof x?.Name === "string" ? x.Name.trim() : "",
      rel: typeof x?.RelativeUrl === "string" ? x.RelativeUrl.trim().replace(/^\/+/, "") : "",
    }))
    .filter((b) => b.name && b.rel);

  const orderedBrands = sortTr(uniq(brands.map((b) => b.name))).map((name) => brands.find((b) => b.name === name));

  const brandCats = [];
  const modelDict = {};
  const noModelCats = [];

  let sortOrder = 10;
  for (const b of orderedBrands) {
    if (!b?.rel) continue;
    const urlSeg = lastPathSegment(b.rel);
    const brandSlug = slugifyKey(urlSeg || b.name);
    const catSlug = `traktor-${brandSlug}`;

    brandCats.push({ slug: catSlug, parent_slug: "traktor", title: b.name, status: "active", sort_order: sortOrder });
    sortOrder += 10;

    const bo = await fetchFacets(b.rel);
    const models = sortTr(
      uniq(
        subcategories(bo)
          .map((m) => (typeof m?.Name === "string" ? m.Name.trim() : ""))
          .filter(Boolean)
      )
    );

    if (models.length > 0) {
      modelDict[catSlug] = models;
      console.log(`models ${catSlug} = ${models.length}`);
    } else {
      noModelCats.push(catSlug);
      console.log(`models ${catSlug} = 0`);
    }
  }

  const outModels = {
    source: "arabam.com GetFacets (traktor brand pages SelectedCategory.SubCategories)",
    generated_at: new Date().toISOString(),
    stats: {
      brand_categories_total: brandCats.length,
      brand_categories_with_models_total: Object.keys(modelDict).length,
      brand_categories_without_models_total: noModelCats.length,
      models_total: Object.values(modelDict).reduce((a, v) => a + (Array.isArray(v) ? v.length : 0), 0),
    },
    brand_slug_to_models: modelDict,
  };

  const schemaModels = {
    schema_version: 1,
    category_slugs: Object.keys(modelDict).sort((a, b) => String(a).localeCompare(String(b), "tr")),
    fields: tractorLeafFields({
      attribute_key: "vehicle_model",
      ui_component: "select",
      required: false,
      filter_mode: "exact",
      rules: null,
      rules_ref: { type: "vehicle_models_by_brand_slug", path: "vehicle-traktor-models.arabam.tr.json" },
      sort_order: 20,
      applies_to_transaction_modes: null,
    }),
  };

  const schemaNoModels = {
    schema_version: 1,
    category_slugs: sortTr(noModelCats),
    fields: tractorLeafFields({
      attribute_key: "vehicle_model",
      ui_component: "text",
      required: false,
      filter_mode: "exact",
      rules: null,
      sort_order: 20,
      applies_to_transaction_modes: null,
    }),
  };

  console.log("\nsummary brand_cats=" + brandCats.length);
  console.log("summary with_models=" + outModels.stats.brand_categories_with_models_total);
  console.log("summary without_models=" + outModels.stats.brand_categories_without_models_total);
  console.log("summary models_total=" + outModels.stats.models_total);

  if (!args.write) {
    console.log("\nDry-run: use --write to write manifests.");
    return;
  }

  const catsPath = path.join(manifestsRoot, "categories", "vehicle-traktor-brands.json");
  fs.writeFileSync(catsPath, JSON.stringify(brandCats, null, 2) + "\n", "utf8");
  console.log("wrote " + catsPath);

  const modelPath = path.join(manifestsRoot, "vehicle-traktor-models.arabam.tr.json");
  fs.writeFileSync(modelPath, JSON.stringify(outModels, null, 2) + "\n", "utf8");
  console.log("wrote " + modelPath);

  const schemaModelsPath = path.join(manifestsRoot, "schema", "vehicle-traktor-models.json");
  fs.writeFileSync(schemaModelsPath, JSON.stringify(schemaModels, null, 2) + "\n", "utf8");
  console.log("wrote " + schemaModelsPath);

  const schemaNoModelsPath = path.join(manifestsRoot, "schema", "vehicle-traktor-brands-no-models.json");
  fs.writeFileSync(schemaNoModelsPath, JSON.stringify(schemaNoModels, null, 2) + "\n", "utf8");
  console.log("wrote " + schemaNoModelsPath);
}

main().catch((e) => {
  console.error("ERROR: " + (e?.message || String(e)));
  process.exit(1);
});

