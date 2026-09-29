# Public content REST read

Approved scope: replace only the public catalog SDK read with URLSession GET of the same Firestore document. Preserve Firebase anonymous authentication, private note SDK sync, image integrity checks, atomic cache activation, UI and disabled business Web entry. No backend deployment, billing change or database migration.

## Implementation

- [x] Add request/decoder/retry regression tests to `Tests/PublicContentTests.swift`; confirm failure before implementation.
- [x] Add `PublicContentREST` to the existing `CoastWild/Core/PublicContentCache.swift` compilation unit. Fixed HTTPS endpoint, Firebase ID token in Authorization only, typed Firestore field decoding, existing release validation, one forced-token retry on 401.
- [x] Switch `CoastWild/App/PublicContentService.swift` to bounded URLSession streaming (2 MiB catalog limit), 20-second request / 60-second resource timeout, no redirects. Keep last valid cached/bundled content after errors.
- [x] Core tests: 256 executed, 1 skipped, zero failures.
- [x] Simulator build succeeded (`/tmp/coast-rest-build.log`). Installed signed simulator build without deleting app data. Proxyman captured CoastWild GET document request #45230: 200 OK, approximately 217 KB, visible Firestore JSON response. A subsequent launch logged `[PublicContent] REST catalog received and validated` (`/tmp/coast-rest-verified.log`). Existing cache remains active for the unchanged release.

Endpoint: `GET https://firestore.googleapis.com/v1/projects/coast-wild-20260915/databases/(default)/documents/publicCatalog/current`.
Response content is in `fields.catalogJSON.stringValue`; it is a JSON string inside the Firestore JSON response. No private notes or photo bytes are part of this document. Do not export Authorization headers in debugging reports.
