import { z } from "zod";
import { requireAuth } from "./request_auth.js";

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

const tenantAddressBody = z.object({
  city: z.string().trim().min(1).max(120),
  district: z.string().trim().min(1).max(120),
  neighborhood: z.string().trim().min(1).max(160),
  street: z.string().trim().max(200).optional().nullable(),
  building_no: z.string().trim().max(40).optional().nullable(),
  door_no: z.string().trim().max(40).optional().nullable(),
  address_line: z.string().trim().max(500).optional().nullable(),
  lat: z.number().finite().min(-90).max(90).optional().nullable(),
  lng: z.number().finite().min(-180).max(180).optional().nullable()
});

async function requireTenantMembership(db, tenantId, userId) {
  const q = await db.query(
    "select 1 from memberships where tenant_id = $1 and user_id = $2 and status = 'active' limit 1",
    [tenantId, userId]
  );
  return q.rowCount > 0;
}

export async function registerV1AddressRoutes(app, { db }) {
  // Public read-only options (used by marketplace forms)
  app.get("/options/cities", async (_req, reply) => {
    const rows = await db.query("select name from address_cities order by name asc");
    return reply.send({ options: rows.rows.map((r) => String(r.name)) });
  });

  app.get("/options/districts", async (req, reply) => {
    const city = String(req.query?.city ?? "").trim();
    if (!city) return reply.code(422).send({ error: "missing_city", message: "city query parameter is required" });

    const normCity = normalizeTr(city);
    const c = await db.query("select id from address_cities where norm_name = $1 limit 1", [normCity]);
    if (c.rowCount === 0) return reply.send({ options: [] });

    const rows = await db.query(
      "select name from address_districts where city_id = $1 order by name asc",
      [c.rows[0].id]
    );
    return reply.send({ options: rows.rows.map((r) => String(r.name)) });
  });

  app.get("/options/neighborhoods", async (req, reply) => {
    const city = String(req.query?.city ?? "").trim();
    const district = String(req.query?.district ?? "").trim();
    if (!city || !district) {
      return reply.code(422).send({
        error: "missing_city_or_district",
        message: "city and district query parameters are required"
      });
    }

    const normCity = normalizeTr(city);
    const normDistrict = normalizeTr(district);
    const c = await db.query("select id from address_cities where norm_name = $1 limit 1", [normCity]);
    if (c.rowCount === 0) return reply.send({ options: [] });
    const d = await db.query(
      "select id from address_districts where city_id = $1 and norm_name = $2 limit 1",
      [c.rows[0].id, normDistrict]
    );
    if (d.rowCount === 0) return reply.send({ options: [] });

    const rows = await db.query(
      "select name from address_neighborhoods where district_id = $1 order by name asc",
      [d.rows[0].id]
    );
    return reply.send({ options: rows.rows.map((r) => String(r.name)) });
  });

  app.get("/tenants/:tenant_id/address", async (req, reply) => {
    const payload = requireAuth(req, reply);
    if (!payload) return;

    const tenantId = String(req.params?.tenant_id || "");
    const userId = String(payload.sub || "");
    if (!tenantId.match(/^[0-9a-f-]{36}$/i)) {
      return reply.code(400).send({ error: "invalid_tenant_id" });
    }

    const allowed = await requireTenantMembership(db, tenantId, userId);
    if (!allowed) return reply.code(403).send({ error: "forbidden", reason: "tenant_membership_required" });

    const q = await db.query(
      "select tenant_id, city, district, neighborhood, street, building_no, door_no, address_line, lat, lng, updated_at from tenant_addresses where tenant_id = $1 limit 1",
      [tenantId]
    );
    if (q.rowCount === 0) {
      return reply.send({ tenant_id: tenantId, address: null });
    }
    const r = q.rows[0];
    return reply.send({
      tenant_id: r.tenant_id,
      address: {
        city: r.city,
        district: r.district,
        neighborhood: r.neighborhood,
        street: r.street,
        building_no: r.building_no,
        door_no: r.door_no,
        address_line: r.address_line,
        lat: r.lat,
        lng: r.lng
      },
      updated_at: r.updated_at
    });
  });

  app.put("/tenants/:tenant_id/address", async (req, reply) => {
    const payload = requireAuth(req, reply);
    if (!payload) return;

    const tenantId = String(req.params?.tenant_id || "");
    const userId = String(payload.sub || "");
    if (!tenantId.match(/^[0-9a-f-]{36}$/i)) {
      return reply.code(400).send({ error: "invalid_tenant_id" });
    }

    const allowed = await requireTenantMembership(db, tenantId, userId);
    if (!allowed) return reply.code(403).send({ error: "forbidden", reason: "tenant_membership_required" });

    const parsed = tenantAddressBody.safeParse(req.body ?? {});
    if (!parsed.success) {
      return reply.code(400).send({ error: parsed.error.flatten() });
    }
    const b = parsed.data;

    await db.query(
      `insert into tenant_addresses
        (tenant_id, city, district, neighborhood, street, building_no, door_no, address_line, lat, lng, updated_by_user_id, created_at, updated_at)
       values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,now(),now())
       on conflict (tenant_id) do update set
        city = excluded.city,
        district = excluded.district,
        neighborhood = excluded.neighborhood,
        street = excluded.street,
        building_no = excluded.building_no,
        door_no = excluded.door_no,
        address_line = excluded.address_line,
        lat = excluded.lat,
        lng = excluded.lng,
        updated_by_user_id = excluded.updated_by_user_id,
        updated_at = now()`,
      [
        tenantId,
        b.city,
        b.district,
        b.neighborhood,
        b.street ?? null,
        b.building_no ?? null,
        b.door_no ?? null,
        b.address_line ?? null,
        b.lat ?? null,
        b.lng ?? null,
        userId
      ]
    );

    return reply.send({ ok: true, tenant_id: tenantId });
  });
}
