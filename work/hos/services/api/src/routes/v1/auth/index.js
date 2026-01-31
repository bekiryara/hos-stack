// WP-NEXT: split from auth_routes.js (NO BEHAVIOR CHANGE)
import { registerRegister } from "./register.js";
import { registerLogin } from "./login.js";
import { registerRefresh } from "./refresh.js";
import { registerLogout } from "./logout.js";
import { registerGoogleOAuth } from "./google_oauth.js";

/**
 * Register v1 auth routes (register, login, refresh, logout, Google OAuth). No behavior change — split from auth_routes.js.
 */
export async function registerV1AuthRoutes(app, { db }) {
  registerRegister(app, { db });
  registerLogin(app, { db });
  registerRefresh(app, { db });
  registerLogout(app, { db });
  registerGoogleOAuth(app, { db });
}
