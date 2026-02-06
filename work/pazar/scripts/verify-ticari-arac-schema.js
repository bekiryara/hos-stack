/* eslint-disable no-console */
/**
 * Verify ticari-arac schema options are birebir with arabam.com facets for a few sample nodes.
 *
 * Usage:
 *   node work/pazar/scripts/verify-ticari-arac-schema.js
 */

const PAZAR_BASE = process.env.PAZAR_BASE || "http://localhost:8080";
const ARABAM_BASE = "https://www.arabam.com/";
const FACETS_ENDPOINT = "https://www.arabam.com/listing/GetFacets?url=";

async function fetchJson(url) {
  const res = await fetch(url, { headers: { accept: "application/json" } });
  if (!res.ok) throw new Error(`HTTP ${res.status} for ${url}`);
  return await res.json();
}

async function fetchArabamFacets(rel) {
  const pageUrl = ARABAM_BASE + String(rel || "").replace(/^\/+/, "");
  const url = FACETS_ENDPOINT + encodeURIComponent(pageUrl);
  return await fetchJson(url);
}

function flattenCategories(tree) {
  const out = [];
  const stack = Array.isArray(tree) ? [...tree] : [];
  while (stack.length) {
    const n = stack.pop();
    if (!n) continue;
    out.push(n);
    const kids = n.children || n.child_categories || n.items || [];
    if (Array.isArray(kids)) for (const k of kids) stack.push(k);
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

function selectedSubCategoryNames(data) {
  const subs = data?.Data?.Facets?.[0]?.SelectedCategory?.SubCategories || [];
  if (!Array.isArray(subs) || subs.length === 0) return [];
  const isModelList = subs.every((s) => s?.IsBrand === false);
  if (!isModelList) return [];
  return subs.map((s) => (typeof s?.Name === "string" ? s.Name.trim() : "")).filter(Boolean);
}

function optionsFromPazarSchema(schema) {
  const rows = Array.isArray(schema) ? schema : Array.isArray(schema?.filters) ? schema.filters : [];
  const out = {};
  for (const f of rows) {
    const key = f.attribute_key || f.key;
    const opts = f?.rules?.options;
    if (!key) continue;
    if (Array.isArray(opts)) out[key] = opts.map(String);
  }
  return out;
}

function equalArray(a, b) {
  if (!Array.isArray(a) || !Array.isArray(b)) return false;
  if (a.length !== b.length) return false;
  for (let i = 0; i < a.length; i++) if (String(a[i]) !== String(b[i])) return false;
  return true;
}

async function main() {
  const categoriesTree = await fetchJson(`${PAZAR_BASE}/api/v1/categories`);
  const flat = flattenCategories(categoriesTree);
  const bySlug = new Map(flat.map((c) => [c.slug, c]));
  const childCountById = new Map();
  for (const c of flat) {
    if (c && c.parent_id != null) childCountById.set(c.parent_id, (childCountById.get(c.parent_id) || 0) + 1);
  }

  const samples = [
    { slug: "ticari-arac", arabam_rel: "ikinci-el/ticari-arac" },
    { slug: "ticari-arac-minibus-midibus", arabam_rel: "ikinci-el/ticari-arac/minibus-midibus" },
    { slug: "ticari-arac-minibus-midibus-ford-otosan", arabam_rel: "ikinci-el/ticari-arac/minibus-midibus/ford-otosan" },
  ];

  const attrToFriendly = {
    city: "il",
    vehicle_brand: "arac-markasi",
    vehicle_seat_count: "koltuk-sayisi",
    vehicle_upper_body: "ust-yapi",
    vehicle_chassis_type: "sasi",
    vehicle_km_bucket: "kilometre",
    vehicle_fuel_type: "yakit-tipi",
    vehicle_transmission: "vites-tipi",
    vehicle_color: "renk",
    vehicle_engine_power_bucket: "motor-gucu",
    vehicle_equipment: "donanim",
    vehicle_with_vehicle: "aracla-birlikte",
    vehicle_station_bound: "duraga-bagli",
    vehicle_plate_status: "plaka",
    vehicle_share_status: "hisseli",
    vehicle_condition: "arac-durumu",
    vehicle_damage_status: "boya-degisen-parca",
    vehicle_heavy_damage_record_status: "agir-hasar-kayitli",
    vehicle_swap_status: "takasa-uygun",
    vehicle_seller_type: "ilan-sahibi",
    vehicle_listing_age: "ilan-tarihi",
    vehicle_special_listing: "ozel-ilanlar",
  };

  let totalMismatches = 0;

  for (const s of samples) {
    const cat = bySlug.get(s.slug);
    if (!cat) throw new Error(`Category slug not found in API tree: ${s.slug}`);

    const schema = await fetchJson(`${PAZAR_BASE}/api/v1/categories/${cat.id}/filter-schema`);
    const pazarOpts = optionsFromPazarSchema(schema);

    const arabam = await fetchArabamFacets(s.arabam_rel);
    const facetMap = facetOptionsByFriendly(arabam);
    const models = selectedSubCategoryNames(arabam);

    const mismatches = [];

    for (const [attr, friendly] of Object.entries(attrToFriendly)) {
      const expected = facetMap[friendly] || [];
      const actual = pazarOpts[attr] || [];
      if (expected.length === 0 && actual.length === 0) continue;
      if (!equalArray(actual, expected)) {
        mismatches.push({ attr, friendly, expected_len: expected.length, actual_len: actual.length });
      }
    }

    const isLeaf = (childCountById.get(cat.id) || 0) === 0;
    if (isLeaf && models.length) {
      const actualModels = pazarOpts.vehicle_model || [];
      if (!equalArray(actualModels, models)) {
        mismatches.push({ attr: "vehicle_model", friendly: "(SelectedCategory.SubCategories models)", expected_len: models.length, actual_len: actualModels.length });
      }
    }

    if (mismatches.length) {
      totalMismatches += mismatches.length;
      console.log(`\n[FAIL] ${s.slug} (id=${cat.id}) mismatches=${mismatches.length}`);
      for (const m of mismatches) console.log(` - ${m.attr} <= ${m.friendly}: expected=${m.expected_len} actual=${m.actual_len}`);
    } else {
      console.log(`[OK] ${s.slug} (id=${cat.id})`);
    }
  }

  if (totalMismatches > 0) {
    console.error(`\nTOTAL_MISMATCHES=${totalMismatches}`);
    process.exit(1);
  }
  console.log("\nALL_OK mismatch=0");
}

main().catch((e) => {
  console.error("ERROR: " + (e?.message || String(e)));
  process.exit(1);
});

