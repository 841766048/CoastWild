# Public content publisher report

## Result

- Firestore document contract: `publicCatalog/current` with exactly `schemaVersion`, `version`, `catalogJSON`, and `images`.
- Hosting output: `.firebase-public/content/<version>/images/`; prior content-addressed releases are not removed.
- Private build payload: `.firebase-content/manifest.json` (not hosted).
- Hosting site: `coast-wild-20260915`, no SPA rewrite, one-year immutable cache for `/content/**`.
- No deployment or Firestore write was performed.

## TDD evidence

RED was observed before implementation:

- Initial `npm test`: 8 failures because validation and bundle building were not implemented.
- Follow-up RED: unsupported client image formats were accepted and admin credential resolution was not implemented.

GREEN after minimal implementation:

```text
tests 15
pass 15
fail 0
```

Coverage includes deterministic contract output, traversal rejection, HTTPS-only sources, duplicate and client-invalid IDs, unknown category/home/next-lesson associations, unexpected top-level and sensitive fields, missing resources, file and whole-imageset symlink escape, asset/filename mismatch, unsupported image formats, and explicit in-memory OAuth token priority.

## Current public resources

- Version: `c47018c040b9c3eafe94a86946d032c2abdf7177baed16b3b40084416d76d4d7`
- Catalog JSON: 147,542 bytes (compact UTF-8)
- Images: 96
- Image bytes: 19,894,469
- Accepted image formats: JPEG, PNG, WebP

Two consecutive real builds produced the same version. Every listed file is sourced from the catalog's `photo`, `heroImage`, or `image` references and resolved through its named `.imageset` (with the explicitly scoped H5 public-assets fallback available).

## Authentication and release guard

The publish command verifies every remote image has status 200 and the expected SHA-256 before writing the current document. Admin authentication supports an environment access token, ADC, or an existing Firebase CLI login loaded from a caller-provided `NODE_PATH`; tokens stay in process memory and are not printed by the tool.

## Production publish guard follow-up

RED evidence: the focused guard run first failed 2/2 because production-origin validation and redirect/timeout fetch options were absent.

GREEN evidence: the complete suite now passes 15/15. `--base-url` accepts only the literal `https://coast-wild-20260915.web.app` origin (no alternate host, scheme, path, query, fragment, or credentials); image verification uses `redirect: "error"`; image reads and the Firestore PATCH each have a 30-second abort timeout. No deployment or Firestore write was performed during this follow-up.
