# Hollow — Documentation

Hollow mounts Google Drive as a folder on a Mac and downloads only the byte ranges that apps read.
These docs are the design record: what it does, why it is built this way, how to set it up, what
has been checked, and what is still open. Read them in order the first time.

## Reading order

| # | Doc | What it settles |
|---|---|---|
| 00 | [Overview](00-overview.md) | Problem, scope, non-goals, and how success is checked |
| 01 | [Architecture](01-architecture.md) | Components, the sign-in and mount paths, and the decisions table |
| 02 | [Google setup](02-google-setup.md) | Creating your own OAuth client, test users, and the errors you will hit |
| 03 | [Build and release](03-build-and-release.md) | The build script, signing, notarization, and what a release needs |
| 04 | [Privacy and security](04-privacy-and-security.md) | What Hollow can see, where secrets live, threats and residual risks |
| 05 | [Testing](05-testing.md) | Unit tests, the live Drive check, manual checks, and what each proves |
| 06 | [Roadmap](06-roadmap.md) | The FSKit path, the native Drive client, and status per milestone |
| 07 | [Known issues](07-known-issues.md) | Limits of the current build and their workarounds |

## The one-paragraph version

Cloud-drive apps usually either sync whole files to disk, which fills small SSDs, or show
placeholders that download the entire file on open. Hollow instead presents Drive as a filesystem
whose reads are served by range: an app that reads 4 KB of a 48 GB video causes about 4 KB of
network traffic and cache. Today that filesystem is rclone's VFS layer served over NFS on loopback,
driven by a small SwiftUI app that handles sign-in, mounting, search and settings. The longer-term
design replaces rclone and NFS with Apple's FSKit and a native Drive client, which gives a real disk
in Finder with Eject. That client exists and is tested on `feature/drive-client`; the FSKit half is
blocked only on the paid Apple Developer Program.

## Conventions

- **MUST / SHOULD / MAY** mark requirements; MUST items are acceptance criteria.
- **[verify]** marks a claim not yet confirmed by a test or a run. Each one says what would confirm it.
- Every result names how it was obtained (a test, a live run, or a manual check) and on which machine.
- Dates are absolute (2026-11-20), never "today" or "last week".
