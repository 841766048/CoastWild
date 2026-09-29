import assert from "node:assert/strict";
import test from "node:test";
import { getAdminAccessToken } from "../src/admin-auth.mjs";

test("uses an explicit OAuth access token without invoking credential helpers", async () => {
  const token = await getAdminAccessToken({ env: { GOOGLE_OAUTH_ACCESS_TOKEN: "memory-only" }, execute: async () => { throw new Error("must not run"); } });
  assert.equal(token, "memory-only");
});
