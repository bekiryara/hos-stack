/* eslint-disable no-console */
/**
 * Export Damaged Vehicles (hasarli-araclar) subtypes + brand categories + models.
 *
 * Structure on arabam.com:
 * - /ikinci-el/hasarli-araclar -> subtypes (otomobil, arazi-suv-pick-up, minivan-panelvan, ticari-arac, motosiklet)
 * - For most subtypes: subtype page -> brands -> brand page SubCategories are models (sometimes sparse)
 * - For hasarli/ticari-arac: subtype page -> ticari subtypes (cekici, kamyon-kamyonet, minibus-midibus) -> brands -> models
 * - For hasarli/motosiklet: brand pages typically expose NO model SubCategories; keep vehicle_model as text.
 *
 * Writes:
 * - catalog/manifests/categories/vehicle-hasarli-araclar-subtypes.json
 * - catalog/manifests/categories/vehicle-hasarli-araclar-brands.json
 * - catalog/manifests/vehicle-hasarli-araclar-models.arabam.tr.json
 * - catalog/manifests/schema/vehicle-hasarli-araclar-models.json           (model dropdown)
 * - catalog/manifests/schema/vehicle-hasarli-araclar-brands-no-models.json (model text)
 *
 * Usage:
 *   node scripts/arabam-export-hasarli-araclar.js --write
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
  { key: "otomobil", title: "Otomobil", rel: "ikinci-el/hasarli-araclar/otomobil", sort_order: 10 },
  { key: "arazi-suv-pick-up", title: "Arazi, SUV, Pick-up", rel: "ikinci-el/hasarli-araclar/arazi-suv-pick-up", sort_order: 20 },
  { key: "minivan-panelvan", title: "Minivan & Panelvan", rel: "ikinci-el/hasarli-araclar/minivan-panelvan", sort_order: 30 },
  { key: "ticari-arac", title: "Ticari Araç", rel: "ikinci-el/hasarli-araclar/ticari-arac", sort_order: 40 },
  { key: "motosiklet", title: "Motosiklet", rel: "ikinci-el/hasarli-araclar/motosiklet", sort_order: 50 },
];

function baseHasarliFields(modelField) {
  // Use existing by_category rules for hasarli-araclar (shared across subtypes)
  return [
    { attribute_key: "city", ui_component: "select", required: false, filter_mode: "exact", rules: null, rules_ref: "cities.tr.json", sort_order: 5, applies_to_transaction_modes: null },
    modelField,
    { attribute_key: "vehicle_year", ui_component: "number", required: false, filter_mode: "range", rules: { min: 1950, max: 2035 }, sort_order: 30, applies_to_transaction_modes: null },
    { attribute_key: "vehicle_fuel_type", ui_component: "select", required: false, filter_mode: "exact", rules: null, rules_ref: "rules/vehicle/by_category/hasarli-araclar/vehicle_fuel_type.tr.json", sort_order: 40, applies_to_transaction_modes: null },
    { attribute_key: "vehicle_transmission", ui_component: "select", required: false, filter_mode: "exact", rules: null, rules_ref: "rules/vehicle/by_category/hasarli-araclar/vehicle_transmission.tr.json", sort_order: 50, applies_to_transaction_modes: null },
    { attribute_key: "vehicle_color", ui_component: "select", required: false, filter_mode: "exact", rules: null, rules_ref: "rules/vehicle/by_category/hasarli-araclar/vehicle_color.tr.json", sort_order: 56, applies_to_transaction_modes: null },
    { attribute_key: "vehicle_seller_type", ui_component: "select", required: false, filter_mode: "exact", rules: null, rules_ref: "rules/vehicle/by_category/hasarli-araclar/vehicle_seller_type.tr.json", sort_order: 59, applies_to_transaction_modes: null },
    { attribute_key: "vehicle_km", ui_component: "number", required: false, filter_mode: "range", rules: { min: 0, max: 2000000 }, sort_order: 60, applies_to_transaction_modes: null },
    { attribute_key: "vehicle_damage_status", ui_component: "select", required: false, filter_mode: "exact", rules: null, rules_ref: "rules/vehicle/by_category/hasarli-araclar/vehicle_damage_status.tr.json", sort_order: 63, applies_to_transaction_modes: null },
    { attribute_key: "vehicle_heavy_damage_record", ui_component: "boolean", required: false, filter_mode: "exact", rules: null, sort_order: 64, applies_to_transaction_modes: null },
    { attribute_key: "vehicle_swap", ui_component: "boolean", required: false, filter_mode: "exact", rules: null, sort_order: 65, applies_to_transaction_modes: null },
    { attribute_key: "vehicle_listing_age", ui_component: "select", required: false, filter_mode: "exact", rules: null, rules_ref: "rules/vehicle/by_category/hasarli-araclar/vehicle_listing_age.tr.json", sort_order: 66, applies_to_transaction_modes: null },
    { attribute_key: "vehicle_price", ui_component: "number", required: false, filter_mode: "range", rules: { min: 0, max: 1000000000 }, sort_order: 70, applies_to_transaction_modes: ["sale"] },
  ];
}

async function exportBrandLeaf(parentSlug, brandName, brandRel) {
  const brandSlug = slugifyKey(lastPathSegment(brandRel));
  const catSlug = `${parentSlug}-${brandSlug}`;

  const bo = await fetchFacets(brandRel);
  const models = sortTr(
    uniq(
      subcategories(bo)
        .map((m) => (typeof m?.Name === "string" ? m.Name.trim() : ""))
        .filter(Boolean)
    )
  );

  return { catSlug, brandSlug, models };
}

async function main() {
  const args = parseArgs(process.argv);
  const repoRoot = path.resolve(__dirname, "..");
  const manifestsRoot = path.join(repoRoot, "catalog", "manifests");

  const subtypeCats = SUBTYPES.map((s) => ({
    slug: `hasarli-araclar-${s.key}`,
    parent_slug: "hasarli-araclar",
    title: s.title,
    status: "active",
    sort_order: s.sort_order,
  }));

  const cats = []; // includes ticari sub-subtypes + all brand leaves
  const modelDict = {}; // brand_leaf_slug -> models[]
  const noModelCats = [];

  for (const s of SUBTYPES) {
    const subtypeSlug = `hasarli-araclar-${s.key}`;
    const o = await fetchFacets(s.rel);
    const subs = subcategories(o)
      .map((x) => ({
        name: typeof x?.Name === "string" ? x.Name.trim() : "",
        rel: typeof x?.RelativeUrl === "string" ? x.RelativeUrl.trim() : "",
      }))
      .filter((x) => x.name && x.rel);

    if (s.key === "ticari-arac") {
      // subs here are ticari subtypes (cekici, kamyon-kamyonet, minibus-midibus)
      const ordered = sortTr(uniq(subs.map((x) => x.name))).map((name) => subs.find((x) => x.name === name));
      let stOrder = 10;
      for (const st of ordered) {
        if (!st?.rel) continue;
        const subSlug = slugifyKey(lastPathSegment(st.rel));
        const stCatSlug = `${subtypeSlug}-${subSlug}`;
        cats.push({ slug: stCatSlug, parent_slug: subtypeSlug, title: st.name, status: "active", sort_order: stOrder });
        stOrder += 10;

        const stO = await fetchFacets(st.rel);
        const brands = subcategories(stO)
          .map((x) => ({
            name: typeof x?.Name === "string" ? x.Name.trim() : "",
            rel: typeof x?.RelativeUrl === "string" ? x.RelativeUrl.trim() : "",
          }))
          .filter((x) => x.name && x.rel);

        const orderedBrands = sortTr(uniq(brands.map((b) => b.name))).map((name) => brands.find((b) => b.name === name));
        let bOrder = 10;
        for (const b of orderedBrands) {
          if (!b?.rel) continue;
          const { catSlug, models } = await exportBrandLeaf(stCatSlug, b.name, b.rel);
          cats.push({ slug: catSlug, parent_slug: stCatSlug, title: b.name, status: "active", sort_order: bOrder });
          bOrder += 10;
          if (models.length > 0) {
            modelDict[catSlug] = models;
            console.log(`models ${catSlug} = ${models.length}`);
          } else {
            noModelCats.push(catSlug);
            console.log(`models ${catSlug} = 0`);
          }
        }
      }
      continue;
    }

    // regular subtype: subs are brands
    const orderedBrands = sortTr(uniq(subs.map((b) => b.name))).map((name) => subs.find((b) => b.name === name));
    let order = 10;
    for (const b of orderedBrands) {
      if (!b?.rel) continue;
      const parentSlug = subtypeSlug;
      const { catSlug, models } = await exportBrandLeaf(parentSlug, b.name, b.rel);
      cats.push({ slug: catSlug, parent_slug: parentSlug, title: b.name, status: "active", sort_order: order });
      order += 10;

      if (models.length > 0) {
        modelDict[catSlug] = models;
        console.log(`models ${catSlug} = ${models.length}`);
      } else {
        noModelCats.push(catSlug);
        console.log(`models ${catSlug} = 0`);
      }
    }
  }

  const outModels = {
    source: "arabam.com GetFacets (hasarli-araclar)",
    generated_at: new Date().toISOString(),
    stats: {
      brand_categories_total: cats.filter((c) => c.parent_slug && c.slug.includes("hasarli-araclar-")).length,
      brand_categories_with_models_total: Object.keys(modelDict).length,
      brand_categories_without_models_total: noModelCats.length,
      models_total: Object.values(modelDict).reduce((a, v) => a + (Array.isArray(v) ? v.length : 0), 0),
    },
    brand_slug_to_models: modelDict,
  };

  const schemaModels = {
    schema_version: 1,
    category_slugs: Object.keys(modelDict).sort((a, b) => String(a).localeCompare(String(b), "tr")),
    fields: baseHasarliFields({
      attribute_key: "vehicle_model",
      ui_component: "select",
      required: false,
      filter_mode: "exact",
      rules: null,
      rules_ref: { type: "vehicle_models_by_brand_slug", path: "vehicle-hasarli-araclar-models.arabam.tr.json" },
      sort_order: 20,
      applies_to_transaction_modes: null,
    }),
  };

  const schemaNoModels = {
    schema_version: 1,
    category_slugs: sortTr(noModelCats),
    fields: baseHasarliFields({
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
  console.log("summary categories_written=" + cats.length);
  console.log("summary with_models=" + outModels.stats.brand_categories_with_models_total);
  console.log("summary without_models=" + outModels.stats.brand_categories_without_models_total);
  console.log("summary models_total=" + outModels.stats.models_total);

  if (!args.write) {
    console.log("\nDry-run: use --write to write manifests.");
    return;
  }

  const subPath = path.join(manifestsRoot, "categories", "vehicle-hasarli-araclar-subtypes.json");
  fs.writeFileSync(subPath, JSON.stringify(subtypeCats, null, 2) + "\n", "utf8");
  console.log("wrote " + subPath);

  const catsPath = path.join(manifestsRoot, "categories", "vehicle-hasarli-araclar-brands.json");
  fs.writeFileSync(catsPath, JSON.stringify(cats, null, 2) + "\n", "utf8");
  console.log("wrote " + catsPath);

  const modelPath = path.join(manifestsRoot, "vehicle-hasarli-araclar-models.arabam.tr.json");
  fs.writeFileSync(modelPath, JSON.stringify(outModels, null, 2) + "\n", "utf8");
  console.log("wrote " + modelPath);

  const schemaModelsPath = path.join(manifestsRoot, "schema", "vehicle-hasarli-araclar-models.json");
  fs.writeFileSync(schemaModelsPath, JSON.stringify(schemaModels, null, 2) + "\n", "utf8");
  console.log("wrote " + schemaModelsPath);

  const schemaNoModelsPath = path.join(manifestsRoot, "schema", "vehicle-hasarli-araclar-brands-no-models.json");
  fs.writeFileSync(schemaNoModelsPath, JSON.stringify(schemaNoModels, null, 2) + "\n", "utf8");
  console.log("wrote " + schemaNoModelsPath);
}

main().catch((e) => {
  console.error("ERROR: " + (e?.message || String(e)));
  process.exit(1);
});

