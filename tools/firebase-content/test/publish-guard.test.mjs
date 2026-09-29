import assert from "node:assert/strict";
import test from "node:test";
import { imageFetchOptions, validateProductionBaseURL } from "../src/publish-guard.mjs";

test("accepts only the exact production Hosting origin", () => {
  assert.equal(validateProductionBaseURL("https://coast-wild-20260915.web.app"), "https://coast-wild-20260915.web.app");
  for (const value of [
    "http://coast-wild-20260915.web.app",
    "https://coast-wild-20260915.web.app/extra",
    "https://coast-wild-20260915.web.app/?preview=1",
    "https://user@coast-wild-20260915.web.app",
    "https://coast-wild-20260915.web.app.evil.test"
  ]) assert.throws(() => validateProductionBaseURL(value), /exact production Hosting origin/i);
});

test("image verification rejects redirects and times out after 30 seconds", () => {
  const options = imageFetchOptions();
  assert.equal(options.redirect, "error");
  assert.ok(options.signal instanceof AbortSignal);
  assert.equal(options.timeoutMilliseconds, 30_000);
});
