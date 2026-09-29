import { createHash } from "node:crypto";
import { copyFile, mkdir, readFile, realpath, stat, writeFile } from "node:fs/promises";
import path from "node:path";

const TOP_LEVEL_FIELDS = ["home", "learn", "categories", "items", "lessons", "gearTemplates"];
const IMAGE_FIELDS = new Set(["photo", "heroImage", "image"]);
const SENSITIVE_FIELD = /(?:access|auth|refresh|id)?token|credential|password|secret|user(?:id|data)?|journal|note/i;
const SAFE_ASSET = /^[A-Za-z0-9][A-Za-z0-9._-]*$/;
const SAFE_NAME = /^[A-Za-z0-9][A-Za-z0-9_-]{0,99}$/;
const MAX_CATALOG_BYTES = 700_000;
const MAX_IMAGE_BYTES = 8 * 1024 * 1024;
const MAX_TOTAL_IMAGE_BYTES = 60 * 1024 * 1024;
const MAX_IMAGES = 128;

function requireObject(value, label) {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error(`${label} must be an object`);
}

function keysFor(value, label) {
  if (!Array.isArray(value)) throw new Error(`${label} must be an array`);
  const result = new Set();
  for (const entry of value) {
    requireObject(entry, `${label} entry`);
    if (typeof entry.key !== "string" || !SAFE_NAME.test(entry.key)) throw new Error(`invalid ${label} key: ${entry.key}`);
    if (result.has(entry.key)) throw new Error(`duplicate ${label} key: ${entry.key}`);
    result.add(entry.key);
  }
  return result;
}

function walk(value, visitor, location = "catalog") {
  if (Array.isArray(value)) return value.forEach((item, index) => walk(item, visitor, `${location}[${index}]`));
  if (!value || typeof value !== "object") return;
  for (const [key, child] of Object.entries(value)) {
    visitor(key, child, `${location}.${key}`);
    walk(child, visitor, `${location}.${key}`);
  }
}

function normalizeImageReference(reference) {
  if (typeof reference !== "string") throw new Error("image reference must be a string");
  let asset = reference;
  if (reference.startsWith("public/assets/")) asset = path.posix.basename(reference, path.posix.extname(reference));
  if (!SAFE_NAME.test(asset) || reference.includes("\\") || reference.includes("..") || reference.startsWith("/") || (reference.includes("/") && !reference.startsWith("public/assets/"))) throw new Error(`unsafe image reference: ${reference}`);
  if (reference.startsWith("public/assets/") && reference !== `public/assets/${path.posix.basename(reference)}`) throw new Error(`unsafe image reference: ${reference}`);
  return asset;
}

export function validateCatalog(catalog) {
  requireObject(catalog, "catalog");
  const actual = Object.keys(catalog);
  for (const field of TOP_LEVEL_FIELDS) if (!actual.includes(field)) throw new Error(`missing top-level field: ${field}`);
  for (const field of actual) if (!TOP_LEVEL_FIELDS.includes(field)) throw new Error(`unexpected top-level field: ${field}`);
  const categories = keysFor(catalog.categories, "categories");
  const items = keysFor(catalog.items, "items");
  const lessons = keysFor(catalog.lessons, "lessons");
  keysFor(catalog.gearTemplates, "gearTemplates");
  for (const [label, list] of [["items", catalog.items], ["lessons", catalog.lessons], ["gearTemplates", catalog.gearTemplates]]) {
    for (const entry of list) if (!categories.has(entry.category)) throw new Error(`${label}.${entry.key} references unknown category: ${entry.category}`);
  }
  const homeItems = [catalog.home?.hero?.item, ...(catalog.home?.tiles ?? []).map((tile) => tile?.item)].filter(Boolean);
  for (const key of homeItems) if (!items.has(key)) throw new Error(`home references unknown item: ${key}`);
  const imageReferences = new Set();
  walk(catalog, (key, value, location) => {
    if (SENSITIVE_FIELD.test(key)) throw new Error(`sensitive field is not publishable: ${location}`);
    if (key === "url") {
      if (typeof value !== "string" || !value.startsWith("https://")) throw new Error(`source link must use HTTPS: ${location}`);
      try { new URL(value); } catch { throw new Error(`invalid HTTPS source link: ${location}`); }
    }
    if (IMAGE_FIELDS.has(key)) imageReferences.add(normalizeImageReference(value));
    if (key === "nextLessonID" && (typeof value !== "string" || !lessons.has(value))) throw new Error(`unknown nextLessonID: ${value}`);
  });
  return [...imageReferences].sort();
}

async function resolveImage(assetName, assetsRoot, fallbackAssetsRoot) {
  const setRoot = path.join(assetsRoot, `${assetName}.imageset`);
  try {
    const contents = JSON.parse(await readFile(path.join(setRoot, "Contents.json"), "utf8"));
    const filenames = [...new Set((contents.images ?? []).map((image) => image.filename).filter(Boolean))];
    if (filenames.length !== 1 || !SAFE_ASSET.test(filenames[0])) throw new Error(`imageset ${assetName} must contain exactly one safe filename`);
    const source = path.join(setRoot, filenames[0]);
    const [realAssets, realSet, realSource] = await Promise.all([realpath(assetsRoot), realpath(setRoot), realpath(source)]);
    if (path.dirname(realSet) !== realAssets) throw new Error(`imageset escapes asset catalog: ${assetName}`);
    if (path.dirname(realSource) !== realSet) throw new Error(`image escapes imageset: ${assetName}`);
    if (path.basename(filenames[0], path.extname(filenames[0])) !== assetName) throw new Error(`imageset filename must match asset name: ${assetName}`);
    return { source: realSource, filename: filenames[0] };
  } catch (error) {
    if (String(error.message).includes("escapes imageset") || String(error.message).includes("escapes asset catalog") || String(error.message).includes("exactly one") || String(error.message).includes("must match asset name")) throw error;
    if (fallbackAssetsRoot) {
      for (const extension of [".webp", ".png", ".jpg", ".jpeg", ".svg"]) {
        try {
          const source = path.join(fallbackAssetsRoot, `${assetName}${extension}`);
          const [realRoot, realSource] = await Promise.all([realpath(fallbackAssetsRoot), realpath(source)]);
          if (path.dirname(realSource) !== realRoot) throw new Error(`image escapes fallback assets: ${assetName}`);
          return { source: realSource, filename: path.basename(realSource) };
        } catch (fallbackError) { if (String(fallbackError.message).includes("escapes fallback")) throw fallbackError; }
      }
    }
    throw new Error(`missing imageset for referenced asset: ${assetName}`);
  }
}

const sha256 = (value) => createHash("sha256").update(value).digest("hex");

export async function buildBundle({ catalogPath, assetsRoot, fallbackAssetsRoot, publicRoot, internalRoot }) {
  const catalog = JSON.parse(await readFile(catalogPath, "utf8"));
  const references = validateCatalog(catalog);
  if (references.length > MAX_IMAGES) throw new Error(`image count exceeds ${MAX_IMAGES}`);
  const catalogJSON = JSON.stringify(catalog);
  if (Buffer.byteLength(catalogJSON) >= MAX_CATALOG_BYTES) throw new Error(`catalogJSON must be smaller than ${MAX_CATALOG_BYTES} bytes`);
  const sources = [];
  const names = new Set();
  let totalBytes = 0;
  for (const reference of references) {
    const resolved = await resolveImage(reference, assetsRoot, fallbackAssetsRoot);
    const name = reference;
    const extension = path.extname(resolved.filename).toLowerCase();
    if (![".png", ".jpg", ".jpeg", ".webp"].includes(extension)) throw new Error(`unsupported image format: ${resolved.filename}`);
    if (!SAFE_ASSET.test(name)) throw new Error(`unsafe output image name: ${name}`);
    if (names.has(name)) throw new Error(`duplicate output image name: ${name}`);
    names.add(name);
    const info = await stat(resolved.source);
    if (!info.isFile() || info.size > MAX_IMAGE_BYTES) throw new Error(`image exceeds 8 MiB: ${name}`);
    totalBytes += info.size;
    if (totalBytes > MAX_TOTAL_IMAGE_BYTES) throw new Error("total images exceed 60 MiB");
    sources.push({ ...resolved, name, extension, sha256: sha256(await readFile(resolved.source)), bytes: info.size });
  }
  sources.sort((a, b) => a.name.localeCompare(b.name));
  const version = sha256(JSON.stringify({ catalogJSON, images: sources.map(({ name, extension, sha256, bytes }) => ({ name, extension, sha256, bytes })) }));
  const images = sources.map(({ name, extension, sha256, bytes }) => ({ name, path: `content/${version}/images/${name}${extension}`, sha256, bytes }));
  const document = { schemaVersion: 1, version, catalogJSON, images };
  const releaseRoot = path.join(publicRoot, "content", version, "images");
  await mkdir(releaseRoot, { recursive: true });
  await Promise.all(sources.map((source, index) => copyFile(source.source, path.join(publicRoot, images[index].path))));
  await mkdir(internalRoot, { recursive: true });
  await writeFile(path.join(internalRoot, "manifest.json"), `${JSON.stringify(document, null, 2)}\n`);
  return { document, stats: { catalogBytes: Buffer.byteLength(catalogJSON), imageCount: images.length, imageBytes: totalBytes } };
}
