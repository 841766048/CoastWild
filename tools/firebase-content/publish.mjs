#!/usr/bin/env node
import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { getAdminAccessToken } from "./src/admin-auth.mjs";
import { imageFetchOptions, validateProductionBaseURL } from "./src/publish-guard.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const project = path.resolve(here, "../..");
const manifest = JSON.parse(await readFile(path.join(project, ".firebase-content/manifest.json"), "utf8"));
const baseFlag = process.argv.indexOf("--base-url");
const baseURL = validateProductionBaseURL(baseFlag >= 0 ? process.argv[baseFlag + 1] : "https://coast-wild-20260915.web.app");

for (const image of manifest.images) {
  const response = await fetch(new URL(image.path, `${baseURL}/`), imageFetchOptions());
  if (response.status !== 200) throw new Error(`remote image returned ${response.status}: ${image.path}`);
  const digest = createHash("sha256").update(Buffer.from(await response.arrayBuffer())).digest("hex");
  if (digest !== image.sha256) throw new Error(`remote image hash mismatch: ${image.path}`);
}

const token = await getAdminAccessToken({ projectRoot: project });
const stringValue = (value) => ({ stringValue: value });
const fields = {
  schemaVersion: { integerValue: String(manifest.schemaVersion) },
  version: stringValue(manifest.version),
  catalogJSON: stringValue(manifest.catalogJSON),
  images: { arrayValue: { values: manifest.images.map((image) => ({ mapValue: { fields: {
    name: stringValue(image.name), path: stringValue(image.path), sha256: stringValue(image.sha256), bytes: { integerValue: String(image.bytes) }
  } } })) } }
};
const endpoint = "https://firestore.googleapis.com/v1/projects/coast-wild-20260915/databases/(default)/documents/publicCatalog/current";
const response = await fetch(endpoint, { method: "PATCH", headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" }, body: JSON.stringify({ fields }), signal: AbortSignal.timeout(30_000) });
if (!response.ok) throw new Error(`Firestore publish failed (${response.status}): ${await response.text()}`);
console.log(`Published publicCatalog/current at version ${manifest.version}`);
