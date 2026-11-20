# 05 — Testing

## Unit tests on `main`

```bash
swift test
```

Seven Swift Testing tests in `Tests/HollowTests/RcloneTests.swift`:

| Test | What it proves |
| --- | --- |
| `mountStreamsWithSparseCache` | The mount uses `--vfs-cache-mode full` and Hollow's own config file |
| `authorizeKeepsTheNarrowScope` | The authorize argument decodes to `drive.file`, with or without a client |
| `authorizeShowsHollowsPage` | `--template` is passed when the sign-in page exists |
| `tokenIsReadFromAuthorizeOutput` | The token is found between rclone's markers, and nothing else is accepted |
| `savingTheTokenUsesOwnClientWhenGiven` | Saving uses the builder's client, non-interactively |
| `signedInNeedsAToken` | A config without a token does not count as signed in |
| `mountTableLookup` | The mount-table check finds `/` and rejects an unmounted folder |

## Native client tests on `feature/drive-client`

Sixteen tests run against a fake Google server built on `URLProtocol`, so they need no network:

- Folder listing across pages, name lookup with quotes escaped, ranged reads (including Drive
  ignoring the range), moving to the bin.
- One shared token refresh on 401, revoked sign-in reported as signed out, retries stopping after
  four attempts on 503 (a regression test for an unbounded-retry bug found during development).
- Resumable uploads: chunked, server keeping less than was sent, a failed chunk, stopping and
  resuming from a saved session, empty files.

## Live check

```bash
swift run hollow-drive-check ~/Downloads/client_secret_XXXX.json
```

Uses the sign-in Hollow already saved. Creates a test folder, uploads 3 MiB with a deliberate
interruption after the first chunk, resumes, reads three 4 KiB slices and compares them byte for
byte, renames, then moves the file and folder to Drive's bin. All steps passed on 2026-11-12.

## Manual checks done on 2026-11-10 to 2026-11-14

| Check | Result |
| --- | --- |
| Range read through the mount (1 MB of 50 MB) | About 2 MB cached |
| Unmount while rclone serves | Detaches in under a second |
| Launch with a stale mount present | Clears it off the main thread, or reports it after 10 s |
| Window comes forward from the menu bar | Confirmed by the user |
| Window comes forward on launch | Window is topmost even when another app stays active |
| Sign-in page through real rclone | Correct page and error text |

## Not covered

- UI automation. The views are reviewed through rendered screenshots, not driven by tests.
- The palette's filtering and `Drive`'s state transitions, which live in views and the `Drive`
  class. Moving them into testable types is planned.
