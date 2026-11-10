# Hollow

A macOS menu-bar app that mounts your Google Drive at `~/Hollow`.
Files stay in your Drive. Opening one downloads only the parts an app actually reads,
so a 90 GB video plays without filling your disk.

It's a SwiftUI shell around [rclone](https://rclone.org) (MIT): `rclone nfsmount` with
`--vfs-cache-mode full`. NFS means no macFUSE and no kernel extension.

The only window is first-run setup (connect Google Drive, open at login).
Everything after that lives in the menu bar.

## Open source, paid app

The code is GPL-3.0 (see [LICENSE](LICENSE)). Anyone can build Hollow for free.
The paid version is the signed, notarized app that installs with one drag and updates itself:
you pay for the convenience, not for an unlock. There's no license check in the code, on purpose.
A license check in public code only stops honest people.

GPL-3.0 means anyone who ships a modified Hollow has to publish their changes under the same
license, so nobody can take this code and sell a closed-source copy of it.

## Develop

```bash
brew install rclone
HOLLOW_CLIENT_ID=... HOLLOW_CLIENT_SECRET=... swift run
swift test
```

## Build the app

```bash
HOLLOW_CLIENT_ID=... HOLLOW_CLIENT_SECRET=... ./scripts/build-app.sh
```

This writes `dist/Hollow.app` with rclone and its license bundled inside, so buyers don't need
Homebrew. The Google client is baked into `Info.plist` at build time and never committed.
Without `DEVELOPER_ID` the app is ad-hoc signed and only runs on the Mac that built it.

### Google client ID (required)

rclone's shared client ID is being retired in 2026, so use your own:

1. In Google Cloud Console, create a project and enable the **Google Drive API**.
2. Set up the OAuth consent screen. Add yourself as a test user while developing.
3. Create credentials of type **OAuth client ID → Desktop app**.

Hollow asks only for the `drive.file` scope: it sees files it created, never the rest of
your Drive. That scope is non-sensitive, so there's no security audit. Publishing the consent
screen for the public still needs Google's brand verification (domain, privacy policy, homepage).

## Before you can sell it

| Step | Needs |
|---|---|
| Developer ID signing + notarization (`xcrun notarytool`) | Apple Developer Program, $99/year |
| Google consent screen published for the public | A domain, homepage and privacy policy |
| Payments | A payment provider (e.g. Razorpay, Lemon Squeezy, Paddle) that delivers the download link after purchase |
| Distribution | A `.dmg`, a download page, and auto-updates (e.g. Sparkle) so paying users stay current |
| App icon | `AppIcon.icns` |
| Intel Macs | A universal rclone (`lipo` the arm64 and amd64 builds from rclone.org) |

## Where things live

| What | Path |
|---|---|
| Mount | `~/Hollow` |
| rclone config + token | `~/Library/Application Support/Hollow/rclone.conf` (separate from your own rclone config) |
| Read cache (10 GB cap) | `~/Library/Application Support/Hollow/cache` |
| Log | `~/Library/Application Support/Hollow/rclone.log` |

## Known gaps

- Killing the app (rather than choosing Quit) leaves rclone running, so the mount stays up. The next launch clears it.
- Sign Out removes your Google token but keeps the cache, which may hold writes rclone hasn't uploaded yet.
- Google sign-in hasn't been tested end to end.
- Apple Silicon only.

## Roadmap

1. Auto-updates (Sparkle)
2. Optional end-to-end encryption (rclone `crypt` remote)
3. Dropbox
4. Drop files on the menu-bar icon to upload
5. File Provider extension (Finder sidebar, native sync badges)
