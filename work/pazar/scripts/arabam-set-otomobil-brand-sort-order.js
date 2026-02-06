/* eslint-disable no-console */
/**
 * Set otomobil brand category sort_order to match arabam.com brand ordering.
 *
 * Data source:
 * - https://www.arabam.com/listing/GetFacets?url=https://www.arabam.com/ikinci-el/otomobil
 * - Uses SelectedCategory.SubCategories in returned facets.
 *
 * Writes:
 * - catalog/manifests/categories/vehicle-otomobil-brands.json (updates sort_order)
 *
 * Usage:
 *   node scripts/arabam-set-otomobil-brand-sort-order.js           # dry-run
 *   node scripts/arabam-set-otomobil-brand-sort-order.js --write   # write file
 *   node scripts/arabam-set-otomobil-brand-sort-order.js --check-api  # compare API order too (requires backend running)
 *   node scripts/arabam-set-otomobil-brand-sort-order.js --write --check-api
 */

const fs = require("fs");
const path = require("path");

const FACETS_ENDPOINT = "https://www.arabam.com/listing/GetFacets?url=";
const BASE = "https://www.arabam.com/";
const ROOT_REL = "ikinci-el/otomobil";

function parseArgs(argv) {
  return {
    write: argv.includes("--write"),
    checkApi: argv.includes("--check-api"),
  };
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

function subcategories(o) {
  const sub = o?.Data?.Facets?.[0]?.SelectedCategory?.SubCategories || [];
  return Array.isArray(sub) ? sub : [];
}

async function fetchJson(url, timeoutMs = 25000) {
  const ac = new AbortController();
  const t = setTimeout(() => ac.abort(), timeoutMs);
  try {
    const res = await fetch(url, { headers: { accept: "application/json" }, signal: ac.signal });
    if (!res.ok) throw new Error(`HTTP ${res.status} for ${url}`);
    return await res.json();
  } finally {
    clearTimeout(t);
  }
}

async function fetchFacets(rel) {
  const pageUrl = BASE + String(rel || "").replace(/^\/+/, "");
  const req = FACETS_ENDPOINT + encodeURIComponent(pageUrl);
  return await fetchJson(req);
}

function flattenTree(nodes) {
  const out = [];
  const stack = Array.isArray(nodes) ? [...nodes] : [];
  while (stack.length) {
    const n = stack.pop();
    if (!n) continue;
    out.push(n);
    if (Array.isArray(n.children)) {
      for (const ch of n.children) stack.push(ch);
    }
  }
  return out;
}

async function detectBaseUrl() {
  const candidates = ["http://127.0.0.1:8080/api", "http://127.0.0.1:8080"];
  for (const base of candidates) {
    try {
      await fetchJson(`${base}/v1/categories`);
      return base;
    } catch {
      // try next
    }
  }
  throw new Error("Could not reach categories endpoint on 127.0.0.1:8080 (tried /api and direct).");
}

function firstDiffIndex(a, b) {
  const n = Math.min(a.length, b.length);
  for (let i = 0; i < n; i++) {
    if (String(a[i]) !== String(b[i])) return i;
  }
  return a.length === b.length ? -1 : n;
}

function formatOneLineArray(rows) {
  if (!Array.isArray(rows) || rows.length === 0) return "[]\n";
  return "[\n" + rows.map((r) => "  " + JSON.stringify(r)).join(",\n") + "\n]\n";
}

async function main() {
  const args = parseArgs(process.argv);
  const repoRoot = path.resolve(__dirname, "..");
  const manifestsRoot = path.join(repoRoot, "catalog", "manifests");
  const brandsPath = path.join(manifestsRoot, "categories", "vehicle-otomobil-brands.json");

  // 1) Fetch arabam order (brand slugs)
  const root = await fetchFacets(ROOT_REL);
  const brands = subcategories(root)
    .map((x) => ({
      name: typeof x?.Name === "string" ? x.Name.trim() : "",
      rel: typeof x?.RelativeUrl === "string" ? x.RelativeUrl.trim().replace(/^\/+/, "") : "",
      seg: lastPathSegment(typeof x?.RelativeUrl === "string" ? x.RelativeUrl : ""),
    }))
    .filter((b) => b.name && b.rel);

  const arabamSlugsInOrder = brands.map((b) => {
    const seg = b.seg || b.name;
    const brandSlug = slugifyKey(seg);
    return `otomobil-${brandSlug}`;
  });

  // 2) Read our manifest and update sort_order
  const rows = JSON.parse(fs.readFileSync(brandsPath, "utf8"));
  if (!Array.isArray(rows)) throw new Error("vehicle-otomobil-brands.json must be an array.");

  const bySlug = new Map();
  for (const r of rows) {
    const s = r && r.slug ? String(r.slug) : "";
    if (s) bySlug.set(s, r);
  }

  const missingInManifest = arabamSlugsInOrder.filter((s) => !bySlug.has(s));
  if (missingInManifest.length) {
    console.log("WARN: arabam slugs missing in manifest: " + JSON.stringify(missingInManifest));
  }

  let changed = 0;
  const desiredSort = new Map(); // slug -> sort_order
  arabamSlugsInOrder.forEach((slug, idx) => desiredSort.set(slug, (idx + 1) * 10));

  for (const r of rows) {
    const slug = r && r.slug ? String(r.slug) : "";
    if (!slug) continue;
    if (r.parent_slug !== "otomobil") continue;
    if (r.status !== "active") continue; // inactive categories do not affect API ordering
    if (!desiredSort.has(slug)) continue; // not present in arabam list
    const newSort = desiredSort.get(slug);
    if (r.sort_order !== newSort) {
      r.sort_order = newSort;
      changed++;
    }
  }

  console.log("arabam_brands_total=" + arabamSlugsInOrder.length);
  console.log("manifest_rows_total=" + rows.length);
  console.log("changed_sort_orders=" + changed);

  if (args.write) {
    fs.writeFileSync(brandsPath, formatOneLineArray(rows), "utf8");
    console.log("wrote " + brandsPath);
  } else {
    console.log("Dry-run: use --write to write manifest.");
  }

  // 3) Optional: check API order equals arabam order (intersection, active only)
  if (args.checkApi) {
    const base = await detectBaseUrl();
    const tree = await fetchJson(`${base}/v1/categories`);
    const flat = flattenTree(tree);
    const otomobil = flat.find((x) => x && String(x.slug) === "otomobil");
    if (!otomobil || !Array.isArray(otomobil.children)) throw new Error("Could not find otomobil children in API tree.");
    const apiOrder = otomobil.children.map((x) => String(x.slug));

    const apiSet = new Set(apiOrder);
    const arabamIntersection = arabamSlugsInOrder.filter((s) => apiSet.has(s));
    const apiIntersection = apiOrder.filter((s) => desiredSort.has(s));

    const idx = firstDiffIndex(arabamIntersection, apiIntersection);
    if (idx === -1 && arabamIntersection.length === apiIntersection.length) {
      console.log("API_ORDER_OK: matches arabam order (" + arabamIntersection.length + ")");
    } else {
      console.log("API_ORDER_MISMATCH: first_diff_index=" + idx);
      console.log("arabam_first_10=" + JSON.stringify(arabamIntersection.slice(0, 10)));
      console.log("api_first_10=" + JSON.stringify(apiIntersection.slice(0, 10)));
    }
  }
}

main().catch((e) => {
  console.error("ERROR: " + (e?.message || String(e)));
  process.exit(1);
});

