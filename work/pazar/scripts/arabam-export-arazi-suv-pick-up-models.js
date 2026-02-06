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

function facetOptionsByFriendly(data) {
  const facets = (data && data.Data && Array.isArray(data.Data.Facets) ? data.Data.Facets : []) || [];
  const out = {};
  for (const f of facets) {
    const friendly = typeof f?.FriendlyUrlName === "string" ? f.FriendlyUrlName : "";
    const items = Array.isArray(f?.Items) ? f.Items : [];
    if (!friendly || items.length === 0) continue;
    out[friendly] = items.map((i) => (typeof i?.Name === "string" ? i.Name.trim() : "")).filter(Boolean);
  }
  return out;
}

function brandSlugFromRelativeUrl(rel) {
  const parts = String(rel || "").split("?")[0].split("#")[0].split("/").filter(Boolean);
  const idx = parts.indexOf("arazi-suv-pick-up");
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

  const rootRel = "ikinci-el/arazi-suv-pick-up";
  const root = await fetchFacets(rootRel);
  const brands = subcategories(root)
    .map((x) => ({
      name: typeof x?.Name === "string" ? x.Name.trim() : "",
      rel: typeof x?.RelativeUrl === "string" ? x.RelativeUrl.trim() : "",
      isBrand: x?.IsBrand === true,
    }))
    .filter((b) => b.isBrand && b.name && b.rel);

  // IMPORTANT: preserve Arabam-provided ordering ("birebir")
  const orderedBrands = [...brands];

  const categories = [];
  const dict = {};
  const catSlugToFacetMap = {};

  // Categories (brands) keep ordering by increasing sort_order.
  let sortOrder = 10;
  for (const b of orderedBrands) {
    const brandSlug = brandSlugFromRelativeUrl(b.rel);
    categories.push({ slug: `arazi-suv-pick-up-${brandSlug}`, parent_slug: "arazi-suv-pick-up", title: b.name, status: "active", sort_order: sortOrder });
    sortOrder += 10;
  }

  // Build model dict + facet map for each brand category (concurrent)
  const concurrency = 8;
  await mapLimit(orderedBrands, concurrency, async (b) => {
    const brandSlug = brandSlugFromRelativeUrl(b.rel);
    const catSlug = `arazi-suv-pick-up-${brandSlug}`;
    const bo = await fetchFacets(b.rel);
    // IMPORTANT: preserve Arabam model ordering (no sorting)
    const models = uniq(subcategories(bo).map((m) => (typeof m?.Name === "string" ? m.Name.trim() : "")).filter(Boolean));
    dict[catSlug] = models;
    catSlugToFacetMap[catSlug] = facetOptionsByFriendly(bo);
    console.log(`models ${catSlug} = ${models.length}`);
  });

  const outModels = {
    source: "arabam.com GetFacets (arazi-suv-pick-up)",
    generated_at: new Date().toISOString(),
    stats: {
      brand_categories_total: Object.keys(dict).length,
      models_total: Object.values(dict).reduce((a, v) => a + (Array.isArray(v) ? v.length : 0), 0),
    },
    brand_slug_to_models: dict,
  };

  function buildFieldsFromFacets(facetMap, { hasModels } = {}) {
    const fields = [];
    const has = (friendly) => Object.prototype.hasOwnProperty.call(facetMap, friendly) && Array.isArray(facetMap[friendly]) && facetMap[friendly].length > 0;

    if (has("il")) {
      // IMPORTANT: Arabam city options are page-specific (only cities with listings).
      // Inline to stay "birebir" instead of using our global cities list.
      fields.push({ attribute_key: "city", ui_component: "select", required: false, filter_mode: "exact", rules: { options: facetMap["il"] }, sort_order: 5, applies_to_transaction_modes: null });
    }

    if (hasModels) {
      fields.push({
        attribute_key: "vehicle_model",
        ui_component: "select",
        required: false,
        filter_mode: "exact",
        rules: null,
        rules_ref: { type: "vehicle_models_by_brand_slug", path: "vehicle-arazi-suv-pick-up-models.arabam.tr.json" },
        sort_order: 20,
        applies_to_transaction_modes: null,
      });
    }

    if (has("yil")) {
      fields.push({ attribute_key: "vehicle_year", ui_component: "number", required: false, filter_mode: "range", rules: { min: 1950, max: 2035 }, sort_order: 30, applies_to_transaction_modes: null });
    }

    if (has("kilometre")) {
      fields.push({ attribute_key: "vehicle_km_bucket", ui_component: "select", required: false, filter_mode: "exact", rules: { options: facetMap["kilometre"] }, sort_order: 32, applies_to_transaction_modes: null });
    }

    if (has("yakit-tipi")) {
      fields.push({ attribute_key: "vehicle_fuel_type", ui_component: "select", required: false, filter_mode: "exact", rules: { options: facetMap["yakit-tipi"] }, sort_order: 40, applies_to_transaction_modes: null });
    }
    if (has("vites-tipi")) {
      fields.push({ attribute_key: "vehicle_transmission", ui_component: "select", required: false, filter_mode: "exact", rules: { options: facetMap["vites-tipi"] }, sort_order: 50, applies_to_transaction_modes: null });
    }
    if (has("kasa-tipi")) {
      fields.push({ attribute_key: "vehicle_body_type", ui_component: "select", required: false, filter_mode: "exact", rules: { options: facetMap["kasa-tipi"] }, sort_order: 55, applies_to_transaction_modes: null });
    }
    if (has("renk")) {
      fields.push({ attribute_key: "vehicle_color", ui_component: "select", required: false, filter_mode: "exact", rules: { options: facetMap["renk"] }, sort_order: 56, applies_to_transaction_modes: null });
    }
    if (has("cekis")) {
      fields.push({ attribute_key: "vehicle_drive_type", ui_component: "select", required: false, filter_mode: "exact", rules: { options: facetMap["cekis"] }, sort_order: 57, applies_to_transaction_modes: null });
    }

    if (has("motor-gucu")) {
      fields.push({ attribute_key: "vehicle_engine_power_bucket", ui_component: "select", required: false, filter_mode: "exact", rules: { options: facetMap["motor-gucu"] }, sort_order: 52, applies_to_transaction_modes: null });
    }
    if (has("motor-hacmi")) {
      fields.push({ attribute_key: "vehicle_engine_displacement_bucket", ui_component: "select", required: false, filter_mode: "exact", rules: { options: facetMap["motor-hacmi"] }, sort_order: 53, applies_to_transaction_modes: null });
    }

    if (has("donanim")) {
      fields.push({ attribute_key: "vehicle_equipment", ui_component: "select", required: false, filter_mode: "exact", rules: { options: facetMap["donanim"] }, sort_order: 61, applies_to_transaction_modes: null });
    }

    if (has("arac-durumu")) {
      fields.push({ attribute_key: "vehicle_condition", ui_component: "select", required: false, filter_mode: "exact", rules: { options: facetMap["arac-durumu"] }, sort_order: 58, applies_to_transaction_modes: null });
    }

    if (has("ilan-sahibi")) {
      fields.push({ attribute_key: "vehicle_seller_type", ui_component: "select", required: false, filter_mode: "exact", rules: { options: facetMap["ilan-sahibi"] }, sort_order: 59, applies_to_transaction_modes: null });
    }

    if (has("boya-degisen-parca")) {
      fields.push({ attribute_key: "vehicle_damage_status", ui_component: "select", required: false, filter_mode: "exact", rules: { options: facetMap["boya-degisen-parca"] }, sort_order: 63, applies_to_transaction_modes: null });
    }

    if (has("agir-hasar-kayitli")) {
      // Arabam returns explicit options: ["Ağır Hasar Kayıtlı", "Ağır Hasar Kayıtlı Değil"]
      fields.push({
        attribute_key: "vehicle_heavy_damage_record_status",
        ui_component: "select",
        required: false,
        filter_mode: "exact",
        rules: { options: facetMap["agir-hasar-kayitli"] },
        sort_order: 64,
        applies_to_transaction_modes: null,
      });
    }

    if (has("takasa-uygun")) {
      fields.push({ attribute_key: "vehicle_swap_status", ui_component: "select", required: false, filter_mode: "exact", rules: { options: facetMap["takasa-uygun"] }, sort_order: 65, applies_to_transaction_modes: null });
    }

    if (has("ilan-tarihi")) {
      fields.push({ attribute_key: "vehicle_listing_age", ui_component: "select", required: false, filter_mode: "exact", rules: { options: facetMap["ilan-tarihi"] }, sort_order: 66, applies_to_transaction_modes: null });
    }
    if (has("ozel-ilanlar")) {
      fields.push({ attribute_key: "vehicle_special_listing", ui_component: "select", required: false, filter_mode: "exact", rules: { options: facetMap["ozel-ilanlar"] }, sort_order: 67, applies_to_transaction_modes: null });
    }

    if (has("fiyat")) {
      fields.push({ attribute_key: "vehicle_price", ui_component: "number", required: false, filter_mode: "range", rules: { min: 0, max: 1000000000 }, sort_order: 70, applies_to_transaction_modes: ["sale"] });
    }

    return fields;
  }

  // Build schema blocks by grouping categories with identical field definitions.
  // NOTE: include root "arazi-suv-pick-up" too, since Arabam shows facets there.
  const rootFacetMap = facetOptionsByFriendly(root);
  const schemaTargets = ["arazi-suv-pick-up", ...Object.keys(dict)];
  const blocksByKey = new Map(); // key -> { fields, category_slugs }
  for (const slug of schemaTargets) {
    const facetMap = slug === "arazi-suv-pick-up" ? rootFacetMap : catSlugToFacetMap[slug] || {};
    const hasModels = slug !== "arazi-suv-pick-up" && Array.isArray(dict[slug]) && dict[slug].length > 0;
    const fields = buildFieldsFromFacets(facetMap, { hasModels });
    const key = JSON.stringify(fields);
    if (!blocksByKey.has(key)) blocksByKey.set(key, { fields, category_slugs: [] });
    blocksByKey.get(key).category_slugs.push(slug);
  }

  const schemaBlocks = Array.from(blocksByKey.values())
    .map((b) => ({ schema_version: 1, category_slugs: b.category_slugs, fields: b.fields }))
    .sort((a, b) => String(a.category_slugs?.[0] || "").localeCompare(String(b.category_slugs?.[0] || ""), "tr"));

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
  fs.writeFileSync(schemaPath, JSON.stringify(schemaBlocks, null, 2) + "\n", "utf8");
  console.log("wrote " + schemaPath);
}

main().catch((e) => {
  console.error("ERROR: " + (e?.message || String(e)));
  process.exit(1);
});

