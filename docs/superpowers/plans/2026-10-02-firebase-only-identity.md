# Firebase-only identity implementation

Work directly on user-authorized main; preserve prior permission edits. No push.

- [x] Test identity partition and resumable deletion state with `swift test`.
- [x] Replace business bootstrap with serialized Firebase anonymous authentication, retaining UID and legacy partition alias. Update startup and login.
- [x] Pause synchronization during deletion; persist cloud/auth/local completion and delete Firebase user before local cleanup. Restart offers retry without silently authenticating.
- [x] Set privacy/support URLs, retain local terms, update legal deletion copy and CI checks.
- [x] Remove unused business sources from shipping target using structured Xcode tooling.
- [x] Finish final Release artifact verification: unsigned archive succeeds; 20 CI/artifact checks pass; executable scan finds no retired host, package identifier or OAuth/config endpoint strings.

## Verification and limits

120 core tests pass. Four isolated simulator tests pass: consent gate, manual/automatic entry, deletion failure, deletion success. The unsigned simulator test harness uses a fixed test device ID; production retains Keychain identity. A disposable live Firebase anonymous user was created, looked up, and deleted successfully. No existing cloud user or note was deleted.

Real-user legacy note migration and reinstall recovery have not been end-to-end validated. Migration preserves the retained Firebase identity's current legacy partition; unavailable identities/unknown old partitions are not magically recovered or administratively erased.

Online privacy is still a draft with placeholders and an editorial paragraph mentioning video calling/camera/microphone. Support still contains outdated language/region claims. These external documents were not edited and remain publication blockers. The app does not censor remote document text. Local legal HTML has no such media descriptions.

Retired business sources, obsolete local-password UI, and obsolete business tests/fixtures are removed from main; their previous versions remain recoverable in Git history. Other branches and remote repositories are unchanged.
