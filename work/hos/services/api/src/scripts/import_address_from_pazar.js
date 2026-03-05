import pgPkg from "pg";
const { Pool } = pgPkg;
import { readEnvOrFile } from "../config.js";

function normalizeTr(raw) {
  let s = String(raw ?? "").trim();
  if (!s) return "";
  s = s.replaceAll("i̇", "i").replaceAll("İ", "i");
  s = s.toLowerCase();
  s = s.replaceAll("i̇", "i").replaceAll("İ", "i");
  s = s
    .replaceAll("ı", "i")
    .replaceAll("ş", "s")
    .replaceAll("ğ", "g")
    .replaceAll("ü", "u")
    .replaceAll("ö", "o")
    .replaceAll("ç", "c");
  return s.replace(/\s+/g, " ").trim();
}

async function fetchOptions(url) {
  const res = await fetch(url, { method: "GET" });
  if (!res.ok) {
    throw new Error(`fetch failed: ${url} status=${res.status}`);
  }
  const data = await res.json();
  return Array.isArray(data?.options) ? data.options.map((v) => String(v)) : [];
}

async function main() {
  const databaseUrl = readEnvOrFile("DATABASE_URL");
  if (!databaseUrl) throw new Error("DATABASE_URL is required");

  const pazarBase = process.env.PAZAR_API_BASE_URL || "http://pazar-app:80";
  const root = `${pazarBase}/api/v1/options`;

  const cities = await fetchOptions(`${root}/cities`);
  const cityRows = [];
  const districtRows = [];
  const neighborhoodRows = [];

  const districtSeen = new Set();
  const neighborhoodSeen = new Set();

  for (const cityRaw of cities) {
    const city = String(cityRaw).trim();
    if (!city) continue;
    const cityNorm = normalizeTr(city);
    if (!cityNorm) continue;
    cityRows.push({ name: city, norm_name: cityNorm });

    const districts = await fetchOptions(`${root}/districts?city=${encodeURIComponent(city)}`);
    for (const districtRaw of districts) {
      const district = String(districtRaw).trim();
      if (!district) continue;
      const districtNorm = normalizeTr(district);
      if (!districtNorm) continue;
      const dKey = `${cityNorm}|${districtNorm}`;
      if (districtSeen.has(dKey)) continue;
      districtSeen.add(dKey);
      districtRows.push({ city_norm: cityNorm, name: district, norm_name: districtNorm });

      const neighborhoods = await fetchOptions(
        `${root}/neighborhoods?city=${encodeURIComponent(city)}&district=${encodeURIComponent(district)}`
      );
      for (const nRaw of neighborhoods) {
        const name = String(nRaw).trim();
        if (!name) continue;
        const normName = normalizeTr(name);
        if (!normName) continue;
        const nKey = `${cityNorm}|${districtNorm}|${normName}`;
        if (neighborhoodSeen.has(nKey)) continue;
        neighborhoodSeen.add(nKey);
        neighborhoodRows.push({
          city_norm: cityNorm,
          district_norm: districtNorm,
          name,
          norm_name: normName
        });
      }
    }
  }

  const pool = new Pool({ connectionString: databaseUrl });
  const client = await pool.connect();
  try {
    await client.query("begin");
    await client.query("truncate table address_neighborhoods, address_districts, address_cities restart identity cascade");

    for (const c of cityRows) {
      await client.query(
        "insert into address_cities(name,norm_name,created_at,updated_at) values ($1,$2,now(),now()) on conflict(norm_name) do update set name = excluded.name, updated_at = now()",
        [c.name, c.norm_name]
      );
    }

    const cityIdRes = await client.query("select id, norm_name from address_cities");
    const cityIdByNorm = new Map(cityIdRes.rows.map((r) => [String(r.norm_name), Number(r.id)]));

    for (const d of districtRows) {
      const cityId = cityIdByNorm.get(d.city_norm);
      if (!cityId) continue;
      await client.query(
        "insert into address_districts(city_id,name,norm_name,created_at,updated_at) values ($1,$2,$3,now(),now()) on conflict(city_id,norm_name) do update set name = excluded.name, updated_at = now()",
        [cityId, d.name, d.norm_name]
      );
    }

    const districtIdRes = await client.query("select id, city_id, norm_name from address_districts");
    const districtIdByKey = new Map(
      districtIdRes.rows.map((r) => [`${String(r.city_id)}|${String(r.norm_name)}`, Number(r.id)])
    );

    for (const n of neighborhoodRows) {
      const cityId = cityIdByNorm.get(n.city_norm);
      if (!cityId) continue;
      const districtId = districtIdByKey.get(`${cityId}|${n.district_norm}`);
      if (!districtId) continue;
      await client.query(
        "insert into address_neighborhoods(district_id,name,norm_name,created_at,updated_at) values ($1,$2,$3,now(),now()) on conflict(district_id,norm_name) do update set name = excluded.name, updated_at = now()",
        [districtId, n.name, n.norm_name]
      );
    }

    await client.query(
      `insert into address_manifest_versions(source, manifests_path, checksum_sha256, counts_json, loaded_at, created_at, updated_at)
       values ($1, $2, $3, jsonb_build_object(
         'cities', (select count(*) from address_cities),
         'districts', (select count(*) from address_districts),
         'neighborhoods', (select count(*) from address_neighborhoods)
       ), now(), now(), now())`,
      ["pazar-api", "http://pazar-app:80/api/v1/options", null]
    );

    await client.query("commit");
    const counts = await client.query(
      "select (select count(*) from address_cities) as cities, (select count(*) from address_districts) as districts, (select count(*) from address_neighborhoods) as neighborhoods"
    );
    console.log("IMPORT_OK", counts.rows[0]);
  } catch (err) {
    try { await client.query("rollback"); } catch {}
    throw err;
  } finally {
    client.release();
    await pool.end();
  }
}

main().catch((err) => {
  console.error("IMPORT_FAIL", err?.message || err);
  process.exit(1);
});
