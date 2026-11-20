# 00 — Overview

## Problem

A MacBook with a 256 GB SSD fills up quickly with video, photo libraries and audio stems. Many of the
same people already pay for 2 TB of Google Drive. The official Drive app either mirrors files to
disk or downloads a whole file when it is opened, so a large video still needs its full size free
before it can play.

## What Hollow does

- Mounts Google Drive at `~/Hollow`, visible to Finder and every app.
- Serves reads by byte range: only the parts of a file an app reads are downloaded and cached.
- Keeps recently read data in a bounded cache (5 to 100 GB, user-chosen).
- Uploads files you copy in, in the background.
- Gives quick access from the menu bar and a global search palette (Control-Option-H).

## Who it is for

People editing or playing large media from a Mac with limited storage who already have Google Drive
space. Secondary: anyone who wants Drive in Finder without full sync.

## Non-goals

- Full two-way sync of an existing Drive. Hollow uses the `drive.file` scope, so it only sees files
  it created ([04](04-privacy-and-security.md) explains why).
- Offline access to files that were never opened.
- Windows or Linux.
- Hosting files. Hollow has no servers.

## Success criteria

| Criterion | How it is checked | Status (2026-11-20) |
| --- | --- | --- |
| A partial read downloads about the size of the read, not the file | Read 1 MB from a 50 MB file through the mount; measure the cache | Met: about 2 MB cached |
| Sign-in uses the builder's own Google client and never ships a secret in the repo | Live sign-in; secret scan of every branch's history | Met |
| Launch never hangs on a stale mount | Reproduce a stuck NFS mount, launch the app | Met after the fix in [01](01-architecture.md#unmount-order) |
| Uploads survive interruption | Upload, interrupt after one chunk, resume | Met in `HollowDrive` (live) |
| Finder shows a disk named Hollow with Eject | FSKit build mounts and Finder is inspected | Not met: needs the paid Apple Developer Program |
| Runs on other Macs without warnings | Developer ID signing and notarization | Not met: same dependency |
