/* eslint-disable no-console */
/**
 * Export brand -> model lists for Arabam "arazi-suv-pick-up".
 *
 * Writes:
 * - catalog/manifests/categories/vehicle-arazi-suv-pick-up-brands.json
 * - catalog/manifests/vehicle-arazi-suv-pick-up-models.arabam.tr.json
 * - catalog/manifests/schema/vehicle-arazi-suv-pick-up-models.json
 *
 * Usage:
 *   node scripts/arabam-export-arazi-suv-pick-up-models.js --write
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

function brandSlugFromRelativeUrl(rel) {
  const parts = String(rel || "").split("?")[0].split("#")[0].split("/").filter(Boolean);
  const idx = parts.indexOf("arazi-suv-pick-up");
  if (idx >= 0 && idx + 1 < parts.length) return parts[idx + 1];
  return parts[parts.length - 1] || "";
}

async function main() {
  const args = parseArgs(process.argv);
  const repoRoot = path.resolve(__dirname, "..");
  const manifestsRoot = path.join(repoRoot, "catalog", "manifests");

  const rootRel = "ikinci-el/arazi-suv-pick-up";
  const root = await fetchFacets(rootRel);
  const brands = subcategories(root)
    .map((x) => ({
      name: typeof x?.Name === "string" ? x.Name.trim() : "",
      rel: typeof x?.RelativeUrl === "string" ? x.RelativeUrl.trim() : "",
      isBrand: x?.IsBrand === true,
    }))
    .filter((b) => b.isBrand && b.name && b.rel);

  const orderedBrands = [...brands].sort((a, b) => String(a.name).localeCompare(String(b.name), "tr"));

  const categories = [];
  const dict = {};

  let sortOrder = 10;
  for (const b of orderedBrands) {
    const brandSlug = brandSlugFromRelativeUrl(b.rel);
    const catSlug = `arazi-suv-pick-up-${brandSlug}`;
    categories.push({
      slug: catSlug,
      parent_slug: "arazi-suv-pick-up",
      title: b.name,
      status: "active",
      sort_order: sortOrder,
    });
    sortOrder += 10;

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
  }

  const outModels = {
    source: "arabam.com GetFacets (arazi-suv-pick-up)",
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
        rules_ref: { type: "vehicle_models_by_brand_slug", path: "vehicle-arazi-suv-pick-up-models.arabam.tr.json" },
        sort_order: 20,
        applies_to_transaction_modes: null,
      },

      { attribute_key: "vehicle_year", ui_component: "number", required: false, filter_mode: "range", rules: { min: 1950, max: 2035 }, sort_order: 30, applies_to_transaction_modes: null },
      { attribute_key: "vehicle_fuel_type", ui_component: "select", required: false, filter_mode: "exact", rules: null, rules_ref: "rules/vehicle/by_category/arazi-suv-pick-up/vehicle_fuel_type.tr.json", sort_order: 40, applies_to_transaction_modes: null },
      { attribute_key: "vehicle_transmission", ui_component: "select", required: false, filter_mode: "exact", rules: null, rules_ref: "rules/vehicle/by_category/arazi-suv-pick-up/vehicle_transmission.tr.json", sort_order: 50, applies_to_transaction_modes: null },
      { attribute_key: "vehicle_body_type", ui_component: "select", required: false, filter_mode: "exact", rules: null, rules_ref: "rules/vehicle/by_category/arazi-suv-pick-up/vehicle_body_type.tr.json", sort_order: 55, applies_to_transaction_modes: null },
      { attribute_key: "vehicle_color", ui_component: "select", required: false, filter_mode: "exact", rules: null, rules_ref: "rules/vehicle/by_category/arazi-suv-pick-up/vehicle_color.tr.json", sort_order: 56, applies_to_transaction_modes: null },
      { attribute_key: "vehicle_drive_type", ui_component: "select", required: false, filter_mode: "exact", rules: null, rules_ref: "rules/vehicle/by_category/arazi-suv-pick-up/vehicle_drive_type.tr.json", sort_order: 57, applies_to_transaction_modes: null },
      { attribute_key: "vehicle_condition", ui_component: "select", required: false, filter_mode: "exact", rules: null, rules_ref: "rules/vehicle/by_category/arazi-suv-pick-up/vehicle_condition.tr.json", sort_order: 58, applies_to_transaction_modes: null },
      { attribute_key: "vehicle_seller_type", ui_component: "select", required: false, filter_mode: "exact", rules: null, rules_ref: "rules/vehicle/by_category/arazi-suv-pick-up/vehicle_seller_type.tr.json", sort_order: 59, applies_to_transaction_modes: null },

      { attribute_key: "vehicle_km", ui_component: "number", required: false, filter_mode: "range", rules: { min: 0, max: 2000000 }, sort_order: 60, applies_to_transaction_modes: null },
      { attribute_key: "vehicle_damage_status", ui_component: "select", required: false, filter_mode: "exact", rules: null, rules_ref: "rules/vehicle/by_category/arazi-suv-pick-up/vehicle_damage_status.tr.json", sort_order: 63, applies_to_transaction_modes: null },
      { attribute_key: "vehicle_heavy_damage_record", ui_component: "boolean", required: false, filter_mode: "exact", rules: null, sort_order: 64, applies_to_transaction_modes: null },
      { attribute_key: "vehicle_swap", ui_component: "boolean", required: false, filter_mode: "exact", rules: null, sort_order: 65, applies_to_transaction_modes: null },
      { attribute_key: "vehicle_listing_age", ui_component: "select", required: false, filter_mode: "exact", rules: null, rules_ref: "rules/vehicle/by_category/arazi-suv-pick-up/vehicle_listing_age.tr.json", sort_order: 66, applies_to_transaction_modes: null },

      { attribute_key: "vehicle_price", ui_component: "number", required: false, filter_mode: "range", rules: { min: 0, max: 1000000000 }, sort_order: 70, applies_to_transaction_modes: ["sale"] },
    ],
  };

  console.log("\nsummary brand_categories_total=" + outModels.stats.brand_categories_total);
  console.log("summary models_total=" + outModels.stats.models_total);

  if (!args.write) {
    console.log("\nDry-run: use --write to write manifests.");
    return;
  }

  const catPath = path.join(manifestsRoot, "categories", "vehicle-arazi-suv-pick-up-brands.json");
  fs.writeFileSync(catPath, JSON.stringify(categories, null, 2) + "\n", "utf8");
  console.log("wrote " + catPath);

  const modelPath = path.join(manifestsRoot, "vehicle-arazi-suv-pick-up-models.arabam.tr.json");
  fs.writeFileSync(modelPath, JSON.stringify(outModels, null, 2) + "\n", "utf8");
  console.log("wrote " + modelPath);

  const schemaPath = path.join(manifestsRoot, "schema", "vehicle-arazi-suv-pick-up-models.json");
  fs.writeFileSync(schemaPath, JSON.stringify(schema, null, 2) + "\n", "utf8");
  console.log("wrote " + schemaPath);
}

main().catch((e) => {
  console.error("ERROR: " + (e?.message || String(e)));
  process.exit(1);
});

