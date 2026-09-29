# Private note image synchronization

Approved design: best-effort same-device reinstall recovery with existing Keychain UUID, Firebase anonymous identity and business account partition. No additional login, no guaranteed recovery, no billing upgrade. Existing note IDs own image subcollections. Up to 12 JPEG backups per note, at most 204800 bytes each, encoded as Base64 strings. Base64 is not encryption.

## Data contract / rules analysis

Existing paths: `users/{uid}/devices/{device}/accounts/{accountHash}/notes/{note}`. Owner UID remains the access boundary. Notes schema 2 adds ordered `photoIDs` (0–12 safe filename stems). Schema 1 text documents remain readable/writable for compatibility. New `images/{imageID}` documents contain `base64`, `bytes`, `sha256`, `width`, `height`, `mimeType`, `schemaVersion`, `updatedAt`. No public or cross-UID access. Create/update require a parent note that references the image after the atomic batch. Base64 indexing disabled. No collections use privileged roles.

## Work and verification

- [x] Core tests first: payload bounds/path validation, old-note requeue migration, authoritative cloud image manifests, preservation of pending local changes.
- [x] ImageIO background compression strips metadata and bounds dimensions to 1600. Preserve local originals. Local imported JPEG filename stem is immutable image ID.
- [x] Atomic batch commits note + new images + removed images. Do not acknowledge outbox on failure. Download missing image files using ordered IDs and validate data before writing. Cleanup image children before deleting their parent or account.
- [x] Privacy consent version 4 gates all uploads, including old-photo migration. Update sync status and English/Chinese legal copy. Keep text-only old cloud documents compatible.
- [x] Firestore emulator tests: anonymous owner allowed; unauthenticated/other UID denied; malformed create/update, oversized payload, orphan image and unknown fields denied. Verify ordered restore, replacement and deletion batches.
- [x] Swift tests, signed simulator build and scoped UI tests. Deploy only Firestore rules/indexes after validation; no private production note deletion or test upload of user photos.

Identity/permissions caveat: photos are recoverable only when the same anonymous UID, Keychain device ID and business account partition are available. Deleting the app must not call signOut or delete the anonymous Firebase user. Existing Keychain identity implementation remains unchanged.

## Verification results (2026-09-24)

- Core tests: 260 executed, 1 skipped, 0 failures. Image codec roundtrip, metadata stripping, checksum/dimension rejection, migration, outbox and account isolation covered. Staging preflight/promotion regression test observed failing before implementation and passing after.
- Firestore emulator: 5 groups passed, including 12-image atomic batch, fresh same-UID client reads, rejection of replacement UID and unauthenticated clients, malformed create/update, removal and cascade batch behavior.
- Signed simulator build passed; privacy and native-login routing UI tests passed. Final incremental build rerun after staging change.
- Firebase project coast-wild-20260915: rules and base64 index exemption deployed successfully; no Storage service or billing change. No private production photo test upload or deletion performed.
- Read-only code review found a cleanup/download race; fixed using private temporary staging and synchronous promotion plus ledger merge on MainActor. Follow-up review found no remaining high/medium issue.
- NOT verified: physical uninstall/reinstall recovery and end-to-end production private-image network roundtrip. Recovery depends on retaining the same Firebase anonymous UID, Keychain UUID and business account partition. This is not guaranteed recovery or cross-device sync.
- Security rules are a tested prototype owner-only policy; review again before broad production release. Hash and JPEG validation run on the client; rules enforce field/type/size/parent ownership, not cryptographic image authenticity.
