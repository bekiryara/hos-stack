import { z } from "zod";
import { audit } from "../../audit.js";
import { requireRole } from "./request_auth.js";

function normalizeMetadata(v) {
  if (v == null) return {};
  if (typeof v === "object") return v;
  if (typeof v === "string") {
    try {
      const parsed = JSON.parse(v);
      return parsed && typeof parsed === "object" ? parsed : {};
    } catch {
      return {};
    }
  }
  return {};
}

function parseLimit(raw, fallback = 50) {
  let limit = Number(raw ?? fallback);
  if (!Number.isFinite(limit)) limit = fallback;
  limit = Math.floor(limit);
  if (limit < 1) limit = 1;
  if (limit > 200) limit = 200;
  return limit;
}

function parseOffset(raw) {
  let offset = Number(raw ?? 0);
  if (!Number.isFinite(offset)) offset = 0;
  offset = Math.floor(offset);
  if (offset < 0) offset = 0;
  if (offset > 100000) offset = 100000;
  return offset;
}

function parseIsoDate(raw) {
  if (!raw) return null;
  const d = new Date(String(raw));
  return Number.isFinite(d.getTime()) ? d.toISOString() : null;
}

function parseLikeTokens(raw) {
  return String(raw || "")
    .toLowerCase()
    .split(/[\s|,;]+/)
    .map((x) => x.trim())
    .filter(Boolean)
    .slice(0, 8);
}

function parseListingStatus(raw) {
  const s = String(raw || "all").trim().toLowerCase();
  if (s === "all" || s === "draft" || s === "published" || s === "paused" || s === "archived") return s;
  return "all";
}

function parseSafeText(raw, max = 120) {
  const v = String(raw || "").trim();
  if (!v) return "";
  return v.slice(0, max);
}

const LISTING_FETCH_PER_STATUS = 1000;

async function fetchPazarListings({ pazarBaseUrl, status, perPage }) {
  const qs = new URLSearchParams();
  qs.set("status", status);
  qs.set("page", "1");
  qs.set("per_page", String(perPage));

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 10000);
  try {
    const response = await fetch(`${pazarBaseUrl}/api/v1/listings?${qs.toString()}`, {
      method: "GET",
      headers: {
        Accept: "application/json",
      },
      signal: controller.signal,
    });

    if (!response.ok) {
      const errorText = await response.text().catch(() => "");
      const err = new Error(`pazar_listings_fetch_failed_${response.status}`);
      err.status = response.status;
      err.message = errorText || err.message;
      throw err;
    }

    const data = await response.json();
    if (!Array.isArray(data)) return [];
    return data;
  } finally {
    clearTimeout(timeout);
  }
}

async function fetchPazarListingById({ pazarBaseUrl, listingId }) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 10000);
  try {
    const response = await fetch(`${pazarBaseUrl}/api/v1/listings/${encodeURIComponent(listingId)}`, {
      method: "GET",
      headers: { Accept: "application/json" },
      signal: controller.signal,
    });
    if (!response.ok) {
      const errorText = await response.text().catch(() => "");
      const err = new Error(`pazar_listing_fetch_failed_${response.status}`);
      err.status = response.status;
      err.message = errorText || err.message;
      throw err;
    }
    return await response.json();
  } finally {
    clearTimeout(timeout);
  }
}

function collectCategoryMapFromTree(nodes, out = {}) {
  if (!Array.isArray(nodes)) return out;
  for (const node of nodes) {
    if (!node || typeof node !== "object") continue;
    const id = String(node?.id || "").trim();
    const title = String(node?.title || "").trim();
    if (id) out[id] = title || id;
    const children = Array.isArray(node?.children) ? node.children : [];
    if (children.length > 0) collectCategoryMapFromTree(children, out);
  }
  return out;
}

async function fetchPazarCategoryTitleMap({ pazarBaseUrl }) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 10000);
  try {
    const response = await fetch(`${pazarBaseUrl}/api/v1/categories`, {
      method: "GET",
      headers: { Accept: "application/json" },
      signal: controller.signal,
    });
    if (!response.ok) return {};
    const data = await response.json();
    return collectCategoryMapFromTree(data, {});
  } catch {
    return {};
  } finally {
    clearTimeout(timeout);
  }
}

async function fetchPazarCategoriesTree({ pazarBaseUrl, view = "", status = "" }) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 10000);
  try {
    const qs = new URLSearchParams();
    if (view) qs.set("view", view);
    if (status) qs.set("status", status);
    const url = `${pazarBaseUrl}/api/v1/categories${qs.toString() ? `?${qs.toString()}` : ""}`;
    const response = await fetch(url, {
      method: "GET",
      headers: { Accept: "application/json" },
      signal: controller.signal,
    });
    if (!response.ok) return [];
    const data = await response.json();
    return Array.isArray(data) ? data : [];
  } catch {
    return [];
  } finally {
    clearTimeout(timeout);
  }
}

function flattenCategoryTree(nodes, out = []) {
  if (!Array.isArray(nodes)) return out;
  for (const node of nodes) {
    if (!node || typeof node !== "object") continue;
    out.push(node);
    const children = Array.isArray(node?.children) ? node.children : [];
    if (children.length > 0) flattenCategoryTree(children, out);
  }
  return out;
}

function parseTrendyolWcFromSlug(slug) {
  const s = String(slug || "");
  const m = s.match(/-ty-c(\d+)$/);
  return m?.[1] || null;
}

/**
 * Register platform-scoped admin routes.
 * Scope: global visibility across all tenants/worlds for owner/admin roles.
 */
export async function registerV1AdminPlatformRoutes(app, { db }) {
  app.get("/admin/platform/categories/overview", async (req, reply) => {
    const payload = requireRole(req, reply, ["owner", "admin"]);
    if (!payload) return;

    const pazarBaseUrl = process.env.PAZAR_API_BASE_URL || "http://pazar-app:80";
    const [canonicalTree, menuTree] = await Promise.all([
      fetchPazarCategoriesTree({ pazarBaseUrl, view: "", status: "all" }),
      fetchPazarCategoriesTree({ pazarBaseUrl, view: "menu" }),
    ]);

    const canonicalFlat = flattenCategoryTree(canonicalTree, []);
    const total = canonicalFlat.length;
    const rootCount = canonicalFlat.filter((n) => n?.parent_id == null).length;
    const activeCount = canonicalFlat.filter((n) => String(n?.status || "").toLowerCase() === "active").length;
    const inactiveCount = canonicalFlat.filter((n) => String(n?.status || "").toLowerCase() !== "active").length;

    const childCountById = {};
    for (const n of canonicalFlat) {
      const pid = String(n?.parent_id || "");
      if (!pid) continue;
      childCountById[pid] = (childCountById[pid] || 0) + 1;
    }
    const leafCount = canonicalFlat.filter((n) => !childCountById[String(n?.id || "")]).length;

    const trendyolMapped = canonicalFlat.filter((n) => Boolean(parseTrendyolWcFromSlug(n?.slug))).length;
    const byWc = new Map();
    for (const n of canonicalFlat) {
      const wc = parseTrendyolWcFromSlug(n?.slug);
      if (!wc) continue;
      const canonicalId = String(n?.canonical_category_id || n?.id || "");
      if (!byWc.has(wc)) byWc.set(wc, new Set());
      byWc.get(wc).add(canonicalId);
    }
    const wcConflictCount = Array.from(byWc.values()).filter((set) => set.size > 1).length;

    const menuFlat = flattenCategoryTree(menuTree, []);
    const menuNodeCount = menuFlat.length;
    const menuWithCanonicalCount = menuFlat.filter((n) => n?.canonical_category_id != null).length;
    const menuVirtualCount = menuFlat.filter((n) => String(n?.status || "") === "virtual").length;

    return reply.send({
      total_categories: total,
      active_categories: activeCount,
      inactive_categories: inactiveCount,
      root_categories: rootCount,
      leaf_categories: leafCount,
      trendyol_mapped_categories: trendyolMapped,
      trendyol_wc_conflict_count: wcConflictCount,
      menu_nodes_total: menuNodeCount,
      menu_nodes_with_canonical: menuWithCanonicalCount,
      menu_virtual_nodes: menuVirtualCount,
    });
  });

  app.get("/admin/platform/categories/tree", async (req, reply) => {
    const payload = requireRole(req, reply, ["owner", "admin"]);
    if (!payload) return;

    const pazarBaseUrl = process.env.PAZAR_API_BASE_URL || "http://pazar-app:80";
    const q = parseSafeText(req?.query?.q, 120).toLowerCase();
    const status = String(req?.query?.status || "all").toLowerCase();

    const tree = await fetchPazarCategoriesTree({ pazarBaseUrl, view: "", status: "all" });
    if (!q && status === "all") {
      return reply.send({ tree });
    }

    const keepByStatus = (node) => {
      if (status === "all") return true;
      const s = String(node?.status || "").toLowerCase();
      return s === status;
    };
    const keepByQuery = (node) => {
      if (!q) return true;
      const title = String(node?.title || "").toLowerCase();
      const slug = String(node?.slug || "").toLowerCase();
      const id = String(node?.id || "").toLowerCase();
      return title.includes(q) || slug.includes(q) || id.includes(q);
    };

    const filterTree = (nodes) => {
      if (!Array.isArray(nodes)) return [];
      const out = [];
      for (const node of nodes) {
        const children = filterTree(Array.isArray(node?.children) ? node.children : []);
        const selfMatch = keepByStatus(node) && keepByQuery(node);
        if (selfMatch || children.length > 0) {
          out.push({
            ...node,
            children,
          });
        }
      }
      return out;
    };

    return reply.send({ tree: filterTree(tree) });
  });

  app.get("/admin/platform/categories/mappings", async (req, reply) => {
    const payload = requireRole(req, reply, ["owner", "admin"]);
    if (!payload) return;

    const pazarBaseUrl = process.env.PAZAR_API_BASE_URL || "http://pazar-app:80";
    const q = parseSafeText(req?.query?.q, 120).toLowerCase();
    const mappingType = String(req?.query?.mapping || "all").toLowerCase();
    const page = Math.max(1, Math.floor(Number(req?.query?.page ?? 1) || 1));
    const perPage = parseLimit(req?.query?.per_page, 100);

    const [canonicalTree, menuTree] = await Promise.all([
      fetchPazarCategoriesTree({ pazarBaseUrl, view: "", status: "all" }),
      fetchPazarCategoriesTree({ pazarBaseUrl, view: "menu" }),
    ]);
    const canonicalFlat = flattenCategoryTree(canonicalTree, []);
    const menuFlat = flattenCategoryTree(menuTree, []);

    const menuPlacementByCanonicalId = {};
    for (const n of menuFlat) {
      const cid = String(n?.canonical_category_id || "").trim();
      if (!cid) continue;
      menuPlacementByCanonicalId[cid] = (menuPlacementByCanonicalId[cid] || 0) + 1;
    }

    let items = canonicalFlat.map((n) => {
      const internalId = String(n?.id || "");
      const trendyolWc = parseTrendyolWcFromSlug(n?.slug);
      return {
        internal_category_id: internalId,
        canonical_category_id: String(n?.canonical_category_id || n?.id || ""),
        slug: String(n?.slug || ""),
        title: String(n?.title || ""),
        status: String(n?.status || ""),
        external_source: trendyolWc ? "trendyol" : null,
        external_id: trendyolWc,
        menu_placements: menuPlacementByCanonicalId[internalId] || 0,
      };
    });

    if (mappingType === "mapped") items = items.filter((x) => Boolean(x.external_id));
    if (mappingType === "unmapped") items = items.filter((x) => !x.external_id);

    if (q) {
      items = items.filter((x) => {
        return (
          String(x.title || "").toLowerCase().includes(q) ||
          String(x.slug || "").toLowerCase().includes(q) ||
          String(x.internal_category_id || "").toLowerCase().includes(q) ||
          String(x.external_id || "").toLowerCase().includes(q)
        );
      });
    }

    items.sort((a, b) => {
      const t = String(a.title || "").localeCompare(String(b.title || ""), "tr");
      if (t !== 0) return t;
      return String(a.internal_category_id || "").localeCompare(String(b.internal_category_id || ""));
    });

    const total = items.length;
    const offset = (page - 1) * perPage;
    return reply.send({
      items: items.slice(offset, offset + perPage),
      page,
      per_page: perPage,
      total,
    });
  });

  app.get("/admin/platform/overview", async (req, reply) => {
    const payload = requireRole(req, reply, ["owner", "admin"]);
    if (!payload) return;

    const [tenants, users, memberships, audit24h] = await Promise.all([
      db.query("select count(*)::int as c from tenants"),
      db.query("select count(*)::int as c from users"),
      db.query("select count(*)::int as c from memberships where status = 'active'"),
      db.query("select count(*)::int as c from audit_events where created_at >= now() - interval '24 hours'")
    ]);

    return reply.send({
      tenants_total: tenants.rows?.[0]?.c ?? 0,
      users_total: users.rows?.[0]?.c ?? 0,
      memberships_active: memberships.rows?.[0]?.c ?? 0,
      audit_events_24h: audit24h.rows?.[0]?.c ?? 0
    });
  });

  app.get("/admin/platform/action-center", async (req, reply) => {
    const payload = requireRole(req, reply, ["owner", "admin"]);
    if (!payload) return;

    const criticalActions = [
      "user.delete.platform",
      "user.deactivate.platform",
      "membership.delete.platform",
      "membership.deactivate.platform",
      "user.role.change.platform"
    ];

    const [
      critical24h,
      usersDeactivated24h,
      usersDeleted24h,
      membershipsDeactivated24h,
      membershipsDeleted24h,
      ownerRiskTenants,
      latestCritical
    ] = await Promise.all([
      db.query(
        "select count(*)::int as c from audit_events where created_at >= now() - interval '24 hours' and action = any($1::text[])",
        [criticalActions]
      ),
      db.query(
        "select count(*)::int as c from audit_events where created_at >= now() - interval '24 hours' and action = 'user.deactivate.platform'"
      ),
      db.query(
        "select count(*)::int as c from audit_events where created_at >= now() - interval '24 hours' and action = 'user.delete.platform'"
      ),
      db.query(
        "select count(*)::int as c from audit_events where created_at >= now() - interval '24 hours' and action = 'membership.deactivate.platform'"
      ),
      db.query(
        "select count(*)::int as c from audit_events where created_at >= now() - interval '24 hours' and action = 'membership.delete.platform'"
      ),
      db.query(
        "select count(*)::int as c from (select tenant_id from memberships where status = 'active' group by tenant_id having sum(case when role = 'owner' then 1 else 0 end) = 1) r"
      ),
      db.query(
        "select a.id, a.action, a.created_at, a.actor_user_id, au.email as actor_email, a.tenant_id, t.slug as tenant_slug from audit_events a left join tenants t on t.id = a.tenant_id left join users au on au.id = a.actor_user_id where a.action = any($1::text[]) order by a.created_at desc limit 10",
        [criticalActions]
      )
    ]);

    return reply.send({
      critical_events_24h: critical24h.rows?.[0]?.c ?? 0,
      owner_risk_tenants: ownerRiskTenants.rows?.[0]?.c ?? 0,
      users_deactivated_24h: usersDeactivated24h.rows?.[0]?.c ?? 0,
      users_deleted_24h: usersDeleted24h.rows?.[0]?.c ?? 0,
      memberships_deactivated_24h: membershipsDeactivated24h.rows?.[0]?.c ?? 0,
      memberships_deleted_24h: membershipsDeleted24h.rows?.[0]?.c ?? 0,
      latest_critical_events: latestCritical.rows ?? []
    });
  });

  app.get("/admin/platform/listings", async (req, reply) => {
    const payload = requireRole(req, reply, ["owner", "admin"]);
    if (!payload) return;

    const pazarBaseUrl = process.env.PAZAR_API_BASE_URL || "http://pazar-app:80";
    const status = parseListingStatus(req?.query?.status);
    const tenantId = parseSafeText(req?.query?.tenant_id, 64);
    const q = parseSafeText(req?.query?.q, 120).toLowerCase();
    const page = Math.max(1, Math.floor(Number(req?.query?.page ?? 1) || 1));
    const perPage = parseLimit(req?.query?.per_page, 50);

    const statusesToFetch = status === "all" ? ["draft", "published", "paused", "archived"] : [status];

    let combined = [];
    try {
      const chunks = await Promise.all(
        statusesToFetch.map((s) => fetchPazarListings({ pazarBaseUrl, status: s, perPage: LISTING_FETCH_PER_STATUS }))
      );
      combined = chunks.flat();
    } catch (e) {
      return reply.code(502).send({
        error: "pazar_api_unavailable",
        message: String(e?.message || e),
      });
    }

    const seen = new Set();
    let items = [];
    for (const row of combined) {
      const id = String(row?.id || "");
      if (!id || seen.has(id)) continue;
      seen.add(id);
      items.push(row);
    }

    if (tenantId) {
      items = items.filter((x) => String(x?.tenant_id || "") === tenantId);
    }

    if (q) {
      items = items.filter((x) => {
        const title = String(x?.title || "").toLowerCase();
        const id = String(x?.id || "").toLowerCase();
        const tenant = String(x?.tenant_id || "").toLowerCase();
        return title.includes(q) || id.includes(q) || tenant.includes(q);
      });
    }

    items.sort((a, b) => {
      const au = String(a?.updated_at || a?.created_at || "");
      const bu = String(b?.updated_at || b?.created_at || "");
      return bu.localeCompare(au);
    });

    const total = items.length;
    const offset = (page - 1) * perPage;
    const paged = items.slice(offset, offset + perPage);

    const tenantIds = Array.from(
      new Set(
        paged
          .map((x) => String(x?.tenant_id || "").trim())
          .filter(Boolean)
      )
    );
    let tenantMap = {};
    if (tenantIds.length > 0) {
      const tenantsRes = await db.query(
        "select id, slug, coalesce(display_name, name, slug) as tenant_name from tenants where id = any($1::uuid[])",
        [tenantIds]
      );
      tenantMap = Object.fromEntries(
        (tenantsRes.rows || []).map((t) => [String(t.id), { slug: t.slug, name: t.tenant_name }])
      );
    }
    const categoryTitleMap = await fetchPazarCategoryTitleMap({ pazarBaseUrl });
    const enriched = paged.map((row) => {
      const tid = String(row?.tenant_id || "");
      const tenant = tenantMap[tid] || null;
      const categoryId = String(row?.category_id || "").trim();
      return {
        ...row,
        tenant_slug: tenant?.slug || null,
        tenant_name: tenant?.name || null,
        category_title: categoryId ? categoryTitleMap[categoryId] || null : null,
      };
    });

    return reply.send({
      items: enriched,
      page,
      per_page: perPage,
      total,
      statuses: statusesToFetch,
    });
  });

  app.get("/admin/platform/listings/overview", async (req, reply) => {
    const payload = requireRole(req, reply, ["owner", "admin"]);
    if (!payload) return;

    const pazarBaseUrl = process.env.PAZAR_API_BASE_URL || "http://pazar-app:80";
    const statuses = ["draft", "published", "paused", "archived"];
    let combined = [];
    try {
      const chunks = await Promise.all(
        statuses.map((s) => fetchPazarListings({ pazarBaseUrl, status: s, perPage: LISTING_FETCH_PER_STATUS }))
      );
      combined = chunks.flat();
    } catch (e) {
      return reply.code(502).send({
        error: "pazar_api_unavailable",
        message: String(e?.message || e),
      });
    }

    const seen = new Set();
    let items = [];
    for (const row of combined) {
      const id = String(row?.id || "");
      if (!id || seen.has(id)) continue;
      seen.add(id);
      items.push(row);
    }

    const counts = { draft: 0, published: 0, paused: 0, archived: 0 };
    for (const row of items) {
      const s = String(row?.status || "");
      if (s === "draft") counts.draft += 1;
      else if (s === "published") counts.published += 1;
      else if (s === "paused") counts.paused += 1;
      else if (s === "archived") counts.archived += 1;
    }

    const lifecycle24h = await db.query(
      "select count(*)::int as total_24h, count(*) filter (where metadata->>'action' = 'publish')::int as publish_24h, count(*) filter (where metadata->>'action' = 'pause')::int as pause_24h, count(*) filter (where metadata->>'action' = 'archive')::int as archive_24h, count(*) filter (where metadata->>'action' = 'delete')::int as delete_24h from audit_events where action = 'listing.lifecycle.platform' and created_at >= now() - interval '24 hours'"
    );

    return reply.send({
      total: items.length,
      draft: counts.draft,
      published: counts.published,
      paused: counts.paused,
      archived: counts.archived,
      lifecycle_24h_total: lifecycle24h.rows?.[0]?.total_24h ?? 0,
      lifecycle_24h_publish: lifecycle24h.rows?.[0]?.publish_24h ?? 0,
      lifecycle_24h_pause: lifecycle24h.rows?.[0]?.pause_24h ?? 0,
      lifecycle_24h_archive: lifecycle24h.rows?.[0]?.archive_24h ?? 0,
      lifecycle_24h_delete: lifecycle24h.rows?.[0]?.delete_24h ?? 0,
    });
  });

  app.post("/admin/platform/listings/:id/lifecycle", async (req, reply) => {
    const payload = requireRole(req, reply, ["owner", "admin"]);
    if (!payload) return;

    const listingId = String(req.params?.id || "").trim();
    if (!listingId) return reply.code(400).send({ error: "invalid_listing_id" });

    const action = String(req?.body?.action || "").trim().toLowerCase();
    if (!["publish", "pause", "archive", "delete"].includes(action)) {
      return reply.code(400).send({ error: "invalid_action" });
    }

    const pazarBaseUrl = process.env.PAZAR_API_BASE_URL || "http://pazar-app:80";
    let listing = null;
    try {
      listing = await fetchPazarListingById({ pazarBaseUrl, listingId });
    } catch (e) {
      const status = Number(e?.status || 502);
      if (status === 404) return reply.code(404).send({ error: "listing_not_found" });
      return reply.code(502).send({ error: "pazar_api_unavailable", message: String(e?.message || e) });
    }

    const authHeader = req.headers?.authorization ? String(req.headers.authorization) : "";
    if (!authHeader) return reply.code(401).send({ error: "unauthorized" });

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 10000);
    let response = null;
    let bodyText = "";
    let out = null;
    try {
      response = await fetch(`${pazarBaseUrl}/api/v1/listings/${encodeURIComponent(listingId)}/admin-transition`, {
        method: "POST",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
          Authorization: authHeader,
        },
        body: JSON.stringify({ action }),
        signal: controller.signal,
      });
      bodyText = await response.text();
      try {
        out = bodyText ? JSON.parse(bodyText) : null;
      } catch {
        out = { raw: bodyText };
      }
    } finally {
      clearTimeout(timeout);
    }

    if (!response?.ok) {
      return reply.code(response?.status || 502).send(out || { error: "transition_failed" });
    }

    await audit(db, {
      action: "listing.lifecycle.platform",
      tenantId: String(listing?.tenant_id || payload.tenantId || ""),
      actorUserId: payload.sub,
      metadata: {
        listingId,
        listingTitle: String(listing?.title || ""),
        listingTenantId: String(listing?.tenant_id || ""),
        prevStatus: String(listing?.status || ""),
        action,
        nextStatus: String(out?.status || (action === "delete" ? "deleted" : "")),
        deleted: Boolean(out?.deleted || false),
      },
    });

    return reply.send({ ok: true, item: out });
  });

  app.get("/admin/platform/tenants", async (req, reply) => {
    const payload = requireRole(req, reply, ["owner", "admin"]);
    if (!payload) return;

    const res = await db.query(
      "select t.id, t.slug, t.name, t.display_name, t.status, t.created_at, count(u.id)::int as users_count from tenants t left join users u on u.tenant_id = t.id group by t.id order by t.created_at asc"
    );
    return reply.send({ items: res.rows });
  });

  app.get("/admin/platform/users", async (req, reply) => {
    const payload = requireRole(req, reply, ["owner", "admin"]);
    if (!payload) return;

    const res = await db.query(
      "select u.id, u.email, u.role, u.created_at, (u.google_sub is not null) as google_linked, u.tenant_id, t.slug as tenant_slug, t.display_name as tenant_name from users u inner join tenants t on t.id = u.tenant_id order by u.created_at asc"
    );
    return reply.send({ items: res.rows });
  });

  app.get("/admin/platform/memberships", async (req, reply) => {
    const payload = requireRole(req, reply, ["owner", "admin"]);
    if (!payload) return;

    const res = await db.query(
      "select m.tenant_id, m.user_id, m.role, m.status, m.created_at, m.updated_at, u.email as user_email, u.display_name as user_display_name, t.slug as tenant_slug, t.display_name as tenant_name from memberships m inner join users u on u.id = m.user_id inner join tenants t on t.id = m.tenant_id order by m.created_at asc"
    );
    return reply.send({ items: res.rows });
  });

  const patchMembershipBody = z
    .object({
      role: z.enum(["member", "admin", "owner"]).optional(),
      status: z.enum(["active", "inactive", "suspended"]).optional()
    })
    .refine((v) => v.role !== undefined || v.status !== undefined, {
      message: "role_or_status_required"
    });
  const membershipLifecycleBody = z.object({
    action: z.enum(["deactivate", "delete"])
  });

  app.patch("/admin/platform/memberships/:tenantId/:userId", async (req, reply) => {
    const payload = requireRole(req, reply, ["owner"]);
    if (!payload) return;

    const tenantId = String(req.params?.tenantId || "");
    const userId = String(req.params?.userId || "");
    if (!tenantId) return reply.code(400).send({ error: "invalid_tenant_id" });
    if (!userId) return reply.code(400).send({ error: "invalid_user_id" });

    const body = patchMembershipBody.safeParse(req.body);
    if (!body.success) return reply.code(400).send({ error: body.error.flatten() });

    const currentRes = await db.query(
      "select tenant_id, user_id, role, status from memberships where tenant_id = $1 and user_id = $2 limit 1",
      [tenantId, userId]
    );
    if (currentRes.rowCount === 0) return reply.code(404).send({ error: "membership_not_found" });

    const current = currentRes.rows[0];
    const nextRole = body.data.role ?? current.role;
    const nextStatus = body.data.status ?? current.status;

    if (current.role === "owner" && current.status === "active" && (nextRole !== "owner" || nextStatus !== "active")) {
      const owners = await db.query(
        "select count(*)::int as c from memberships where tenant_id = $1 and role = 'owner' and status = 'active'",
        [tenantId]
      );
      const count = owners.rows?.[0]?.c ?? 0;
      if (count <= 1) {
        return reply.code(409).send({ error: "cannot_remove_last_owner" });
      }
    }

    await db.query(
      "update memberships set role = $1, status = $2, updated_at = now() where tenant_id = $3 and user_id = $4",
      [nextRole, nextStatus, tenantId, userId]
    );

    if (body.data.role !== undefined) {
      await db.query("update users set role = $1 where tenant_id = $2 and id = $3", [nextRole, tenantId, userId]);
    }

    await audit(db, {
      action: "membership.update.platform",
      tenantId,
      actorUserId: payload.sub,
      metadata: { targetUserId: userId, role: nextRole, status: nextStatus }
    });

    return reply.send({ ok: true, item: { tenant_id: tenantId, user_id: userId, role: nextRole, status: nextStatus } });
  });

  app.post("/admin/platform/memberships/:tenantId/:userId/lifecycle", async (req, reply) => {
    const payload = requireRole(req, reply, ["owner"]);
    if (!payload) return;

    const tenantId = String(req.params?.tenantId || "");
    const userId = String(req.params?.userId || "");
    if (!tenantId) return reply.code(400).send({ error: "invalid_tenant_id" });
    if (!userId) return reply.code(400).send({ error: "invalid_user_id" });

    const body = membershipLifecycleBody.safeParse(req.body);
    if (!body.success) return reply.code(400).send({ error: body.error.flatten() });

    const currentRes = await db.query(
      "select tenant_id, user_id, role, status from memberships where tenant_id = $1 and user_id = $2 limit 1",
      [tenantId, userId]
    );
    if (currentRes.rowCount === 0) return reply.code(404).send({ error: "membership_not_found" });

    const current = currentRes.rows[0];
    const isOwnerActive = current.role === "owner" && current.status === "active";
    if (isOwnerActive) {
      const owners = await db.query(
        "select count(*)::int as c from memberships where tenant_id = $1 and role = 'owner' and status = 'active'",
        [tenantId]
      );
      const count = owners.rows?.[0]?.c ?? 0;
      if (count <= 1) return reply.code(409).send({ error: "cannot_remove_last_owner" });
    }

    if (body.data.action === "deactivate") {
      await db.query(
        "update memberships set status = 'inactive', updated_at = now() where tenant_id = $1 and user_id = $2",
        [tenantId, userId]
      );
      await db.query(
        "update users set role = 'member' where id = $1 and tenant_id = $2 and role <> 'member'",
        [userId, tenantId]
      );
      await audit(db, {
        action: "membership.deactivate.platform",
        tenantId,
        actorUserId: payload.sub,
        metadata: { targetUserId: userId }
      });
      return reply.send({ ok: true, action: "deactivate" });
    }

    await db.query("delete from memberships where tenant_id = $1 and user_id = $2", [tenantId, userId]);
    await db.query(
      "update users set role = 'member' where id = $1 and tenant_id = $2 and role <> 'member'",
      [userId, tenantId]
    );
    await audit(db, {
      action: "membership.delete.platform",
      tenantId,
      actorUserId: payload.sub,
      metadata: { targetUserId: userId }
    });
    return reply.send({ ok: true, action: "delete" });
  });

  app.get("/admin/platform/audit", async (req, reply) => {
    const payload = requireRole(req, reply, ["owner", "admin"]);
    if (!payload) return;

    const limit = parseLimit(req?.query?.limit, 50);
    const offset = parseOffset(req?.query?.offset);
    const actionTokens = parseLikeTokens(req?.query?.action);
    const actorLike = String(req?.query?.actor || "").trim().toLowerCase();
    const tenantLike = String(req?.query?.tenant || "").trim().toLowerCase();
    const qTokens = parseLikeTokens(req?.query?.q);
    const fromIso = parseIsoDate(req?.query?.from);
    const toIso = parseIsoDate(req?.query?.to);

    const where = [];
    const params = [];
    let i = 1;

    if (actionTokens.length > 0) {
      const parts = actionTokens.map((tok) => {
        const p = `$${i++}`;
        params.push(`%${tok}%`);
        return `lower(a.action) like ${p}`;
      });
      where.push(`(${parts.join(" or ")})`);
    }
    if (actorLike) {
      where.push(`lower(coalesce(a.actor_user_id::text,'')) like $${i++}`);
      params.push(`%${actorLike}%`);
    }
    if (tenantLike) {
      where.push(`lower(coalesce(t.slug,'')) like $${i++}`);
      params.push(`%${tenantLike}%`);
    }
    if (fromIso) {
      where.push(`a.created_at >= $${i++}`);
      params.push(fromIso);
    }
    if (toIso) {
      where.push(`a.created_at <= $${i++}`);
      params.push(toIso);
    }
    if (qTokens.length > 0) {
      const qParts = qTokens.map((tok) => {
        const p = `$${i++}`;
        params.push(`%${tok}%`);
        return `(lower(coalesce(a.action,'')) like ${p} or lower(coalesce(a.actor_user_id::text,'')) like ${p} or lower(coalesce(au.email,'')) like ${p} or lower(coalesce(t.slug,'')) like ${p})`;
      });
      where.push(`(${qParts.join(" or ")})`);
    }

    params.push(limit);
    params.push(offset);
    const whereSql = where.length > 0 ? `where ${where.join(" and ")}` : "";
    const sql = `select a.id, a.action, a.created_at, a.metadata, a.actor_user_id, au.email as actor_email, a.tenant_id, t.slug as tenant_slug from audit_events a left join tenants t on t.id = a.tenant_id left join users au on au.id = a.actor_user_id ${whereSql} order by a.created_at desc limit $${i} offset $${i + 1}`;
    const res = await db.query(sql, params);

    return reply.send({ items: res.rows.map((r) => ({ ...r, metadata: normalizeMetadata(r.metadata) })) });
  });

  const patchUserRoleBody = z.object({
    role: z.enum(["member", "admin", "owner"])
  });
  const userLifecycleBody = z.object({
    action: z.enum(["deactivate", "delete"])
  });

  app.patch("/admin/platform/users/:id/role", async (req, reply) => {
    const payload = requireRole(req, reply, ["owner"]);
    if (!payload) return;

    const body = patchUserRoleBody.safeParse(req.body);
    if (!body.success) return reply.code(400).send({ error: body.error.flatten() });

    const userId = String(req.params?.id || "");
    if (!userId) return reply.code(400).send({ error: "invalid_user_id" });

    const target = await db.query("select id, tenant_id, role from users where id = $1 limit 1", [userId]);
    if (target.rowCount === 0) return reply.code(404).send({ error: "user_not_found" });

    const currentRole = target.rows[0].role ?? "member";
    const targetTenantId = target.rows[0].tenant_id;
    const nextRole = body.data.role;

    if (currentRole === "owner" && nextRole !== "owner") {
      const owners = await db.query(
        "select count(*)::int as c from users where tenant_id = $1 and role = 'owner'",
        [targetTenantId]
      );
      const count = owners.rows?.[0]?.c ?? 0;
      if (count <= 1) return reply.code(409).send({ error: "cannot_remove_last_owner" });
    }

    await db.query("update users set role = $1 where id = $2", [nextRole, userId]);
    await db.query(
      "insert into memberships (tenant_id, user_id, role, status) values ($1, $2, $3, $4) on conflict (tenant_id, user_id) do update set role = $3, status = $4, updated_at = now()",
      [targetTenantId, userId, nextRole, "active"]
    );

    await audit(db, {
      action: "user.role.change.platform",
      tenantId: targetTenantId,
      actorUserId: payload.sub,
      metadata: { targetUserId: userId, role: nextRole, membershipEnsured: true }
    });

    return reply.send({ ok: true });
  });

  app.post("/admin/platform/users/:id/lifecycle", async (req, reply) => {
    const payload = requireRole(req, reply, ["owner"]);
    if (!payload) return;

    const body = userLifecycleBody.safeParse(req.body);
    if (!body.success) return reply.code(400).send({ error: body.error.flatten() });

    const userId = String(req.params?.id || "");
    if (!userId) return reply.code(400).send({ error: "invalid_user_id" });
    if (userId === String(payload.sub || "")) return reply.code(409).send({ error: "cannot_delete_current_admin_session" });

    const target = await db.query("select id, tenant_id, email, role from users where id = $1 limit 1", [userId]);
    if (target.rowCount === 0) return reply.code(404).send({ error: "user_not_found" });
    const targetTenantId = target.rows[0].tenant_id;
    const targetEmail = target.rows[0].email;

    const lockedOwner = await db.query(
      "select m.tenant_id from memberships m where m.user_id = $1 and m.role = 'owner' and m.status = 'active' and (select count(*)::int from memberships mo where mo.tenant_id = m.tenant_id and mo.role = 'owner' and mo.status = 'active') <= 1 limit 1",
      [userId]
    );
    if (lockedOwner.rowCount > 0) return reply.code(409).send({ error: "cannot_remove_last_owner" });

    if (body.data.action === "deactivate") {
      const disabledMemberships = await db.query(
        "update memberships set status = 'inactive', updated_at = now() where user_id = $1 and status = 'active'",
        [userId]
      );
      await db.query("update users set role = 'member' where id = $1 and role <> 'member'", [userId]);

      await audit(db, {
        action: "user.deactivate.platform",
        tenantId: targetTenantId,
        actorUserId: payload.sub,
        metadata: { targetUserId: userId, targetEmail, activeMembershipsDisabled: disabledMemberships.rowCount ?? 0 }
      });

      return reply.send({ ok: true, action: "deactivate", active_memberships_disabled: disabledMemberships.rowCount ?? 0 });
    }

    const permitRefs = await db.query("select count(*)::int as c from hos_permits where actor_id = $1", [userId]);
    const permitCount = permitRefs.rows?.[0]?.c ?? 0;
    if (permitCount > 0) {
      return reply.code(409).send({ error: "cannot_delete_user_with_permits", permits_count: permitCount });
    }

    await db.query("begin");
    try {
      const del = await db.query("delete from users where id = $1", [userId]);
      if (del.rowCount === 0) {
        await db.query("rollback");
        return reply.code(404).send({ error: "user_not_found" });
      }
      await db.query("commit");
    } catch (e) {
      await db.query("rollback");
      throw e;
    }

    await audit(db, {
      action: "user.delete.platform",
      tenantId: targetTenantId,
      actorUserId: payload.sub,
      metadata: { targetUserId: userId, targetEmail }
    });

    return reply.send({ ok: true, action: "delete" });
  });
}
