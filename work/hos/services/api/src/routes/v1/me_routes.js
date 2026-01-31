import { requireAuth } from "./request_auth.js";

/**
 * Register v1 /me routes (profile, orders, rentals, reservations, memberships). No behavior change — split from auth_me_tenants.js.
 */
export async function registerV1MeRoutes(app, { db }) {
  app.get("/me", async (req, reply) => {
    const payload = requireAuth(req, reply);
    if (!payload) return;

    const userId = payload.sub;

    const user = await db.query(
      "select id, email, display_name, created_at from users where id = $1 limit 1",
      [userId]
    );

    if (user.rowCount === 0) {
      return reply.code(404).send({ error: "user_not_found" });
    }

    const userRow = user.rows[0];

    const membershipsCount = await db.query(
      "select count(*)::int as c from memberships where user_id = $1 and status = 'active'",
      [userId]
    );
    const count = membershipsCount.rows?.[0]?.c ?? 0;

    return reply.send({
      user_id: userRow.id,
      email: userRow.email,
      display_name: userRow.display_name || userRow.email.split("@")[0],
      memberships_count: count
    });
  });

  app.get("/me/orders", async (req, reply) => {
    const payload = requireAuth(req, reply);
    if (!payload) return;

    const userId = payload.sub;
    const pazarBaseUrl = process.env.PAZAR_API_BASE_URL || "http://pazar-app:80";

    try {
      const response = await fetch(`${pazarBaseUrl}/api/v1/orders?buyer_user_id=${userId}`, {
        method: "GET",
        headers: {
          "Authorization": req.headers.authorization || "",
          "Content-Type": "application/json"
        }
      });

      if (!response.ok) {
        const errorText = await response.text().catch(() => "");
        return reply.code(response.status).send({ error: "pazar_api_error", message: errorText });
      }

      const data = await response.json();
      return reply.send(data);
    } catch (e) {
      return reply.code(502).send({ error: "pazar_api_unavailable", message: String(e.message) });
    }
  });

  app.get("/me/orders/:id", async (req, reply) => {
    const payload = requireAuth(req, reply);
    if (!payload) return;

    const userId = payload.sub;
    const id = req.params.id;
    const pazarBaseUrl = process.env.PAZAR_API_BASE_URL || "http://pazar-app:80";

    try {
      const response = await fetch(`${pazarBaseUrl}/api/v1/orders/${id}?buyer_user_id=${userId}`, {
        method: "GET",
        headers: {
          "Authorization": req.headers.authorization || "",
          "Content-Type": "application/json"
        }
      });

      if (!response.ok) {
        const errorText = await response.text().catch(() => "");
        return reply.code(response.status).send({ error: "pazar_api_error", message: errorText });
      }

      const data = await response.json();
      return reply.send(data);
    } catch (e) {
      return reply.code(502).send({ error: "pazar_api_unavailable", message: String(e.message) });
    }
  });

  app.get("/me/rentals", async (req, reply) => {
    const payload = requireAuth(req, reply);
    if (!payload) return;

    const userId = payload.sub;
    const pazarBaseUrl = process.env.PAZAR_API_BASE_URL || "http://pazar-app:80";

    try {
      const response = await fetch(`${pazarBaseUrl}/api/v1/rentals?renter_user_id=${userId}`, {
        method: "GET",
        headers: {
          "Authorization": req.headers.authorization || "",
          "Content-Type": "application/json"
        }
      });

      if (!response.ok) {
        const errorText = await response.text().catch(() => "");
        return reply.code(response.status).send({ error: "pazar_api_error", message: errorText });
      }

      const data = await response.json();
      return reply.send(data);
    } catch (e) {
      return reply.code(502).send({ error: "pazar_api_unavailable", message: String(e.message) });
    }
  });

  app.get("/me/rentals/:id", async (req, reply) => {
    const payload = requireAuth(req, reply);
    if (!payload) return;

    const userId = payload.sub;
    const id = req.params.id;
    const pazarBaseUrl = process.env.PAZAR_API_BASE_URL || "http://pazar-app:80";

    try {
      const response = await fetch(`${pazarBaseUrl}/api/v1/rentals/${id}?renter_user_id=${userId}`, {
        method: "GET",
        headers: {
          "Authorization": req.headers.authorization || "",
          "Content-Type": "application/json"
        }
      });

      if (!response.ok) {
        const errorText = await response.text().catch(() => "");
        return reply.code(response.status).send({ error: "pazar_api_error", message: errorText });
      }

      const data = await response.json();
      return reply.send(data);
    } catch (e) {
      return reply.code(502).send({ error: "pazar_api_unavailable", message: String(e.message) });
    }
  });

  app.get("/me/reservations", async (req, reply) => {
    const payload = requireAuth(req, reply);
    if (!payload) return;

    const userId = payload.sub;
    const pazarBaseUrl = process.env.PAZAR_API_BASE_URL || "http://pazar-app:80";

    try {
      const response = await fetch(`${pazarBaseUrl}/api/v1/reservations?requester_user_id=${userId}`, {
        method: "GET",
        headers: {
          "Authorization": req.headers.authorization || "",
          "Content-Type": "application/json"
        }
      });

      if (!response.ok) {
        const errorText = await response.text().catch(() => "");
        return reply.code(response.status).send({ error: "pazar_api_error", message: errorText });
      }

      const data = await response.json();
      return reply.send(data);
    } catch (e) {
      return reply.code(502).send({ error: "pazar_api_unavailable", message: String(e.message) });
    }
  });

  app.get("/me/reservations/:id", async (req, reply) => {
    const payload = requireAuth(req, reply);
    if (!payload) return;

    const userId = payload.sub;
    const id = req.params.id;
    const pazarBaseUrl = process.env.PAZAR_API_BASE_URL || "http://pazar-app:80";

    try {
      const response = await fetch(`${pazarBaseUrl}/api/v1/reservations/${id}?requester_user_id=${userId}`, {
        method: "GET",
        headers: {
          "Authorization": req.headers.authorization || "",
          "Content-Type": "application/json"
        }
      });

      if (!response.ok) {
        const errorText = await response.text().catch(() => "");
        return reply.code(response.status).send({ error: "pazar_api_error", message: errorText });
      }

      const data = await response.json();
      return reply.send(data);
    } catch (e) {
      return reply.code(502).send({ error: "pazar_api_unavailable", message: String(e.message) });
    }
  });

  app.get("/me/memberships", async (req, reply) => {
    const payload = requireAuth(req, reply);
    if (!payload) return;

    const userId = payload.sub;

    const memberships = await db.query(
      "select m.tenant_id, m.role, m.status, m.created_at, t.slug as tenant_slug, t.display_name as tenant_name from memberships m inner join tenants t on m.tenant_id = t.id where m.user_id = $1 and m.status = 'active' order by m.created_at asc",
      [userId]
    );

    return reply.send({
      items: memberships.rows.map((row) => ({
        tenant_id: row.tenant_id,
        tenant_slug: row.tenant_slug,
        tenant_name: row.tenant_name || row.tenant_slug,
        role: row.role ?? "member",
        status: row.status,
        created_at: row.created_at
      }))
    });
  });
}
