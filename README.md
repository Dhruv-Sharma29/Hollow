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

## Build and run it yourself

You need a Mac with Apple Silicon, macOS 15 or later, Xcode, and about 15 minutes.
The repo has no Google credentials in it: every build uses a Google client you create.

### 1. Install rclone

```bash
brew install rclone
```

### 2. Create your own Google client

Google requires every app that touches Drive to have its own client. It's free.

1. Open [Google Cloud Console](https://console.cloud.google.com) and create a project, e.g. `Hollow`.
2. **APIs & Services → Library**: enable the **Google Drive API**.
3. **Google Auth Platform → Get started**: enter an app name and your email.
   For **Audience**, pick **External**. (Internal only works for Google Workspace accounts in your
   organisation; personal Gmail accounts get `Error 403: org_internal`.)
4. **Audience → Test users → Add users**: add the Gmail address you'll sign in with.
   While the app is in Testing, only listed test users can sign in; everyone else gets
   `Error 403: access_denied`.
5. **Data access → Add or remove scopes**: add only `https://www.googleapis.com/auth/drive.file`.
   Hollow sees just the files it creates, and this scope needs no security audit.
6. **Clients → Create client → Desktop app**, then **Download JSON**. Google shows a secret only
   once; if you lose it, use **Add secret** on the client page and download again.

Keep that JSON file out of the repo (`.gitignore` already ignores `client_secret*.json`).

### 3. Build the app

```bash
./scripts/build-app.sh ~/Downloads/client_secret_….json
```

The first line should read `using Google client …`. This writes `dist/Hollow.app` with rclone
and its license bundled inside. Your client goes into the app's `Info.plist`, never the repo.
Without `DEVELOPER_ID` the app is ad-hoc signed and runs only on the Mac that built it.

### 4. Run it

```bash
open dist/Hollow.app
```

Go through the tour and click **Connect Google Drive**. Google shows "Google hasn't verified this
app" while your client is in Testing: choose **Continue**, then **Allow**. Your Drive appears at
`~/Hollow`. Press **⌃⌥H** anywhere to search it.

### Develop and test

```bash
HOLLOW_CLIENT_ID=… HOLLOW_CLIENT_SECRET=… swift run
swift test
```

`swift run` reads the client from the environment. "Open at login" only works from the built app.

### Let anyone sign in

Testing allows up to 100 test users. To open sign-in to everyone, publish your consent screen:
you'll need a domain you own (verified in Google Search Console), a homepage and a privacy policy
on it, the **Branding** page filled in, then **Audience → Publish app**. A logo also goes through
Google's brand verification, which takes a few days.

## Before you can sell it

| Step | Needs |
|---|---|
| Developer ID signing + notarization (`xcrun notarytool`) | Apple Developer Program, $99/year |
| Google consent screen published for the public | A domain, homepage and privacy policy |
| Payments | A payment provider (e.g. Razorpay, Lemon Squeezy, Paddle) that delivers the download link after purchase |
| Distribution | A `.dmg`, a download page, and auto-updates (e.g. Sparkle) so paying users stay current |
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
