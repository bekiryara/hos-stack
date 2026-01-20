let sdk = null;
let started = false;

function isTruthy(v) {
  return String(v ?? "").toLowerCase() === "true" || String(v ?? "") === "1";
}

export async function initTelemetry() {
  if (started) return;
  started = true;

  // Keep tracing truly opt-in: only enable when explicitly requested.
  const enabled = isTruthy(process.env.OTEL_ENABLED);
  if (!enabled) return;

  // IMPORTANT: dynamic imports so prod builds can omit OTEL deps when OTEL_ENABLED=false.
  const [{ NodeSDK }, { getNodeAutoInstrumentations }, { OTLPTraceExporter }] = await Promise.all([
    import("@opentelemetry/sdk-node"),
    import("@opentelemetry/auto-instrumentations-node"),
    import("@opentelemetry/exporter-trace-otlp-http")
  ]);

  // Minimal defaults; customize via env:
  // - OTEL_SERVICE_NAME (defaults to hos-api)
  // - OTEL_EXPORTER_OTLP_ENDPOINT (e.g. http://localhost:4318/v1/traces)
  // - OTEL_EXPORTER_OTLP_HEADERS (if needed)
  process.env.OTEL_SERVICE_NAME ||= "hos-api";

  const endpoint = process.env.OTEL_EXPORTER_OTLP_ENDPOINT;
  const traceExporter = endpoint ? new OTLPTraceExporter({ url: endpoint }) : undefined;

  sdk = new NodeSDK({
    traceExporter,
    instrumentations: [getNodeAutoInstrumentations()]
  });

  await sdk.start();

  // Graceful shutdown
  const shutdown = async () => {
    await sdk?.shutdown();
  };

  process.once("SIGTERM", shutdown);
  process.once("SIGINT", shutdown);
}



