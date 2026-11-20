# 04 — Privacy and security

## What Hollow can access

- **Google:** only files under the `drive.file` scope, which covers files the app created. It
  cannot list, read or change the rest of the user's Drive.
- **The Mac:** `~/Hollow`, its own folder in Application Support, and the files a user explicitly
  adds through **Add files…**. The first access to the mount triggers macOS's network-volume
  permission prompt, whose text explains why.

## Where secrets live

| Secret | Location | Notes |
| --- | --- | --- |
| Google client ID and secret | The built app's `Info.plist` | Never in the repository; `client_secret*.json` is git-ignored. Google treats installed-app secrets as non-confidential, but they are still kept out of version control |
| Access and refresh tokens | `~/Library/Application Support/Hollow/rclone.conf` | Plain text, user-readable only by default. Moving them to the Keychain is planned for the FSKit version |

A secret scan of every branch's history (client secrets and client IDs) found none on 2026-11-12.

## Threats considered

| Threat | Mitigation |
| --- | --- |
| A stale sign-in process from an earlier run receives the OAuth redirect | Hollow kills sign-in processes started by its own rclone binary before starting a new one, and ends its sign-in on quit |
| An attacker on the same Mac reads the OAuth redirect | rclone listens on 127.0.0.1 only; the redirect carries a one-time code. A local process running as the same user can still interfere **[verify]** whether rclone uses PKCE |
| A user commits their client JSON | Git ignore rule; the README and build output tell builders to pass the file, not copy it |
| Placeholder credentials baked into a release | The build script rejects malformed IDs and secrets |
| Data loss on sign-out | The cache, which may hold unsent writes, is kept |
| Accidental deletion | The native client moves files to Drive's bin instead of deleting them |

## Residual risks

- Tokens are stored in a plain file until the Keychain migration.
- The NFS server listens on loopback; any process on the Mac running as the same user can talk to
  it. This is inherent to the NFS approach and goes away with FSKit.
- rclone is a dependency with its own release cadence; Hollow ships whatever version was on the
  build machine (v1.76.0 for the builds described here).
