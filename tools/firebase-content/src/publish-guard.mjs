const PRODUCTION_ORIGIN = "https://coast-wild-20260915.web.app";
const TIMEOUT_MILLISECONDS = 30_000;

export function validateProductionBaseURL(value) {
  if (value !== PRODUCTION_ORIGIN) throw new Error(`--base-url must be the exact production Hosting origin: ${PRODUCTION_ORIGIN}`);
  const parsed = new URL(value);
  if (parsed.origin !== value || parsed.pathname !== "/" || parsed.search || parsed.hash || parsed.username || parsed.password) {
    throw new Error(`--base-url must be the exact production Hosting origin: ${PRODUCTION_ORIGIN}`);
  }
  return value;
}

export function imageFetchOptions() {
  return { redirect: "error", signal: AbortSignal.timeout(TIMEOUT_MILLISECONDS), timeoutMilliseconds: TIMEOUT_MILLISECONDS };
}
