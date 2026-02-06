/* eslint-disable no-console */
/**
 * Export "ticari-arac" schemas + leaf model dictionaries from arabam.com facets (birebir).
 *
 * Notes:
 * - Arabam root /ticari-arac does NOT expose brand subcategories; brands are a facet ("arac-markasi").
 * - Intermediate pages like /ticari-arac/minibus-midibus DO have facets and brand subcategories.
 * - Leaf brand pages like /ticari-arac/minibus-midibus/ford-otosan expose models as SelectedCategory.SubCategories (IsBrand=false).
 *
 * This exporter does NOT rebuild category trees. It uses our existing category manifests to know which slugs exist.
 *
 * Writes:
 * - catalog/manifests/vehicle-ticari-arac-models.arabam.tr.json (category_slug -> models[])
 * - catalog/manifests/schema/vehicle-ticari-arac.json (schema blocks array for root + intermediates + leaves)
 *
 * Usage:
 *   node scripts/arabam-export-ticari-arac-schemas.js --write
 */
const fs = require("fs");
const path = require("path");

const FACETS_ENDPOINT = "https://www.arabam.com/listing/GetFacets?url=";
const BASE = "https://www.arabam.com/";

function parseArgs(argv) {
  return { write: argv.includes("--write"), concurrency: 8 };
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

function buildFieldsFromFacets(facetMap, { includeModels } = {}) {
  const fields = [];
  const has = (friendly) => Object.prototype.hasOwnProperty.call(facetMap, friendly) && Array.isArray(facetMap[friendly]) && facetMap[friendly].length > 0;

  if (has("il")) {
    fields.push({ attribute_key: "city", ui_component: "select", required: false, filter_mode: "exact", rules: { options: facetMap.il }, sort_order: 5, applies_to_transaction_modes: null });
  }

  // Brand facet (root uses arac-markasi; intermediate pages often don't have it)
  if (has("arac-markasi")) {
    fields.push({ attribute_key: "vehicle_brand", ui_component: "select", required: false, filter_mode: "exact", rules: { options: facetMap["arac-markasi"] }, sort_order: 10, applies_to_transaction_modes: null });
  }

  if (includeModels) {
    fields.push({
      attribute_key: "vehicle_model",
      ui_component: "select",
      required: false,
      filter_mode: "exact",
      rules: null,
      rules_ref: { type: "vehicle_models_by_brand_slug", path: "vehicle-ticari-arac-models.arabam.tr.json" },
      sort_order: 20,
      applies_to_transaction_modes: null,
    });
  }

  if (has("koltuk-sayisi")) {
    fields.push({ attribute_key: "vehicle_seat_count", ui_component: "select", required: false, filter_mode: "exact", rules: { options: facetMap["koltuk-sayisi"] }, sort_order: 22, applies_to_transaction_modes: null });
  }
  if (has("ust-yapi")) {
    fields.push({ attribute_key: "vehicle_upper_body", ui_component: "select", required: false, filter_mode: "exact", rules: { options: facetMap["ust-yapi"] }, sort_order: 24, applies_to_transaction_modes: null });
  }
  if (has("sasi")) {
    fields.push({ attribute_key: "vehicle_chassis_type", ui_component: "select", required: false, filter_mode: "exact", rules: { options: facetMap.sasi }, sort_order: 25, applies_to_transaction_modes: null });
  }

  if (has("yil")) {
    fields.push({ attribute_key: "vehicle_year", ui_component: "number", required: false, filter_mode: "range", rules: { min: 1950, max: 2035 }, sort_order: 30, applies_to_transaction_modes: null });
  }
  if (has("kilometre")) {
    fields.push({ attribute_key: "vehicle_km_bucket", ui_component: "select", required: false, filter_mode: "exact", rules: { options: facetMap.kilometre }, sort_order: 32, applies_to_transaction_modes: null });
  }

  if (has("yakit-tipi")) {
    fields.push({ attribute_key: "vehicle_fuel_type", ui_component: "select", required: false, filter_mode: "exact", rules: { options: facetMap["yakit-tipi"] }, sort_order: 40, applies_to_transaction_modes: null });
  }
  if (has("vites-tipi")) {
    fields.push({ attribute_key: "vehicle_transmission", ui_component: "select", required: false, filter_mode: "exact", rules: { options: facetMap["vites-tipi"] }, sort_order: 50, applies_to_transaction_modes: null });
  }
  if (has("renk")) {
    fields.push({ attribute_key: "vehicle_color", ui_component: "select", required: false, filter_mode: "exact", rules: { options: facetMap.renk }, sort_order: 56, applies_to_transaction_modes: null });
  }

  if (has("motor-gucu")) {
    fields.push({ attribute_key: "vehicle_engine_power_bucket", ui_component: "select", required: false, filter_mode: "exact", rules: { options: facetMap["motor-gucu"] }, sort_order: 52, applies_to_transaction_modes: null });
  }

  if (has("donanim")) {
    fields.push({ attribute_key: "vehicle_equipment", ui_component: "select", required: false, filter_mode: "exact", rules: { options: facetMap.donanim }, sort_order: 61, applies_to_transaction_modes: null });
  }

  if (has("aracla-birlikte")) {
    fields.push({ attribute_key: "vehicle_with_vehicle", ui_component: "select", required: false, filter_mode: "exact", rules: { options: facetMap["aracla-birlikte"] }, sort_order: 62, applies_to_transaction_modes: null });
  }
  if (has("duraga-bagli")) {
    fields.push({ attribute_key: "vehicle_station_bound", ui_component: "select", required: false, filter_mode: "exact", rules: { options: facetMap["duraga-bagli"] }, sort_order: 63, applies_to_transaction_modes: null });
  }
  if (has("plaka")) {
    fields.push({ attribute_key: "vehicle_plate_status", ui_component: "select", required: false, filter_mode: "exact", rules: { options: facetMap.plaka }, sort_order: 64, applies_to_transaction_modes: null });
  }
  if (has("hisseli")) {
    fields.push({ attribute_key: "vehicle_share_status", ui_component: "select", required: false, filter_mode: "exact", rules: { options: facetMap.hisseli }, sort_order: 65, applies_to_transaction_modes: null });
  }

  if (has("arac-durumu")) {
    fields.push({ attribute_key: "vehicle_condition", ui_component: "select", required: false, filter_mode: "exact", rules: { options: facetMap["arac-durumu"] }, sort_order: 58, applies_to_transaction_modes: null });
  }

  if (has("boya-degisen-parca")) {
    fields.push({ attribute_key: "vehicle_damage_status", ui_component: "select", required: false, filter_mode: "exact", rules: { options: facetMap["boya-degisen-parca"] }, sort_order: 66, applies_to_transaction_modes: null });
  }
  if (has("agir-hasar-kayitli")) {
    fields.push({ attribute_key: "vehicle_heavy_damage_record_status", ui_component: "select", required: false, filter_mode: "exact", rules: { options: facetMap["agir-hasar-kayitli"] }, sort_order: 67, applies_to_transaction_modes: null });
  }
  if (has("takasa-uygun")) {
    fields.push({ attribute_key: "vehicle_swap_status", ui_component: "select", required: false, filter_mode: "exact", rules: { options: facetMap["takasa-uygun"] }, sort_order: 68, applies_to_transaction_modes: null });
  }

  if (has("ilan-sahibi")) {
    fields.push({ attribute_key: "vehicle_seller_type", ui_component: "select", required: false, filter_mode: "exact", rules: { options: facetMap["ilan-sahibi"] }, sort_order: 69, applies_to_transaction_modes: null });
  }
  if (has("ilan-tarihi")) {
    fields.push({ attribute_key: "vehicle_listing_age", ui_component: "select", required: false, filter_mode: "exact", rules: { options: facetMap["ilan-tarihi"] }, sort_order: 70, applies_to_transaction_modes: null });
  }
  if (has("ozel-ilanlar")) {
    fields.push({ attribute_key: "vehicle_special_listing", ui_component: "select", required: false, filter_mode: "exact", rules: { options: facetMap["ozel-ilanlar"] }, sort_order: 71, applies_to_transaction_modes: null });
  }
  if (has("fiyat")) {
    fields.push({ attribute_key: "vehicle_price", ui_component: "number", required: false, filter_mode: "range", rules: { min: 0, max: 1000000000 }, sort_order: 80, applies_to_transaction_modes: ["sale"] });
  }

  return fields;
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

function lastPathSegment(rel) {
  const parts = String(rel || "").split("?")[0].split("#")[0].split("/").filter(Boolean);
  return parts[parts.length - 1] || "";
}

async function main() {
  const args = parseArgs(process.argv);
  const repoRoot = path.resolve(__dirname, "..");
  const manifestsRoot = path.join(repoRoot, "catalog", "manifests");

  // Load existing ticari category slugs + parent mapping from our manifests
  const catFiles = [
    path.join(manifestsRoot, "categories", "vehicle-ticari-minibus-otobus.json"),
    path.join(manifestsRoot, "categories", "vehicle-ticari-rest.json"),
  ];
  const all = [];
  for (const fp of catFiles) {
    const arr = JSON.parse(fs.readFileSync(fp, "utf8"));
    if (Array.isArray(arr)) all.push(...arr);
  }
  const ticari = all.filter((c) => typeof c?.slug === "string" && String(c.slug).startsWith("ticari-arac"));
  const parentBy = {};
  const childrenBy = {};
  for (const c of ticari) {
    const slug = String(c.slug);
    const parent = typeof c?.parent_slug === "string" ? String(c.parent_slug) : null;
    parentBy[slug] = parent;
    if (!childrenBy[slug]) childrenBy[slug] = [];
    if (parent) {
      if (!childrenBy[parent]) childrenBy[parent] = [];
      childrenBy[parent].push(slug);
    }
  }

  const ROOT = "ticari-arac";
  if (!childrenBy[ROOT]) childrenBy[ROOT] = [];

  function relForComputed(slug) {
    if (slug === ROOT) return "ikinci-el/ticari-arac";
    const parent = parentBy[slug];
    if (!parent) throw new Error("Missing parent for slug=" + slug);
    if (!slug.startsWith(parent + "-")) throw new Error("Unexpected slug-parent relation: " + slug + " parent=" + parent);
    const segment = slug.slice(parent.length + 1);
    const parentRel = relForComputed(parent);
    return parentRel + "/" + segment;
  }

  const slugs = uniq([ROOT, ...Object.keys(parentBy)]);

  const slugToFacetMap = {};
  const modelsDict = {};
  const relBySlug = { [ROOT]: "ikinci-el/ticari-arac" };

  // Depth-order traversal so we can prefer Arabam-provided RelativeUrl for children.
  const depthBy = { [ROOT]: 0 };
  const byDepth = new Map();
  const q = [ROOT];
  while (q.length) {
    const p = q.shift();
    const d = depthBy[p] ?? 0;
    if (!byDepth.has(d)) byDepth.set(d, []);
    byDepth.get(d).push(p);
    const kids = childrenBy[p] || [];
    for (const k of kids) {
      if (depthBy[k] == null) {
        depthBy[k] = d + 1;
        q.push(k);
      }
    }
  }
  const maxDepth = Math.max(...Array.from(byDepth.keys()));

  const slugToData = {};
  for (let d = 0; d <= maxDepth; d++) {
    const level = byDepth.get(d) || [];
    // Ensure we have rel for everything in this level (fallback to computed).
    for (const slug of level) {
      if (!relBySlug[slug]) relBySlug[slug] = relForComputed(slug);
    }

    // Fetch this level in parallel
    const results = await mapLimit(level, args.concurrency, async (slug) => {
      const rel = relBySlug[slug];
      const data = await fetchFacets(rel);
      return { slug, rel, data };
    });

    for (const r of results) {
      slugToData[r.slug] = r.data;
      slugToFacetMap[r.slug] = facetOptionsByFriendly(r.data);

      const subs = subcategories(r.data);
      const isBrandList = subs.length > 0 && subs.every((s) => s?.IsBrand === true);
      const isModelList = subs.length > 0 && subs.every((s) => s?.IsBrand === false);
      const leaf = !(childrenBy[r.slug] && childrenBy[r.slug].length > 0);

      if (leaf && isModelList) {
        modelsDict[r.slug] = subs.map((s) => (typeof s?.Name === "string" ? s.Name.trim() : "")).filter(Boolean);
      }

      const kind = isBrandList ? "brands" : isModelList ? "models" : "none";
      console.log(`fetched ${r.slug} rel=${r.rel} depth=${d} facets=${Object.keys(slugToFacetMap[r.slug] || {}).length} subcats=${subs.length} kind=${kind} leaf=${leaf}`);
    }

    // After fetching this level, discover child RelativeUrl mappings from Arabam SubCategories.
    for (const slug of level) {
      const kids = childrenBy[slug] || [];
      if (!kids.length) continue;
      const data = slugToData[slug];
      const subs = subcategories(data);
      if (!subs.length) continue;
      const parentRel = relBySlug[slug] || relForComputed(slug);
      const parentLast = lastPathSegment(parentRel);

      for (const child of kids) {
        // If already set by another path, keep it.
        if (relBySlug[child]) continue;
        const segment = child.startsWith(slug + "-") ? child.slice(slug.length + 1) : null;
        if (!segment) continue;
        const match =
          subs.find((s) => lastPathSegment(s?.RelativeUrl) === segment) ||
          subs.find((s) => String(s?.RelativeUrl || "").endsWith("/" + segment)) ||
          subs.find((s) => String(s?.RelativeUrl || "").includes("/" + segment)) ||
          // Some Arabam pages encode child in the parent segment, e.g. ".../kamyon-kamyonet-citroen"
          subs.find((s) => lastPathSegment(s?.RelativeUrl) === `${parentLast}-${segment}`) ||
          subs.find((s) => lastPathSegment(s?.RelativeUrl).endsWith(`-${segment}`));
        const rel = typeof match?.RelativeUrl === "string" ? match.RelativeUrl.trim().replace(/^\/+/, "") : "";
        if (rel) relBySlug[child] = rel;
      }
    }
  }

  // Build schema blocks by grouping categories with identical field definitions.
  const blocksByKey = new Map();
  for (const slug of slugs) {
    const facetMap = slugToFacetMap[slug] || {};
    const includeModels = Object.prototype.hasOwnProperty.call(modelsDict, slug) && Array.isArray(modelsDict[slug]) && modelsDict[slug].length > 0;
    const fields = buildFieldsFromFacets(facetMap, { includeModels });
    const key = JSON.stringify(fields);
    if (!blocksByKey.has(key)) blocksByKey.set(key, { fields, category_slugs: [] });
    blocksByKey.get(key).category_slugs.push(slug);
  }

  const schemaBlocks = Array.from(blocksByKey.values())
    .map((b) => ({ schema_version: 1, category_slugs: b.category_slugs, fields: b.fields }))
    .sort((a, b) => String(a.category_slugs?.[0] || "").localeCompare(String(b.category_slugs?.[0] || ""), "tr"));

  const outModels = {
    source: "arabam.com GetFacets (ticari-arac brand leaf pages SelectedCategory.SubCategories)",
    generated_at: new Date().toISOString(),
    stats: {
      categories_seen: slugs.length,
      categories_with_models: Object.keys(modelsDict).length,
      models_total: Object.values(modelsDict).reduce((a, v) => a + (Array.isArray(v) ? v.length : 0), 0),
    },
    // Kept compatible with existing import rule type: vehicle_models_by_brand_slug
    // (the key name is historical; values are keyed by our leaf category slug)
    brand_slug_to_models: modelsDict,
  };

  console.log(`\nschemaBlocks=${schemaBlocks.length} targets=${slugs.length}`);
  console.log(`models categories=${outModels.stats.categories_with_models} models_total=${outModels.stats.models_total}`);

  if (!args.write) {
    console.log("\nDry-run: use --write to write manifests.");
    return;
  }

  const modelsPath = path.join(manifestsRoot, "vehicle-ticari-arac-models.arabam.tr.json");
  fs.writeFileSync(modelsPath, JSON.stringify(outModels, null, 2) + "\n", "utf8");
  console.log("wrote " + modelsPath);

  const schemaPath = path.join(manifestsRoot, "schema", "vehicle-ticari-arac.json");
  fs.writeFileSync(schemaPath, JSON.stringify(schemaBlocks, null, 2) + "\n", "utf8");
  console.log("wrote " + schemaPath);
}

main().catch((e) => {
  console.error("ERROR: " + (e?.message || String(e)));
  process.exit(1);
});

