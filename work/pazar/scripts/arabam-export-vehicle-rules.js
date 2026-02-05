/* eslint-disable no-console */
/**
 * Arabam GetFacets -> manifest rules exporter
 *
 * Goal: keep `schema/vehicle.json` small (rules_ref), while option lists live in
 * `catalog/manifests/rules/vehicle/*.json`.
 *
 * Usage (dry-run, prints report only):
 *   node scripts/arabam-export-vehicle-rules.js
 *
 * Write/update manifest rule files:
 *   node scripts/arabam-export-vehicle-rules.js --write
 *
 * Use a different seed category page (used to discover top-level RelativeUrl list):
 *   node scripts/arabam-export-vehicle-rules.js --seed "https://www.arabam.com/ikinci-el/otomobil"
 *
 * Export category-specific rules (writes under rules/vehicle/by_category/<slug>/):
 *   node scripts/arabam-export-vehicle-rules.js --by-category --category "ikinci-el/ticari-arac" --category "ikinci-el/arazi-suv-pick-up" --write
 */

const fs = require("fs");
const path = require("path");

const DEFAULT_SEED_PAGE = "https://www.arabam.com/ikinci-el/arazi-suv-pick-up";
const FACETS_ENDPOINT = "https://www.arabam.com/listing/GetFacets?url=";

// Map Arabam facet display name -> manifest rules file
// (Keep this small + explicit for control.)
const FACET_TO_RULEFILE = {
  "Yakıt Tipi": "vehicle_fuel_type.tr.json",
  "Vites Tipi": "vehicle_transmission.tr.json",
  "Kasa Tipi": "vehicle_body_type.tr.json",
  Renk: "vehicle_color.tr.json",
  "Araç Durumu": "vehicle_condition.tr.json",
  Çekiş: "vehicle_drive_type.tr.json",
  "İlan Sahibi": "vehicle_seller_type.tr.json",
  "Boya, Değişen Parça": "vehicle_damage_status.tr.json",
  "İlan Tarihi": "vehicle_listing_age.tr.json",
};

function parseArgs(argv) {
  const out = { write: false, seed: DEFAULT_SEED_PAGE, byCategory: false, categories: [] };
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--write") out.write = true;
    else if (a === "--seed") out.seed = argv[++i] || DEFAULT_SEED_PAGE;
    else if (a === "--by-category") out.byCategory = true;
    else if (a === "--category") out.categories.push(argv[++i] || "");
  }
  return out;
}

async function fetchJson(url, timeoutMs = 25000) {
  const ac = new AbortController();
  const t = setTimeout(() => ac.abort(), timeoutMs);
  try {
    const res = await fetch(url, {
      method: "GET",
      headers: {
        accept: "application/json,text/plain,*/*",
        "user-agent": "Mozilla/5.0 (compatible; catalog-import-bot/1.0)",
      },
      signal: ac.signal,
    });
    if (!res.ok) throw new Error(`HTTP ${res.status} for ${url}`);
    return await res.json();
  } finally {
    clearTimeout(t);
  }
}

function getSeedRelativeUrls(getFacetsData) {
  const d = getFacetsData?.Data || getFacetsData?.data || {};
  const list = d?.BreadCrumbSubCategories?.[0]?.Value || [];
  const rels = [];
  for (const it of list) {
    const rel = typeof it?.RelativeUrl === "string" ? it.RelativeUrl : "";
    if (!rel) continue;
    // Normalize: ensure no leading slash
    rels.push(rel.replace(/^\/+/, ""));
  }
  // De-dup preserve order
  const seen = new Set();
  const out = [];
  for (const r of rels) {
    if (seen.has(r)) continue;
    seen.add(r);
    out.push(r);
  }
  return out;
}

function extractFacetOptions(getFacetsData) {
  const d = getFacetsData?.Data || getFacetsData?.data || {};
  const facets = Array.isArray(d?.Facets) ? d.Facets : [];
  const out = new Map(); // facetName -> list<string>
  for (const f of facets) {
    const name = typeof f?.Name === "string" ? f.Name : "";
    if (!name) continue;
    const items = Array.isArray(f?.Items) ? f.Items : [];
    const options = items
      .map((x) => (typeof x?.Name === "string" ? x.Name.trim() : ""))
      .filter((x) => x.length > 0);
    out.set(name, options);
  }
  return out;
}

function writeRuleFile(manifestsRoot, ruleFileName, options, subdir = "") {
  const dir = path.join(manifestsRoot, "rules", "vehicle", subdir);
  fs.mkdirSync(dir, { recursive: true });
  const full = path.join(dir, ruleFileName);
  fs.writeFileSync(full, JSON.stringify(options, null, 2) + "\n", "utf8");
  return full;
}

function categorySlugFromRelativeUrl(rel) {
  const r = String(rel || "").replace(/^https?:\/\/[^/]+\//, "").replace(/^\/+/, "");
  // expected: ikinci-el/<slug> or ikinci-el/<slug>/...
  const m = r.match(/^ikinci-el\/([^/?#]+)/);
  return m ? m[1] : "";
}

async function main() {
  const args = parseArgs(process.argv);
  const manifestsRoot = path.resolve(__dirname, "..", "catalog", "manifests");

  console.log("seed_page=" + args.seed);
  const seedUrl = FACETS_ENDPOINT + encodeURIComponent(args.seed);
  const seed = await fetchJson(seedUrl);
  const rels = getSeedRelativeUrls(seed);
  console.log("discovered_relative_urls=" + rels.length);
  if (rels.length) console.log(rels.join("\n"));

  // Prefer otomobil as canonical source when available.
  const prefer = "ikinci-el/otomobil";
  const ordered = rels.includes(prefer) ? [prefer, ...rels.filter((x) => x !== prefer)] : rels;

  if (args.byCategory) {
    const cats = args.categories.filter(Boolean);
    if (cats.length === 0) {
      console.log("\n--by-category requires at least one --category <ikinci-el/...>.");
      process.exit(2);
    }

    for (const rel of cats) {
      const slug = categorySlugFromRelativeUrl(rel);
      if (!slug) {
        console.log("SKIP (cannot parse slug): " + rel);
        continue;
      }
      const pageUrl = rel.startsWith("http") ? rel : "https://www.arabam.com/" + rel.replace(/^\/+/, "");
      const data = await fetchJson(FACETS_ENDPOINT + encodeURIComponent(pageUrl));
      const facets = extractFacetOptions(data);

      console.log("\nCategory: " + rel + " (slug=" + slug + ") facets=" + facets.size);
      for (const facetName of Object.keys(FACET_TO_RULEFILE)) {
        const opts = facets.get(facetName);
        if (!opts || opts.length === 0) {
          console.log("- MISSING facet=" + facetName);
          continue;
        }
        const fileName = FACET_TO_RULEFILE[facetName];
        console.log("- facet=" + facetName + " options=" + opts.length + " -> " + fileName);
        if (args.write) {
          const full = writeRuleFile(manifestsRoot, fileName, opts, path.join("by_category", slug));
          console.log("  wrote " + full);
        }
      }
    }

    if (!args.write) {
      console.log("\nDry-run: no files written. Use --write to update manifests.");
    }
    return;
  }

  const collected = new Map(); // facetName -> {options, source}
  const perCat = [];
  for (const rel of ordered) {
    const pageUrl = rel.startsWith("http") ? rel : "https://www.arabam.com/" + rel;
    const data = await fetchJson(FACETS_ENDPOINT + encodeURIComponent(pageUrl));
    const facets = extractFacetOptions(data);
    perCat.push({ rel, facetCount: facets.size });

    for (const facetName of Object.keys(FACET_TO_RULEFILE)) {
      const opts = facets.get(facetName);
      if (!opts || opts.length === 0) continue;
      if (!collected.has(facetName)) {
        collected.set(facetName, { options: opts, source: rel });
      }
    }
  }

  console.log("\nFacet coverage report:");
  for (const r of perCat) {
    console.log("- " + r.rel + " facets=" + r.facetCount);
  }

  console.log("\nSelected facets to export:");
  for (const facetName of Object.keys(FACET_TO_RULEFILE)) {
    const found = collected.get(facetName);
    if (!found) {
      console.log("- MISSING facet=" + facetName);
      continue;
    }
    console.log(
      "- facet=" + facetName + " options=" + found.options.length + " source=" + found.source + " -> " + FACET_TO_RULEFILE[facetName]
    );
  }

  if (!args.write) {
    console.log("\nDry-run: no files written. Use --write to update manifests.");
    return;
  }

  for (const facetName of Object.keys(FACET_TO_RULEFILE)) {
    const found = collected.get(facetName);
    if (!found) continue;
    const fileName = FACET_TO_RULEFILE[facetName];
    const full = writeRuleFile(manifestsRoot, fileName, found.options);
    console.log("wrote " + full + " (" + found.options.length + " options)");
  }
}

main().catch((e) => {
  console.error("ERROR: " + (e && e.message ? e.message : String(e)));
  process.exit(1);
});

