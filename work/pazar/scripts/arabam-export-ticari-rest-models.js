/* eslint-disable no-console */
/**
 * Export remaining ticari-arac subtypes (except minibus-midibus/otobus).
 *
 * Writes:
 * - catalog/manifests/categories/vehicle-ticari-rest.json
 * - catalog/manifests/vehicle-ticari-rest-models.arabam.tr.json
 * - catalog/manifests/schema/vehicle-ticari-rest-models.json
 *
 * Usage:
 *   node scripts/arabam-export-ticari-rest-models.js --write
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

function stripQueryHash(s) {
  return String(s || "").split("?")[0].split("#")[0];
}

function normalizePathLike(s) {
  const raw = stripQueryHash(s).trim();
  if (!raw) return "";
  // If it's a full URL, remove protocol+host.
  const noProto = raw.replace(/^https?:\/\/[^/]+\//i, "");
  return noProto.replace(/^\/+/, "");
}

function pathSegments(s) {
  return normalizePathLike(s)
    .split("/")
    .map((x) => x.trim())
    .filter(Boolean);
}

function deriveItemSlug(item, subtypeKey) {
  const candidates = [item?.AbsoluteUrl, item?.AbsolutePath, item?.RelativeUrl].filter(Boolean);
  for (const c of candidates) {
    const segs = pathSegments(c);
    if (segs.length === 0) continue;

    // Prefer /ticari-arac/<subtypeKey>/<slug> or /<subtypeKey>/ticari-arac/<slug>
    const ticariIdx = segs.indexOf("ticari-arac");
    if (ticariIdx >= 0 && ticariIdx + 1 < segs.length) {
      const after = segs[ticariIdx + 1];
      if (after === subtypeKey && ticariIdx + 2 < segs.length) return segs[ticariIdx + 2];
      if (after.startsWith(subtypeKey + "-")) return after.slice(subtypeKey.length + 1);
      if (after) return after;
    }

    // Then try /<subtypeKey>/<slug> form (some pages are /ikinci-el/<subtypeKey>/ticari-arac/<slug>)
    const idx = segs.indexOf(subtypeKey);
    if (idx >= 0) {
      if (idx + 2 < segs.length && segs[idx + 1] === "ticari-arac") return segs[idx + 2];
      if (idx + 1 < segs.length && segs[idx + 1] !== "ticari-arac") return segs[idx + 1];
    }

    const last = segs[segs.length - 1];
    if (last.startsWith(subtypeKey + "-")) return last.slice(subtypeKey.length + 1);
  }

  // Fallback: last segment of any candidate
  for (const c of candidates) {
    const segs = pathSegments(c);
    if (segs.length) return segs[segs.length - 1];
  }
  return "";
}

async function fetchJsonByRelativeOrAbsoluteUrl(relOrAbs, timeoutMs = 25000) {
  const rel = normalizePathLike(relOrAbs);
  const pageUrl = BASE + rel;
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

const SUBTYPES = [
  { key: "kamyon-kamyonet", title: "Kamyon & Kamyonet", rel: "ikinci-el/ticari-arac/kamyon-kamyonet", sort: 30 },
  { key: "cekici", title: "Çekici", rel: "ikinci-el/ticari-arac/cekici", sort: 40 },
  { key: "dorse", title: "Dorse", rel: "ikinci-el/ticari-arac/dorse", sort: 50 },
  { key: "romork", title: "Römork", rel: "ikinci-el/ticari-arac/romork", sort: 60 },
  { key: "karoser-ust-yapi", title: "Karoser & Üst Yapı", rel: "ikinci-el/ticari-arac/karoser-ust-yapi", sort: 70 },
  { key: "oto-kurtarici-tasiyici", title: "Oto Kurtarıcı & Taşıyıcı", rel: "ikinci-el/ticari-arac/oto-kurtarici-tasiyici", sort: 80 },
  { key: "ticari-hat-plaka", title: "Ticari Hat & Plaka", rel: "ikinci-el/ticari-arac/ticari-hat-plaka", sort: 90 },
];

async function exportSubtype(subtype) {
  const o = await fetchJsonByRelativeOrAbsoluteUrl(subtype.rel);
  const items = subcategories(o);

  const childCats = [];
  const modelDict = {}; // category_slug -> models[]

  for (const it of items) {
    const name = typeof it?.Name === "string" ? it.Name.trim() : "";
    const rel = it?.RelativeUrl;
    if (!name || !rel) continue;

    const itemSlug = deriveItemSlug(it, subtype.key);
    if (!itemSlug) continue;

    const catSlug = `ticari-arac-${subtype.key}-${itemSlug}`;
    childCats.push({ slug: catSlug, title: name, rel });

    const io = await fetchJsonByRelativeOrAbsoluteUrl(rel);
    const models = sortTr(
      uniq(
        subcategories(io)
          .map((x) => (typeof x?.Name === "string" ? x.Name.trim() : ""))
          .filter(Boolean)
      )
    );

    if (models.length > 0) {
      modelDict[catSlug] = models;
      console.log(`models ${catSlug} = ${models.length}`);
    } else {
      console.log(`models ${catSlug} = 0 (no model options)`);
    }
  }

  return { subtype, childCats, modelDict };
}

async function main() {
  const args = parseArgs(process.argv);
  const repoRoot = path.resolve(__dirname, "..");
  const manifestsRoot = path.join(repoRoot, "catalog", "manifests");

  const exports = [];
  for (const s of SUBTYPES) {
    exports.push(await exportSubtype(s));
  }

  // categories manifest
  const categories = [];
  for (const ex of exports) {
    categories.push({
      slug: `ticari-arac-${ex.subtype.key}`,
      parent_slug: "ticari-arac",
      title: ex.subtype.title,
      status: "active",
      sort_order: ex.subtype.sort,
    });
    // keep stable ordering: use name sort (TR)
    const ordered = [...ex.childCats].sort((a, b) => String(a.title).localeCompare(String(b.title), "tr"));
    let order = 10;
    for (const c of ordered) {
      categories.push({
        slug: c.slug,
        parent_slug: `ticari-arac-${ex.subtype.key}`,
        title: c.title,
        status: "active",
        sort_order: order,
      });
      order += 10;
    }
  }

  // merge model dicts
  const brand_slug_to_models = {};
  for (const ex of exports) {
    for (const [k, v] of Object.entries(ex.modelDict)) brand_slug_to_models[k] = v;
  }

  const outModels = {
    source: "arabam.com GetFacets (ticari-arac rest subtypes)",
    generated_at: new Date().toISOString(),
    stats: {
      category_slugs_with_models_total: Object.keys(brand_slug_to_models).length,
      models_total: Object.values(brand_slug_to_models).reduce((a, v) => a + (Array.isArray(v) ? v.length : 0), 0),
    },
    brand_slug_to_models,
  };

  const schema = {
    schema_version: 1,
    category_slugs: Object.keys(brand_slug_to_models).sort((a, b) => String(a).localeCompare(String(b), "tr")),
    fields: [
      { attribute_key: "city", ui_component: "select", required: false, filter_mode: "exact", rules: null, rules_ref: "cities.tr.json", sort_order: 5, applies_to_transaction_modes: null },

      {
        attribute_key: "vehicle_model",
        ui_component: "select",
        required: false,
        filter_mode: "exact",
        rules: null,
        rules_ref: { type: "vehicle_models_by_brand_slug", path: "vehicle-ticari-rest-models.arabam.tr.json" },
        sort_order: 20,
        applies_to_transaction_modes: null,
      },
      { attribute_key: "vehicle_seat_count", ui_component: "select", required: false, filter_mode: "exact", rules: null, rules_ref: "rules/vehicle/by_category/ticari-arac/vehicle_seat_count.tr.json", sort_order: 22, applies_to_transaction_modes: null },
      { attribute_key: "vehicle_upper_body", ui_component: "select", required: false, filter_mode: "exact", rules: null, rules_ref: "rules/vehicle/by_category/ticari-arac/vehicle_upper_body.tr.json", sort_order: 24, applies_to_transaction_modes: null },

      { attribute_key: "vehicle_year", ui_component: "number", required: false, filter_mode: "range", rules: { min: 1950, max: 2035 }, sort_order: 30, applies_to_transaction_modes: null },
      { attribute_key: "vehicle_fuel_type", ui_component: "select", required: false, filter_mode: "exact", rules: null, rules_ref: "rules/vehicle/by_category/ticari-arac/vehicle_fuel_type.tr.json", sort_order: 40, applies_to_transaction_modes: null },
      { attribute_key: "vehicle_transmission", ui_component: "select", required: false, filter_mode: "exact", rules: null, rules_ref: "rules/vehicle/by_category/ticari-arac/vehicle_transmission.tr.json", sort_order: 50, applies_to_transaction_modes: null },
      { attribute_key: "vehicle_color", ui_component: "select", required: false, filter_mode: "exact", rules: null, rules_ref: "rules/vehicle/by_category/ticari-arac/vehicle_color.tr.json", sort_order: 56, applies_to_transaction_modes: null },
      { attribute_key: "vehicle_condition", ui_component: "select", required: false, filter_mode: "exact", rules: null, rules_ref: "rules/vehicle/by_category/ticari-arac/vehicle_condition.tr.json", sort_order: 58, applies_to_transaction_modes: null },
      { attribute_key: "vehicle_seller_type", ui_component: "select", required: false, filter_mode: "exact", rules: null, rules_ref: "rules/vehicle/by_category/ticari-arac/vehicle_seller_type.tr.json", sort_order: 59, applies_to_transaction_modes: null },

      { attribute_key: "vehicle_km", ui_component: "number", required: false, filter_mode: "range", rules: { min: 0, max: 2000000 }, sort_order: 60, applies_to_transaction_modes: null },
      { attribute_key: "vehicle_damage_status", ui_component: "select", required: false, filter_mode: "exact", rules: null, rules_ref: "rules/vehicle/by_category/ticari-arac/vehicle_damage_status.tr.json", sort_order: 63, applies_to_transaction_modes: null },
      { attribute_key: "vehicle_heavy_damage_record", ui_component: "boolean", required: false, filter_mode: "exact", rules: null, sort_order: 64, applies_to_transaction_modes: null },
      { attribute_key: "vehicle_swap", ui_component: "boolean", required: false, filter_mode: "exact", rules: null, sort_order: 65, applies_to_transaction_modes: null },
      { attribute_key: "vehicle_listing_age", ui_component: "select", required: false, filter_mode: "exact", rules: null, rules_ref: "rules/vehicle/by_category/ticari-arac/vehicle_listing_age.tr.json", sort_order: 66, applies_to_transaction_modes: null },

      { attribute_key: "vehicle_price", ui_component: "number", required: false, filter_mode: "range", rules: { min: 0, max: 1000000000 }, sort_order: 70, applies_to_transaction_modes: ["sale"] },
    ],
  };

  console.log("\nsummary categories_rows=" + categories.length);
  console.log("summary category_slugs_with_models=" + Object.keys(brand_slug_to_models).length);
  console.log("summary models_total=" + outModels.stats.models_total);

  if (!args.write) {
    console.log("\nDry-run: use --write to write manifests.");
    return;
  }

  const catPath = path.join(manifestsRoot, "categories", "vehicle-ticari-rest.json");
  fs.writeFileSync(catPath, JSON.stringify(categories, null, 2) + "\n", "utf8");
  console.log("wrote " + catPath);

  const modelPath = path.join(manifestsRoot, "vehicle-ticari-rest-models.arabam.tr.json");
  fs.writeFileSync(modelPath, JSON.stringify(outModels, null, 2) + "\n", "utf8");
  console.log("wrote " + modelPath);

  const schemaPath = path.join(manifestsRoot, "schema", "vehicle-ticari-rest-models.json");
  fs.writeFileSync(schemaPath, JSON.stringify(schema, null, 2) + "\n", "utf8");
  console.log("wrote " + schemaPath);
}

main().catch((e) => {
  console.error("ERROR: " + (e?.message || String(e)));
  process.exit(1);
});

