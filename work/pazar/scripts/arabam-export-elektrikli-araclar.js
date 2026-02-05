/* eslint-disable no-console */
/**
 * Export Electric Vehicles (elektrikli-araclar) subtypes + brand categories.
 *
 * Some subtypes expose brand->model lists via SelectedCategory.SubCategories on brand pages
 * (e.g., otomobil-elektrik, elektrikli-motosiklet, elektrikli-minivan_-panelvan_).
 * Others do not (scooter, kickscooter, atv-utv, hizmet-araclari). For those, vehicle_model stays text.
 *
 * Writes:
 * - catalog/manifests/categories/vehicle-elektrikli-araclar-subtypes.json
 * - catalog/manifests/categories/vehicle-elektrikli-araclar-brands.json
 * - catalog/manifests/vehicle-elektrikli-araclar-models.arabam.tr.json
 * - catalog/manifests/schema/vehicle-elektrikli-araclar-models.json          (model dropdown)
 * - catalog/manifests/schema/vehicle-elektrikli-araclar-brands-no-models.json (model text)
 *
 * Usage:
 *   node scripts/arabam-export-elektrikli-araclar.js --write
 */

const fs = require("fs");
const path = require("path");

const FACETS_ENDPOINT = "https://www.arabam.com/listing/GetFacets?url=";
const BASE = "https://www.arabam.com/";

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

function slugifyKey(s) {
  return String(s || "")
    .trim()
    .toLowerCase()
    .replace(/_+/g, "-")
    .replace(/[^a-z0-9\-]+/g, "-")
    .replace(/-+/g, "-")
    .replace(/^-|-$/g, "");
}

const SUBTYPES = [
  { key: "otomobil", title: "Elektrikli Otomobil", rel: "ikinci-el/otomobil-elektrik", sort_order: 10 },
  { key: "motosiklet", title: "Elektrikli Motosiklet", rel: "ikinci-el/elektrikli-araclar/elektrikli-motosiklet", sort_order: 20 },
  { key: "minivan-panelvan", title: "Elektrikli Minivan & Panelvan", rel: "ikinci-el/elektrikli-araclar/elektrikli-minivan_-panelvan_", sort_order: 30 },
  { key: "scooter", title: "Elektrikli Scooter", rel: "ikinci-el/elektrikli-araclar/elektrikli-scooter", sort_order: 40 },
  { key: "kickscooter", title: "Elektrikli Kickscooter", rel: "ikinci-el/elektrikli-araclar/elektrikli-kickscooter", sort_order: 50 },
  { key: "atv-utv", title: "Elektrikli ATV & UTV", rel: "ikinci-el/elektrikli-araclar/elektrikli-atv-utv", sort_order: 60 },
  { key: "hizmet-araclari", title: "Elektrikli Hizmet Araçları", rel: "ikinci-el/elektrikli-araclar/elektrikli-hizmet-araclari", sort_order: 70 },
];

function baseElectricFields(modelField) {
  return [
    { attribute_key: "city", ui_component: "select", required: false, filter_mode: "exact", rules: null, rules_ref: "cities.tr.json", sort_order: 5, applies_to_transaction_modes: null },
    modelField,
    { attribute_key: "vehicle_year", ui_component: "number", required: false, filter_mode: "range", rules: { min: 1950, max: 2035 }, sort_order: 30, applies_to_transaction_modes: null },
    { attribute_key: "vehicle_color", ui_component: "select", required: false, filter_mode: "exact", rules: null, rules_ref: "rules/vehicle/by_category/elektrikli-araclar/vehicle_color.tr.json", sort_order: 56, applies_to_transaction_modes: null },
    { attribute_key: "vehicle_condition", ui_component: "select", required: false, filter_mode: "exact", rules: null, rules_ref: "rules/vehicle/by_category/elektrikli-araclar/vehicle_condition.tr.json", sort_order: 58, applies_to_transaction_modes: null },
    { attribute_key: "vehicle_seller_type", ui_component: "select", required: false, filter_mode: "exact", rules: null, rules_ref: "rules/vehicle/by_category/elektrikli-araclar/vehicle_seller_type.tr.json", sort_order: 59, applies_to_transaction_modes: null },
    { attribute_key: "vehicle_km", ui_component: "number", required: false, filter_mode: "range", rules: { min: 0, max: 2000000 }, sort_order: 60, applies_to_transaction_modes: null },
    { attribute_key: "vehicle_swap", ui_component: "boolean", required: false, filter_mode: "exact", rules: null, sort_order: 65, applies_to_transaction_modes: null },
    { attribute_key: "vehicle_listing_age", ui_component: "select", required: false, filter_mode: "exact", rules: null, rules_ref: "rules/vehicle/by_category/elektrikli-araclar/vehicle_listing_age.tr.json", sort_order: 66, applies_to_transaction_modes: null },
    { attribute_key: "vehicle_price", ui_component: "number", required: false, filter_mode: "range", rules: { min: 0, max: 1000000000 }, sort_order: 70, applies_to_transaction_modes: ["sale"] },
  ];
}

async function main() {
  const args = parseArgs(process.argv);
  const repoRoot = path.resolve(__dirname, "..");
  const manifestsRoot = path.join(repoRoot, "catalog", "manifests");

  // subtype categories
  const subtypeCats = SUBTYPES.map((s) => ({
    slug: `elektrikli-araclar-${s.key}`,
    parent_slug: "elektrikli-araclar",
    title: s.title,
    status: "active",
    sort_order: s.sort_order,
  }));

  const brandCats = [];
  const modelDict = {}; // brand_category_slug -> models[]
  const brandCatsNoModels = [];

  for (const s of SUBTYPES) {
    const subtypeSlug = `elektrikli-araclar-${s.key}`;
    const o = await fetchFacets(s.rel);
    const brands = subcategories(o)
      .map((x) => ({
        name: typeof x?.Name === "string" ? x.Name.trim() : "",
        rel: typeof x?.RelativeUrl === "string" ? x.RelativeUrl.trim() : "",
      }))
      .filter((b) => b.name && b.rel);

    const orderedBrands = sortTr(uniq(brands.map((b) => b.name))).map((name) => {
      // Find the rel URL by name (first match)
      const hit = brands.find((b) => b.name === name);
      return { name, rel: hit?.rel || "" };
    });

    let order = 10;
    for (const b of orderedBrands) {
      const brandSlug = slugifyKey(lastPathSegment(b.rel));
      const catSlug = `elektrikli-araclar-${s.key}-${brandSlug}`;
      brandCats.push({
        slug: catSlug,
        parent_slug: subtypeSlug,
        title: b.name,
        status: "active",
        sort_order: order,
      });
      order += 10;

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
        brandCatsNoModels.push(catSlug);
        console.log(`models ${catSlug} = 0`);
      }
    }
  }

  const outModels = {
    source: "arabam.com GetFacets (elektrikli-araclar subtypes)",
    generated_at: new Date().toISOString(),
    stats: {
      brand_categories_with_models_total: Object.keys(modelDict).length,
      brand_categories_without_models_total: brandCatsNoModels.length,
      models_total: Object.values(modelDict).reduce((a, v) => a + (Array.isArray(v) ? v.length : 0), 0),
    },
    brand_slug_to_models: modelDict,
  };

  const schemaModels = {
    schema_version: 1,
    category_slugs: Object.keys(modelDict).sort((a, b) => String(a).localeCompare(String(b), "tr")),
    fields: baseElectricFields({
      attribute_key: "vehicle_model",
      ui_component: "select",
      required: false,
      filter_mode: "exact",
      rules: null,
      rules_ref: { type: "vehicle_models_by_brand_slug", path: "vehicle-elektrikli-araclar-models.arabam.tr.json" },
      sort_order: 20,
      applies_to_transaction_modes: null,
    }),
  };

  const schemaNoModels = {
    schema_version: 1,
    category_slugs: sortTr(brandCatsNoModels),
    fields: baseElectricFields({
      attribute_key: "vehicle_model",
      ui_component: "text",
      required: false,
      filter_mode: "exact",
      rules: null,
      sort_order: 20,
      applies_to_transaction_modes: null,
    }),
  };

  console.log("\nsummary subtype_cats=" + subtypeCats.length);
  console.log("summary brand_cats=" + brandCats.length);
  console.log("summary with_models=" + outModels.stats.brand_categories_with_models_total);
  console.log("summary without_models=" + outModels.stats.brand_categories_without_models_total);
  console.log("summary models_total=" + outModels.stats.models_total);

  if (!args.write) {
    console.log("\nDry-run: use --write to write manifests.");
    return;
  }

  const subPath = path.join(manifestsRoot, "categories", "vehicle-elektrikli-araclar-subtypes.json");
  fs.writeFileSync(subPath, JSON.stringify(subtypeCats, null, 2) + "\n", "utf8");
  console.log("wrote " + subPath);

  const brandPath = path.join(manifestsRoot, "categories", "vehicle-elektrikli-araclar-brands.json");
  fs.writeFileSync(brandPath, JSON.stringify(brandCats, null, 2) + "\n", "utf8");
  console.log("wrote " + brandPath);

  const modelPath = path.join(manifestsRoot, "vehicle-elektrikli-araclar-models.arabam.tr.json");
  fs.writeFileSync(modelPath, JSON.stringify(outModels, null, 2) + "\n", "utf8");
  console.log("wrote " + modelPath);

  const schemaModelsPath = path.join(manifestsRoot, "schema", "vehicle-elektrikli-araclar-models.json");
  fs.writeFileSync(schemaModelsPath, JSON.stringify(schemaModels, null, 2) + "\n", "utf8");
  console.log("wrote " + schemaModelsPath);

  const schemaNoModelsPath = path.join(manifestsRoot, "schema", "vehicle-elektrikli-araclar-brands-no-models.json");
  fs.writeFileSync(schemaNoModelsPath, JSON.stringify(schemaNoModels, null, 2) + "\n", "utf8");
  console.log("wrote " + schemaNoModelsPath);
}

main().catch((e) => {
  console.error("ERROR: " + (e?.message || String(e)));
  process.exit(1);
});

