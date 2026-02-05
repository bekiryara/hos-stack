/* eslint-disable no-console */
/**
 * Export karavan subtypes as categories + brand rules as select options.
 *
 * Writes:
 * - catalog/manifests/categories/vehicle-karavan-subtypes.json
 * - catalog/manifests/rules/vehicle/by_category/karavan-motokaravan/vehicle_brand.tr.json
 * - catalog/manifests/rules/vehicle/by_category/karavan-cekme-karavan/vehicle_brand.tr.json
 * - catalog/manifests/schema/vehicle-karavan-subtypes.json
 *
 * Note: Arabam karavan pages do NOT expose a structured model facet, so only brand is selectable;
 * model remains a free-text field.
 *
 * Usage:
 *   node scripts/arabam-export-karavan-subtypes-brand-rules.js --write
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

function sortTr(list) {
  return [...list].sort((a, b) => String(a).localeCompare(String(b), "tr"));
}

function uniq(list) {
  const seen = new Set();
  const out = [];
  for (const x of list) {
    const v = String(x || "").trim();
    if (!v || seen.has(v)) continue;
    seen.add(v);
    out.push(v);
  }
  return out;
}

function getFacet(o, property) {
  const facets = o?.Data?.Facets || [];
  return facets.find((f) => f?.Property === property);
}

function facetOptions(facet) {
  const items = facet?.Items || [];
  return sortTr(
    uniq(
      items
        .map((i) => (typeof i?.Name === "string" ? i.Name.trim() : ""))
        .filter(Boolean)
    )
  );
}

async function main() {
  const args = parseArgs(process.argv);
  const repoRoot = path.resolve(__dirname, "..");
  const manifestsRoot = path.join(repoRoot, "catalog", "manifests");

  const subtypes = [
    { slug: "karavan-motokaravan", title: "Motokaravan", rel: "ikinci-el/karavan-motokaravan", sort_order: 10 },
    { slug: "karavan-cekme-karavan", title: "Çekme Karavan", rel: "ikinci-el/karavan-cekme-karavan", sort_order: 20 },
  ];

  const categories = subtypes.map((s) => ({
    slug: s.slug,
    parent_slug: "karavan",
    title: s.title,
    status: "active",
    sort_order: s.sort_order,
  }));

  const rulesBySlug = {};
  for (const s of subtypes) {
    const o = await fetchFacets(s.rel);
    const brandFacet = getFacet(o, "aracmarkasi");
    const opts = facetOptions(brandFacet);
    // Rules manifests in this repo are plain string arrays.
    rulesBySlug[s.slug] = opts;
    console.log(`${s.slug} brands=${opts.length}`);
  }

  // Schema blocks for subtypes: override brand as select + keep model as text
  const baseFields = [
    { attribute_key: "city", ui_component: "select", required: false, filter_mode: "exact", rules: null, rules_ref: "cities.tr.json", sort_order: 5, applies_to_transaction_modes: null },
    // vehicle_brand overridden per subtype
    { attribute_key: "vehicle_model", ui_component: "text", required: false, filter_mode: "exact", rules: null, sort_order: 20, applies_to_transaction_modes: null },
    { attribute_key: "vehicle_year", ui_component: "number", required: false, filter_mode: "range", rules: { min: 1950, max: 2035 }, sort_order: 30, applies_to_transaction_modes: null },
    { attribute_key: "vehicle_transmission", ui_component: "select", required: false, filter_mode: "exact", rules: null, rules_ref: "rules/vehicle/by_category/karavan/vehicle_transmission.tr.json", sort_order: 50, applies_to_transaction_modes: null },
    { attribute_key: "vehicle_seller_type", ui_component: "select", required: false, filter_mode: "exact", rules: null, rules_ref: "rules/vehicle/by_category/karavan/vehicle_seller_type.tr.json", sort_order: 59, applies_to_transaction_modes: null },
    { attribute_key: "vehicle_km", ui_component: "number", required: false, filter_mode: "range", rules: { min: 0, max: 2000000 }, sort_order: 60, applies_to_transaction_modes: null },
    { attribute_key: "vehicle_listing_age", ui_component: "select", required: false, filter_mode: "exact", rules: null, rules_ref: "rules/vehicle/by_category/karavan/vehicle_listing_age.tr.json", sort_order: 66, applies_to_transaction_modes: null },
    { attribute_key: "vehicle_price", ui_component: "number", required: false, filter_mode: "range", rules: { min: 0, max: 1000000000 }, sort_order: 70, applies_to_transaction_modes: ["sale"] },
    { attribute_key: "vehicle_price_per_day", ui_component: "number", required: false, filter_mode: "range", rules: { min: 0, max: 1000000 }, sort_order: 80, applies_to_transaction_modes: ["rental"] },
    { attribute_key: "vehicle_min_rent_days", ui_component: "number", required: false, filter_mode: "range", rules: { min: 1, max: 365 }, sort_order: 90, applies_to_transaction_modes: ["rental"] },
  ];

  const schema = [];
  for (const s of subtypes) {
    schema.push({
      schema_version: 1,
      category_slugs: [s.slug],
      fields: [
        baseFields[0],
        {
          attribute_key: "vehicle_brand",
          ui_component: "select",
          required: false,
          filter_mode: "exact",
          rules: null,
          rules_ref: `rules/vehicle/by_category/${s.slug}/vehicle_brand.tr.json`,
          sort_order: 10,
          applies_to_transaction_modes: null,
        },
        ...baseFields.slice(1),
      ],
    });
  }

  if (!args.write) {
    console.log("\nDry-run: use --write to write manifests.");
    return;
  }

  const catPath = path.join(manifestsRoot, "categories", "vehicle-karavan-subtypes.json");
  fs.writeFileSync(catPath, JSON.stringify(categories, null, 2) + "\n", "utf8");
  console.log("wrote " + catPath);

  for (const s of subtypes) {
    const rulesPath = path.join(manifestsRoot, "rules", "vehicle", "by_category", s.slug, "vehicle_brand.tr.json");
    fs.mkdirSync(path.dirname(rulesPath), { recursive: true });
    fs.writeFileSync(rulesPath, JSON.stringify(rulesBySlug[s.slug], null, 2) + "\n", "utf8");
    console.log("wrote " + rulesPath);
  }

  const schemaPath = path.join(manifestsRoot, "schema", "vehicle-karavan-subtypes.json");
  fs.writeFileSync(schemaPath, JSON.stringify(schema, null, 2) + "\n", "utf8");
  console.log("wrote " + schemaPath);
}

main().catch((e) => {
  console.error("ERROR: " + (e?.message || String(e)));
  process.exit(1);
});

