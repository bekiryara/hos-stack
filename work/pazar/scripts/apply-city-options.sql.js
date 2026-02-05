const fs = require("fs");
const path = require("path");

/**
 * Emits SQL to STDOUT that updates `city` filter options in Postgres.
 *
 * Usage:
 *   node scripts/apply-city-options.sql.js | psql ...
 */
const manifestPath = path.resolve(__dirname, "..", "catalog", "manifests", "cities.tr.json");
const raw = fs.readFileSync(manifestPath, "utf8");
const options = JSON.parse(raw);

if (!Array.isArray(options) || options.length === 0) {
  throw new Error(`Invalid or empty city list at ${manifestPath}`);
}

const rules = JSON.stringify({ options });

// Windows shells/pipelines may transcode stdout in a way that corrupts non-ASCII chars.
// Emit ASCII-only JSON using \uXXXX escapes; Postgres will decode it when casting to json.
const rulesAscii = rules.replace(/[\u0080-\uFFFF]/g, (ch) => {
  const code = ch.charCodeAt(0).toString(16).padStart(4, "0");
  return "\\u" + code;
});

process.stdout.write("BEGIN;\n");
process.stdout.write(
  "UPDATE category_filter_schema " +
    "SET ui_component='select', rules_json=$json$" +
    rulesAscii +
    "$json$::json " +
    "WHERE attribute_key='city';\n"
);
process.stdout.write("COMMIT;\n");

