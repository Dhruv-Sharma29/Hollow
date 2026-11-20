# 07 — Known issues

| Issue | Impact | Workaround or plan |
| --- | --- | --- |
| Finder shows "localhost" with Disconnect | Cosmetic; the mount works | FSKit version ([06](06-roadmap.md)) |
| Only files Hollow created are visible | Existing Drive files do not appear | By design of `drive.file`; add files through Hollow |
| Killing the app leaves rclone running | The mount stays up until the next launch clears it | Quit from the menu bar |
| Sign Out keeps the cache | Disk space is not reclaimed | Delete `~/Library/Application Support/Hollow/cache` once uploads are done |
| First access asks for network-volume permission | One-time prompt | Click **Allow** |
| Apple Silicon only | Does not run on Intel Macs | Universal rclone and app build |
| Ad-hoc signed builds | Run only on the Mac that built them | Developer ID signing and notarization |
| Search walks the folder tree on each keystroke | Slow on very large trees | Use rclone's cached listing, or `HollowDrive` queries |
| Dark app icon not shown in dark mode by default | Cosmetic | Set **Icon & widget style** to Dark |
| Tokens stored in a plain file | Readable by processes running as the user | Keychain in the FSKit version |
