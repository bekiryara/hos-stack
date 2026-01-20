// Backwards-compatible entrypoint: keep for existing scripts.
// Ensure telemetry (if enabled) is started before importing server/db modules.
const { initTelemetry } = await import("./otel.js");
await initTelemetry();

await import("./server.js");


