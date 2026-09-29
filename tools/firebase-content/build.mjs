#!/usr/bin/env node
import path from "node:path";
import { fileURLToPath } from "node:url";
import { buildBundle } from "./src/content-builder.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const project = path.resolve(here, "../..");
const catalogSource = process.argv[2];
if (!catalogSource) {
  throw new Error("Native V1 does not bundle a catalog. Pass the reviewed public catalog path: node build.mjs /absolute/path/catalog.json");
}
const result = await buildBundle({
  catalogPath: path.resolve(catalogSource),
  assetsRoot: path.join(project, "CoastWild/Resources/Assets.xcassets"),
  fallbackAssetsRoot: path.resolve(project, "../h5-preview/public/assets"),
  publicRoot: path.join(project, ".firebase-public"),
  internalRoot: path.join(project, ".firebase-content")
});
console.log(JSON.stringify({ version: result.document.version, ...result.stats }, null, 2));
