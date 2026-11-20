# 06 — Roadmap

## Milestones

| # | Milestone | Status (2026-11-20) |
| --- | --- | --- |
| M1 | Menu-bar app that mounts Drive through rclone | Done |
| M2 | First-run tour, search palette, settings, icons | Done |
| M3 | Own Google client, branded sign-in page, robust mount and unmount | Done |
| M4 | Native Drive client (`HollowDrive`): ranged reads, resumable uploads, token refresh | Done on `feature/drive-client`; not yet used by the app |
| M5 | FSKit extension: Hollow as a real disk with Eject | Spike compiles on `spike/fskit`; signing blocked |
| M6 | Release: Developer ID, notarization, `.dmg`, Sparkle, published consent screen | Not started |
| M7 | Optional encryption before upload, Dropbox | Not started |

## The FSKit path

Finder shows the current mount as the network server "localhost" with **Disconnect**, because it
is an NFS mount. An FSKit file-system extension is mounted as a local volume and gets **Eject** and
the volume's own name.

`spike/fskit` contains a minimal extension serving an empty read-only volume named "Hollow Drive".
It compiles. Signing it fails with:

> Personal development teams ... do not support the FSKit Module capability.

so M5 needs the paid Apple Developer Program, which M6 needs anyway. Apple's own path-URL FSKit
mount on the same Mac lists its source as a `file://` URL and its flags as `local, fskit`, which
indicates the mount command the spike will need **[verify]** once it can be signed.

## Order of work once enrolled

1. Sign and mount the spike; confirm Finder shows "Hollow Drive" with Eject.
2. Back the FSKit volume with `HollowDrive`: directory listing, attributes, ranged reads.
3. Writes and uploads, using the resumable sessions already tested.
4. Native sign-in (replace `rclone authorize`), tokens in the Keychain.
5. Remove rclone from the app bundle.
