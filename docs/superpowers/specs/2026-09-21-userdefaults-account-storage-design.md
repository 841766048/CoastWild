# UserDefaults Account Storage Design

## Goal

Move the app's local account records and active login session from iOS Keychain storage to `UserDefaults`, while retaining the existing Keychain utility and preserving users who already signed in with an earlier build.

## Storage design

- `AccountVault` stores one encoded `VaultData` value in a dedicated `UserDefaults` key.
- Production and UI-test data use separate keys so automated tests cannot alter normal app accounts.
- Account passwords remain non-readable: the stored model contains only the existing random salt and PBKDF2-SHA256 digest. The app never stores plaintext passwords.
- Registration, login, logout, recovery, and account lookup keep their existing public behavior.

## Legacy migration

On initialization, `AccountVault` first reads `UserDefaults`. If no valid value exists, it checks the former Keychain service and account name. When legacy data exists, it decodes and writes it to `UserDefaults`, then removes only that legacy vault item after the new write succeeds. The Keychain helper/source remains in the project for other secure data and future server tokens.

Malformed `UserDefaults` data is treated as a storage error instead of silently overwriting account records. A missing value creates an empty vault.

## Testability

Storage access is separated behind small interfaces so tests can use isolated `UserDefaults` suites and an in-memory legacy store. Tests cover:

1. Registration persists an account and session in `UserDefaults`.
2. A new vault instance restores the active session.
3. Existing Keychain-shaped data migrates once without losing the session.
4. Successful migration removes only the old vault item.
5. A failed destination write leaves legacy data intact.
6. Production and testing storage keys stay isolated.

## Scope

This change only replaces persistence for the current local account system. It does not change screens, validation rules, password hashing, or introduce server authentication.
