/* eslint-disable no-console */
/**
 * Export Tractor (traktor) brand options from arabam.com and write rules_ref file.
 *
 * Writes:
 * - catalog/manifests/rules/vehicle/by_category/traktor/vehicle_brand.tr.json
 *
 * Usage:
 *   node scripts/arabam-export-traktor-brand-rules.js --write
 */

const fs = require("fs");
const path = require("path");

const FACETS_ENDPOINT = "https://www.arabam.com/listing/GetFacets?url=";
const PAGE_REL = "ikinci-el/traktor";

function parseArgs(argv) {
  return { write: argv.includes("--write") };
}

async function fetchFacets(rel, timeoutMs = 25000) {
  const pageUrl = "https://www.arabam.com/" + String(rel || "").replace(/^\/+/, "");
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

async function main() {
  const args = parseArgs(process.argv);
  const repoRoot = path.resolve(__dirname, "..");
  const manifestsRoot = path.join(repoRoot, "catalog", "manifests");

  const o = await fetchFacets(PAGE_REL);
  const brands = sortTr(
    uniq(
      subcategories(o)
        .map((x) => (typeof x?.Name === "string" ? x.Name.trim() : ""))
        .filter(Boolean)
    )
  );

  console.log("traktor_brands=" + brands.length);
  console.log(brands.slice(0, 30).join(" | "));

  if (!args.write) {
    console.log("\nDry-run: use --write to write rules manifest.");
    return;
  }

  const outDir = path.join(manifestsRoot, "rules", "vehicle", "by_category", "traktor");
  fs.mkdirSync(outDir, { recursive: true });
  const outFile = path.join(outDir, "vehicle_brand.tr.json");
  fs.writeFileSync(outFile, JSON.stringify(brands, null, 2) + "\n", "utf8");
  console.log("wrote " + outFile);
}

main().catch((e) => {
  console.error("ERROR: " + (e?.message || String(e)));
  process.exit(1);
});

