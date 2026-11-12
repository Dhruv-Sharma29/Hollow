# FSKit spike

**Question:** can this Mac sign and run an FSKit file system that Finder shows as a disk named
**Hollow Drive**, with **Eject**, instead of the NFS server "localhost" with Disconnect?

**What it is:** a host app plus a minimal FSKit extension (`FS/HollowFS.swift`) that serves one
empty, read-only volume named "Hollow Drive". It never touches Google Drive.

## Result (12 November 2026)

**Blocked on the account type.** The extension compiles, but Apple won't sign it for a free account:

> Personal development teams, including "Dhruv Sharma", do not support the FSKit Module capability.

FSKit needs the paid Apple Developer Program ($99/year), the same membership needed to sell Hollow.
Until then Hollow stays on rclone + NFS, which Finder shows as the server "localhost" with Disconnect.
Once enrolled, set the team in `project.yml` and rerun step 2; the mount steps below are untested.

Clue for step 5: Apple's own path-URL FSKit mount on this Mac (DeviceFS) lists its source as a
`file:///…` URL and its flags as `local, fskit`. So the mount may need
`mount -t hollowdrive file://$HOME/HollowSpikeSource ~/HollowSpikeMount`, and `local` is what gives
Finder its Eject button.

## Run it

1. **Sign in to Xcode:** Xcode → Settings → Accounts → **+** → Apple ID.
2. **Build and sign** (registers `app.hollow.spike.HollowFSSpike` and `….fs` with your team):
   ```bash
   cd spikes/fskit && xcodegen generate --spec project.yml
   xcodebuild -project HollowFSSpike.xcodeproj -scheme HollowFSSpike -derivedDataPath build -allowProvisioningUpdates build
   ```
   Or open `HollowFSSpike.xcodeproj` in Xcode and press Run.
3. **Register the extension:** press Run in Xcode, or open the built `Hollow Drive.app` once.
4. **Enable it:** System Settings → General → Login Items & Extensions → File System Extensions →
   turn on **Hollow Drive**.
5. **Mount it:**
   ```bash
   mkdir -p ~/HollowSpikeSource ~/HollowSpikeMount
   mount -t hollowdrive ~/HollowSpikeSource ~/HollowSpikeMount
   ```
6. **Look in Finder:** does the sidebar show **Hollow Drive** with an Eject button?
7. **Unmount:** `umount ~/HollowSpikeMount`

## What each outcome means

| Result | Meaning |
|---|---|
| Signing fails on `com.apple.developer.fskit.fsmodule` | A free Apple account can't sign FSKit modules; needs the paid program |
| Signs, but the mount fails | Signing is fine; the mount call or extension setup needs work |
| Mounts and Finder shows Hollow Drive + Eject | FSKit works here; the rewrite is viable |
