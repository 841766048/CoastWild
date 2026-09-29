import assert from "node:assert/strict";
import { mkdtemp, mkdir, readFile, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";

import { buildBundle, validateCatalog } from "../src/content-builder.mjs";

const PNG = Buffer.from("89504e470d0a1a0a", "hex");

function catalog(overrides = {}) {
  return {
    home: { hero: { item: "story", photo: "public/assets/hero.png" }, tiles: [{ item: "story" }] },
    learn: {},
    categories: [{ key: "surf" }],
    items: [{ key: "story", category: "surf", photo: "public/assets/hero.png" }],
    lessons: [{ key: "lesson", category: "surf", heroImage: "lesson-photo", sourceLinks: [{ url: "https://example.com/source" }], webDetail: { blocks: [{ type: "image", image: "lesson-art" }] } }],
    gearTemplates: [{ key: "gear", category: "surf", items: [] }],
    ...overrides
  };
}

async function fixture(value = catalog()) {
  const root = await mkdtemp(path.join(os.tmpdir(), "firebase-content-test-"));
  const assetsRoot = path.join(root, "Assets.xcassets");
  for (const [name, filename] of [["hero", "hero.png"], ["lesson-photo", "lesson-photo.png"], ["lesson-art", "lesson-art.png"]]) {
    const set = path.join(assetsRoot, `${name}.imageset`);
    await mkdir(set, { recursive: true });
    await writeFile(path.join(set, filename), PNG);
    await writeFile(path.join(set, "Contents.json"), JSON.stringify({ images: [{ filename, idiom: "universal", scale: "1x" }], info: { author: "xcode", version: 1 } }));
  }
  const catalogPath = path.join(root, "catalog.json");
  await writeFile(catalogPath, JSON.stringify(value, null, 2));
  return { root, assetsRoot, catalogPath, publicRoot: path.join(root, "public"), internalRoot: path.join(root, "internal") };
}

test("builds the exact publicCatalog/current contract deterministically", async () => {
  const input = await fixture();
  const first = await buildBundle(input);
  const second = await buildBundle(input);
  assert.deepEqual(first.document, second.document);
  assert.match(first.document.version, /^[a-f0-9]{64}$/);
  assert.equal(first.document.schemaVersion, 1);
  assert.deepEqual(Object.keys(first.document).sort(), ["catalogJSON", "images", "schemaVersion", "version"]);
  assert.deepEqual(first.document.images.map(({ name }) => name), ["hero", "lesson-art", "lesson-photo"]);
  for (const image of first.document.images) {
    assert.equal(image.path, `content/${first.document.version}/images/${image.name}.png`);
    assert.match(image.sha256, /^[a-f0-9]{64}$/);
    assert.equal(image.bytes, PNG.length);
    assert.deepEqual(await readFile(path.join(input.publicRoot, image.path)), PNG);
  }
  assert.deepEqual(JSON.parse(first.document.catalogJSON), catalog());
  assert.deepEqual(JSON.parse(await readFile(path.join(input.internalRoot, "manifest.json"), "utf8")), first.document);
});

test("rejects path injection in image references", () => {
  assert.throws(() => validateCatalog(catalog({ home: { hero: { item: "story", photo: "public/assets/../secret.png" }, tiles: [] } })), /unsafe image reference/i);
});

test("rejects non-HTTPS source links", () => {
  const value = catalog();
  value.lessons[0].sourceLinks[0].url = "http://example.com/source";
  assert.throws(() => validateCatalog(value), /HTTPS/i);
});

test("rejects duplicate IDs", () => {
  const value = catalog();
  value.lessons.push({ ...value.lessons[0] });
  assert.throws(() => validateCatalog(value), /duplicate lessons key/i);
});

test("rejects missing associated IDs", () => {
  const value = catalog();
  value.items[0].category = "missing";
  assert.throws(() => validateCatalog(value), /unknown category/i);
});

test("rejects arbitrary top-level fields and sensitive keys", () => {
  assert.throws(() => validateCatalog(catalog({ extra: true })), /top-level field/i);
  const value = catalog();
  value.lessons[0].accessToken = "secret";
  assert.throws(() => validateCatalog(value), /sensitive field/i);
});

test("rejects missing image resources", async () => {
  const input = await fixture();
  input.catalogPath = path.join(input.root, "missing.json");
  const value = catalog();
  value.lessons[0].heroImage = "does-not-exist";
  await writeFile(input.catalogPath, JSON.stringify(value));
  await assert.rejects(() => buildBundle(input), /missing imageset/i);
});

test("rejects symlink escape from an imageset", async () => {
  const input = await fixture();
  const set = path.join(input.assetsRoot, "lesson-photo.imageset");
  await writeFile(path.join(input.root, "outside.png"), PNG);
  await import("node:fs/promises").then(({ symlink, unlink }) => unlink(path.join(set, "lesson-photo.png")).then(() => symlink(path.join(input.root, "outside.png"), path.join(set, "lesson-photo.png"))));
  await assert.rejects(() => buildBundle(input), /escapes imageset/i);
});

test("rejects image formats the iOS client cannot decode", async () => {
  const input = await fixture();
  const set = path.join(input.assetsRoot, "lesson-art.imageset");
  await writeFile(path.join(set, "Contents.json"), JSON.stringify({ images: [{ filename: "lesson-art.svg" }] }));
  await writeFile(path.join(set, "lesson-art.svg"), "<svg/>");
  await assert.rejects(() => buildBundle(input), /unsupported image format/i);
});

test("rejects an imageset directory symlink that escapes the asset catalog", async () => {
  const input = await fixture();
  const outside = path.join(input.root, "outside.imageset");
  await mkdir(outside);
  await writeFile(path.join(outside, "lesson-photo.png"), PNG);
  await writeFile(path.join(outside, "Contents.json"), JSON.stringify({ images: [{ filename: "lesson-photo.png" }] }));
  const set = path.join(input.assetsRoot, "lesson-photo.imageset");
  await import("node:fs/promises").then(({ rm, symlink }) => rm(set, { recursive: true }).then(() => symlink(outside, set)));
  await assert.rejects(() => buildBundle(input), /imageset escapes asset catalog/i);
});

test("rejects an imageset filename that does not preserve the catalog asset name", async () => {
  const input = await fixture();
  const set = path.join(input.assetsRoot, "lesson-photo.imageset");
  await writeFile(path.join(set, "renamed.png"), PNG);
  await writeFile(path.join(set, "Contents.json"), JSON.stringify({ images: [{ filename: "renamed.png" }] }));
  await assert.rejects(() => buildBundle(input), /must match asset name/i);
});

test("rejects unknown nextLessonID and client-invalid IDs", () => {
  const unknown = catalog();
  unknown.lessons[0].webDetail.nextLessonID = "missing";
  assert.throws(() => validateCatalog(unknown), /unknown nextLessonID/i);
  const invalid = catalog();
  invalid.lessons[0].key = "lesson.with.dot";
  assert.throws(() => validateCatalog(invalid), /invalid lessons key/i);
});
