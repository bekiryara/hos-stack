import { defineConfig } from "vite";

// Keep the runtime architecture: browser talks to same-origin nginx, nginx proxies /api/* to api:3000.
// For local dev (vite dev server), we proxy /api to localhost:3000 for convenience.
export default defineConfig({
  server: {
    port: 5173,
    proxy: {
      "/api": {
        target: "http://localhost:3000",
        changeOrigin: true,
        secure: false,
        rewrite: (p) => p.replace(/^\/api/, "")
      }
    }
  }
});


