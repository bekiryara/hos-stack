import { registerV1CoreWorldContractRoutes } from "./core_world_contract.js";
import { registerV1AuthRoutes } from "./auth_routes.js";
import { registerV1MeRoutes } from "./me_routes.js";
import { registerV1TenantRoutes } from "./tenant_routes.js";
import { registerV1AdminPermitRoutes } from "./admin_permits.js";
import { registerV1AddressRoutes } from "./address_routes.js";

/**
 * Register all v1 API routes. Legacy mode adds Deprecation/Sunset headers (no behavior change).
 */
export async function registerV1Routes(app, { db, legacy = false }) {
  if (legacy) {
    app.addHook("onSend", async (_req, reply, payload) => {
      reply.header("Deprecation", "true");
      reply.header("Sunset", "TBD");
      return payload;
    });
  }

  await registerV1CoreWorldContractRoutes(app, { db, legacy });
  await registerV1AuthRoutes(app, { db });
  await registerV1MeRoutes(app, { db });
  await registerV1TenantRoutes(app, { db });
  await registerV1AddressRoutes(app, { db });
  await registerV1AdminPermitRoutes(app, { db, legacy });
}
