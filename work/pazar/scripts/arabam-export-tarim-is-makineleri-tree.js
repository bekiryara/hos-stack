/* eslint-disable no-console */
/**
 * Export arabam.com "Tarım & İş Makineleri" category tree as nested categories.
 *
 * Arabam structure (observed):
 * - /ikinci-el/tarim-is-makineleri
 *   -> SelectedCategory.SubCategories (3): is-makineleri, sanayi, tarim-makineleri
 * - Each node may have further SelectedCategory.SubCategories.
 * - Brand pages generally DO NOT expose model lists; there is no "Model" facet either.
 *   So we build the category tree and keep vehicle_model as free text in schema.
 *
 * Writes:
 * - catalog/manifests/categories/vehicle-tarim-is-makineleri-tree.json
 * - catalog/manifests/schema/vehicle-tarim-is-makineleri-leaves.json
 *
 * Usage:
 *   node scripts/arabam-export-tarim-is-makineleri-tree.js          # dry-run
 *   node scripts/arabam-export-tarim-is-makineleri-tree.js --write # write manifests
 */
const fs = require("fs");
const path = require("path");

const FACETS_ENDPOINT = "https://www.arabam.com/listing/GetFacets?url=";
const BASE = "https://www.arabam.com/";
const ROOT_REL = "ikinci-el/tarim-is-makineleri";
const ROOT_SLUG = "tarim-is-makineleri";

function parseArgs(argv) {
  return { write: argv.includes("--write"), concurrency: 6 };
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

function lastPathSegment(rel) {
  const parts = String(rel || "").split("?")[0].split("#")[0].split("/").filter(Boolean);
  return parts[parts.length - 1] || "";
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

async function mapLimit(items, limit, fn) {
  const results = new Array(items.length);
  let nextIndex = 0;
  let running = 0;

  return await new Promise((resolve, reject) => {
    const launch = () => {
      while (running < limit && nextIndex < items.length) {
        const idx = nextIndex++;
        running++;
        Promise.resolve(fn(items[idx], idx))
          .then((res) => {
            results[idx] = res;
            running--;
            if (nextIndex >= items.length && running === 0) resolve(results);
            else launch();
          })
          .catch(reject);
      }
    };
    launch();
  });
}

function facetOptionsByFriendly(data) {
  const facets = (data && data.Data && Array.isArray(data.Data.Facets) ? data.Data.Facets : []) || [];
  const out = {};
  for (const f of facets) {
    const friendly = typeof f?.FriendlyUrlName === "string" ? f.FriendlyUrlName : "";
    const items = Array.isArray(f?.Items) ? f.Items : [];
    if (!friendly || items.length === 0) continue;
    const opts = items.map((i) => (typeof i?.Name === "string" ? i.Name.trim() : "")).filter(Boolean);
    // Keep options only for small select-like facets. Large lists (like cities) are referenced via rules_ref.
    out[friendly] = opts;
  }
  return out;
}

function buildFieldsFromFacets(facetMap) {
  const fields = [];
  const has = (friendly) => Object.prototype.hasOwnProperty.call(facetMap, friendly) && Array.isArray(facetMap[friendly]) && facetMap[friendly].length > 0;

  // Arabam facet -> our attribute mapping (birebir options per page where applicable)
  if (has("il")) {
    fields.push({
      attribute_key: "city",
      ui_component: "select",
      required: false,
      filter_mode: "exact",
      rules: null,
      rules_ref: "cities.tr.json",
      sort_order: 5,
      applies_to_transaction_modes: null,
    });
  }

  if (has("yil")) {
    fields.push({
      attribute_key: "vehicle_year",
      ui_component: "number",
      required: false,
      filter_mode: "range",
      rules: { min: 1950, max: 2035 },
      sort_order: 30,
      applies_to_transaction_modes: null,
    });
  }

  if (has("arac-durumu")) {
    fields.push({
      attribute_key: "vehicle_condition",
      ui_component: "select",
      required: false,
      filter_mode: "exact",
      rules: { options: facetMap["arac-durumu"] },
      sort_order: 58,
      applies_to_transaction_modes: null,
    });
  }

  if (has("sasi-tipi")) {
    fields.push({
      attribute_key: "vehicle_chassis_type",
      ui_component: "select",
      required: false,
      filter_mode: "exact",
      rules: { options: facetMap["sasi-tipi"] },
      sort_order: 59,
      applies_to_transaction_modes: null,
    });
  }

  if (has("ilan-sahibi")) {
    fields.push({
      attribute_key: "vehicle_seller_type",
      ui_component: "select",
      required: false,
      filter_mode: "exact",
      rules: { options: facetMap["ilan-sahibi"] },
      sort_order: 60,
      applies_to_transaction_modes: null,
    });
  }

  if (has("ilan-tarihi")) {
    fields.push({
      attribute_key: "vehicle_listing_age",
      ui_component: "select",
      required: false,
      filter_mode: "exact",
      rules: { options: facetMap["ilan-tarihi"] },
      sort_order: 66,
      applies_to_transaction_modes: null,
    });
  }

  if (has("ozel-ilanlar")) {
    fields.push({
      attribute_key: "vehicle_special_listing",
      ui_component: "select",
      required: false,
      filter_mode: "exact",
      rules: { options: facetMap["ozel-ilanlar"] },
      sort_order: 67,
      applies_to_transaction_modes: null,
    });
  }

  if (has("fiyat")) {
    fields.push({
      attribute_key: "vehicle_price",
      ui_component: "number",
      required: false,
      filter_mode: "range",
      rules: { min: 0, max: 1000000000 },
      sort_order: 70,
      applies_to_transaction_modes: ["sale"],
    });
  }

  return fields;
}

async function main() {
  const args = parseArgs(process.argv);
  const repoRoot = path.resolve(__dirname, "..");
  const manifestsRoot = path.join(repoRoot, "catalog", "manifests");

  const categoriesOutPath = path.join(manifestsRoot, "categories", "vehicle-tarim-is-makineleri-tree.json");
  const schemaOutPath = path.join(manifestsRoot, "schema", "vehicle-tarim-is-makineleri-leaves.json");

  // Keep Node alive while async work is in progress (some environments may exit with only pending promises).
  const keepAlive = setInterval(() => {}, 1000);

  const visited = new Set();
  const categories = [];
  const parentToChildren = new Map(); // parent_slug -> Set(child_slug)
  const leafSlugs = [];
  const seenSlugs = new Set();
  const slugToFacetMap = {}; // slug -> facetMap (friendly -> options)

  function addChild(parentSlug, childSlug) {
    if (!parentToChildren.has(parentSlug)) parentToChildren.set(parentSlug, new Set());
    parentToChildren.get(parentSlug).add(childSlug);
  }

  /**
   * Iterative traversal with a global concurrency pool.
   */
  const queue = [{ parent_slug: null, slug: ROOT_SLUG, rel: ROOT_REL }];
  let processed = 0;
  let fetched = 0;

  while (queue.length > 0) {
    const batch = queue.splice(0, 50);
    await mapLimit(batch, args.concurrency, async (task) => {
      if (!task || !task.rel || !task.slug) return;
      if (visited.has(task.rel)) return;
      visited.add(task.rel);

      const data = await fetchFacets(task.rel);
      fetched++;
      slugToFacetMap[task.slug] = facetOptionsByFriendly(data);
      const kids = subcategories(data)
        .map((x) => ({
          name: typeof x?.Name === "string" ? x.Name.trim() : "",
          rel: typeof x?.RelativeUrl === "string" ? x.RelativeUrl.trim().replace(/^\/+/, "") : "",
        }))
        .filter((c) => c.name && c.rel);

      kids.forEach((c, idx) => {
        const seg = lastPathSegment(c.rel);
        const segSlug = slugifyKey(seg || c.name);
        const childSlug = `${task.slug}-${segSlug}`;

        addChild(task.slug, childSlug);
        if (!seenSlugs.has(childSlug)) {
          seenSlugs.add(childSlug);
          categories.push({
            slug: childSlug,
            parent_slug: task.slug,
            title: c.name,
            status: "active",
            sort_order: (idx + 1) * 10,
          });
        }
        queue.push({ parent_slug: task.slug, slug: childSlug, rel: c.rel });
      });

      processed++;
      if (processed % 50 === 0) {
        console.log(`progress: processed=${processed} fetched=${fetched} queue=${queue.length} categories=${categories.length}`);
      }
    });
  }

  // Leaves are nodes that have no children (excluding the root itself).
  const hasChildren = new Set();
  for (const [p, set] of parentToChildren.entries()) {
    if (set && set.size) hasChildren.add(p);
  }
  for (const row of categories) {
    if (!hasChildren.has(row.slug)) {
      leafSlugs.push(row.slug);
    }
  }

  // Deterministic output ordering (for diffs) while preserving per-parent sort_order.
  // We sort primarily by parent_slug then sort_order, secondarily by slug.
  categories.sort((a, b) => {
    const p = String(a.parent_slug).localeCompare(String(b.parent_slug), "tr");
    if (p !== 0) return p;
    const so = (a.sort_order || 0) - (b.sort_order || 0);
    if (so !== 0) return so;
    return String(a.slug).localeCompare(String(b.slug), "tr");
  });

  // leafSlugs order is not user-facing but keep stable
  leafSlugs.sort((a, b) => String(a).localeCompare(String(b), "tr"));

  // Build birebir schema blocks by grouping categories with identical field definitions.
  // NOTE: We attach schema not only to leaves, but also to intermediate nodes, because Arabam shows facets there too.
  const schemaTargets = [ROOT_SLUG, ...categories.map((c) => String(c.slug))];
  const schemaTargetsUniq = Array.from(new Set(schemaTargets));
  const blocksByKey = new Map(); // key -> { fields, category_slugs }
  for (const slug of schemaTargetsUniq) {
    const facetMap = slugToFacetMap[slug] || {};
    const fields = buildFieldsFromFacets(facetMap);
    const key = JSON.stringify(fields);
    if (!blocksByKey.has(key)) {
      blocksByKey.set(key, { fields, category_slugs: [] });
    }
    blocksByKey.get(key).category_slugs.push(slug);
  }

  const schemaBlocks = Array.from(blocksByKey.values())
    .map((b) => ({
      schema_version: 1,
      category_slugs: b.category_slugs,
      fields: b.fields,
    }))
    .sort((a, b) => {
      // deterministic: by first slug
      const as = String(a.category_slugs?.[0] || "");
      const bs = String(b.category_slugs?.[0] || "");
      return as.localeCompare(bs, "tr");
    });

  console.log("categories_total=" + categories.length);
  console.log("leaf_categories_total=" + leafSlugs.length);
  console.log("schema_targets_total=" + schemaTargetsUniq.length);
  console.log("schema_blocks_total=" + schemaBlocks.length);

  if (!args.write) {
    console.log("\nDry-run: use --write to write manifests.");
    clearInterval(keepAlive);
    return;
  }

  console.log("writing_manifests...");
  fs.writeFileSync(categoriesOutPath, JSON.stringify(categories, null, 2) + "\n", "utf8");
  fs.writeFileSync(schemaOutPath, JSON.stringify(schemaBlocks, null, 2) + "\n", "utf8");
  console.log("writing_manifests_done");
  console.log("wrote " + categoriesOutPath);
  console.log("wrote " + schemaOutPath);
  clearInterval(keepAlive);
}

main().catch((e) => {
  console.error("ERROR: " + (e?.message || String(e)));
  process.exit(1);
});

