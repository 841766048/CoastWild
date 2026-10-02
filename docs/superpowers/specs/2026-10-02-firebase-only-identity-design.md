# Firebase-only identity for main

## Scope

Only `main` changes. Preserve the existing uncommitted permission-removal work; do not merge or push other branches. Replace the first-version business authentication/configuration dependency with Firebase anonymous authentication. Keep the current Firebase project, official bundle identifier and signing settings. Do not add email/password or social sign-in screens.

## Authentication and launch

After privacy consent, reuse a valid Firebase current user or perform anonymous sign-in. Serialize concurrent sign-in requests. A failed request presents a retry state, never fabricated success. Retained sessions enter the native interface without briefly showing the login screen. Keep the Keychain device UUID, but never use that UUID as an authentication credential. Recovery on the same device is best-effort, not a guarantee.

Firebase identity becomes the authentication authority. A legacy business account identifier may be retained solely as a data-partition alias; it is not an authenticated backend identity. Remove old business tokens from active use. Ordinary app locking/returning to the welcome screen must not sign out and abandon an anonymous identity without informing the user; distinguish local session presentation from permanent account deletion.

## Existing notes and photos

The existing path is `users/{firebaseUID}/devices/{keychainUUID}/accounts/{accountHash}/notes/{noteID}/images/{photoID}`. Retain access to the current account partition using a persisted migration alias tied to the verified Firebase UID. Preserve local ledger files and photo paths until migration succeeds. Never overwrite a populated destination, merge data across Firebase users, or rely on a UUID to bypass Firestore rules.

For a fresh install with no legacy alias, use the authenticated Firebase UID as the account key. Existing cloud-only legacy partitions that cannot be discovered under current rules must not be claimed as automatically recovered. Test this boundary explicitly and report limitations instead of silently creating a success state. No cross-user administrative migration is authorized.

## Account deletion

Retain the Delete Account entry point and confirmation. Stop and await in-flight note sync; prevent concurrent login, uploads and account switching during deletion. Delete owned cloud note/image data for all partitions the app associates with this identity before deleting the Firebase Auth user. Do not assume deleting a Firestore parent deletes its subcollections.

Persist deletion progress so a restart or network failure can retry without repopulating deleted data. After cloud deletion succeeds, call Firebase user deletion; clear local ledger/photos/session aliases only after identity deletion succeeds. A local cleanup failure after identity deletion retries local cleanup, not anonymous sign-in. Surface authentication or network failures honestly. Remove the simulated business deletion flow. Do not auto-create a replacement anonymous account as part of deletion completion.

## Remove the old service

Remove the old test-host configuration, business OAuth/bootstrap/config requests and test package identity from the main app's active code/resources. Remove now-unused business integration components and their project references when no consumers remain. Update tests and CI guards that currently require development mode and the old backend. Historical design records may remain explicitly historical; they must not feed a build or runtime configuration. Do not replace the old service with an invented production endpoint.

## Legal and support links

- Support: https://docs.google.com/document/d/10b0pTTc6ho_taVkYgpNDqt0qWmTvsllIY0iKA-5IrJU/edit
- Privacy: https://docs.google.com/document/d/1BONvGvpiAzvxY9HDlxbfqMkpn940XtMi6Fvn6d5VG6M/edit
- Terms: continue using the bundled local terms; update obsolete simulated business-account deletion statements to the implemented Firebase-based behavior.

Do not treat Support as Terms. Remove remote config overrides for these destinations. Keep an accurate bundled privacy fallback and no audio/video/calling claims. Never filter a remote legal page to conceal statements. The supplied documents still contain placeholders and outdated statements: configuring their URLs is not publication approval. Do not invent legal operator/contact details or edit external documents without a separate content-edit request. Verify public access and clearly report remaining publication blockers.

## Verification and acceptance

Use failing tests before implementation for launch/consent, identity reuse and errors, concurrent sign-in, migration alias persistence and user isolation, deletion ordering/failure/restart, and legal destination selection. Verify the existing note/photo sync tests and CI tests still pass. Add a build-source check rejecting the retired test host and business package identity in shipping files. Preserve the camera/microphone permission and HTML content guards.

Build the Release archive and inspect the actual app configuration. Exercise fresh launch, retained session, existing local notes/photos, cloud restore, offline errors and deletion on disposable test data only. Do not delete the user's real cloud account or notes for validation. If cloud/emulator validation is unavailable, state exactly which checks remain unverified. A passing build is not a guarantee of App Review acceptance. No remote push or App Store submission is included.
