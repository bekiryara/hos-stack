/* eslint-disable no-console */
/**
 * Export Tractor (traktor) feature option lists from arabam.com facets
 * and write rules_ref files.
 *
 * Writes:
 * - catalog/manifests/rules/vehicle/by_category/traktor/vehicle_cylinder_count.tr.json
 * - catalog/manifests/rules/vehicle/by_category/traktor/vehicle_tractor_type.tr.json
 * - catalog/manifests/rules/vehicle/by_category/traktor/vehicle_tractor_cabin.tr.json
 *
 * Usage:
 *   node scripts/arabam-export-traktor-feature-rules.js --write
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

function uniqPreserve(list) {
  const seen = new Set();
  const out = [];
  for (const x of list) {
    if (!x || seen.has(x)) continue;
    seen.add(x);
    out.push(x);
  }
  return out;
}

function facetOptionsByName(getFacetsData, facetName) {
  const facets = getFacetsData?.Data?.Facets || [];
  const f = Array.isArray(facets) ? facets.find((x) => x && x.Name === facetName) : null;
  const items = f && Array.isArray(f.Items) ? f.Items : [];
  return uniqPreserve(items.map((x) => (typeof x?.Name === "string" ? x.Name.trim() : "")).filter(Boolean));
}

function writeRule(manifestsRoot, fileName, options) {
  const outDir = path.join(manifestsRoot, "rules", "vehicle", "by_category", "traktor");
  fs.mkdirSync(outDir, { recursive: true });
  const outFile = path.join(outDir, fileName);
  fs.writeFileSync(outFile, JSON.stringify(options, null, 2) + "\n", "utf8");
  return outFile;
}

async function main() {
  const args = parseArgs(process.argv);
  const repoRoot = path.resolve(__dirname, "..");
  const manifestsRoot = path.join(repoRoot, "catalog", "manifests");

  const data = await fetchFacets(PAGE_REL);

  const cylinder = facetOptionsByName(data, "Silindir Sayısı");
  const tractorType = facetOptionsByName(data, "Traktör Tipi");
  const cabin = facetOptionsByName(data, "Kabin");

  console.log("traktor facet options");
  console.log("- Silindir Sayısı:", cylinder.length, cylinder.join(" | "));
  console.log("- Traktör Tipi:", tractorType.length, tractorType.join(" | "));
  console.log("- Kabin:", cabin.length, cabin.join(" | "));

  if (!args.write) {
    console.log("\nDry-run: use --write to write rules manifests.");
    return;
  }

  const wrote = [];
  wrote.push(writeRule(manifestsRoot, "vehicle_cylinder_count.tr.json", cylinder));
  wrote.push(writeRule(manifestsRoot, "vehicle_tractor_type.tr.json", tractorType));
  wrote.push(writeRule(manifestsRoot, "vehicle_tractor_cabin.tr.json", cabin));
  wrote.forEach((p) => console.log("wrote " + p));
}

main().catch((e) => {
  console.error("ERROR: " + (e?.message || String(e)));
  process.exit(1);
});

