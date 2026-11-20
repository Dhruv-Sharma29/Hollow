# 03 — Build and release

## Building

```bash
./scripts/build-app.sh ~/Downloads/client_secret_XXXX.json
```

The script, in order:

1. Reads the Google client from the JSON (or from `HOLLOW_CLIENT_ID` and `HOLLOW_CLIENT_SECRET`).
   It rejects an ID that does not end in `.apps.googleusercontent.com` and a secret that is not
   `GOCSPX-` followed by 28 characters, without printing the secret.
2. Checks that rclone exists before touching `dist/`, so a bad input never leaves a half-built app.
3. Builds the Swift package in release mode for arm64.
4. Assembles `dist/Hollow.app`: the executable, rclone, both licences, the sign-in page, and the
   icon compiled from `branding/Hollow.icon` by `actool` (light, dark and tinted variants, plus a
   fallback `.icns` for macOS versions before 26).
5. Writes `Info.plist`, including the Google client, the `hollow://` URL scheme, `LSUIElement`, and
   the explanation shown in the network-volume permission prompt.
6. Signs rclone, then the app. Without `DEVELOPER_ID` it signs ad hoc.

| Variable | Purpose |
| --- | --- |
| `DEVELOPER_ID` | `Developer ID Application: …`; enables hardened runtime and timestamped signing |
| `RCLONE` | Path to a specific rclone binary; defaults to the one on `PATH` |
| `VERSION` | Bundle version; defaults to `0.1.0` |

## What an ad-hoc build can do

It runs on the Mac that built it. Gatekeeper rejects it elsewhere (`spctl --assess` reports
`rejected`, checked on 2026-11-11).

## What a release needs

| Step | Needs | Status |
| --- | --- | --- |
| Developer ID signing | Apple Developer Program, USD 99 per year | Not done |
| Notarization (`xcrun notarytool`) and stapling | Same | Not scripted yet |
| A published Google consent screen | Domain, homepage, privacy policy | Not done |
| Universal binary for Intel Macs | A universal rclone (`lipo` of the arm64 and amd64 builds) | Not done |
| Auto-updates | Sparkle | Not started |
| Distribution | A `.dmg` and a download page | Not started |

## Icons

`branding/Hollow.icon` is an Icon Composer document with light and dark art. Rebuild its images
from the two logo renders with:

```bash
./scripts/make-icon.sh
```

macOS 26 and later choose the dark icon from **System Settings → Appearance → Icon & widget style**,
not from dark mode alone.
