import SwiftUI

/// Host app. Launching it once registers the HollowFS extension with macOS.
@main
struct SpikeApp: App {
    var body: some Scene {
        WindowGroup("Hollow Drive") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Hollow Drive (FSKit test)").font(.title2.bold())
                Text("1. System Settings → General → Login Items & Extensions → File System Extensions: turn on Hollow Drive.")
                Text("2. Then mount it from Terminal (see spikes/fskit/README.md).")
            }
            .padding(24)
            .frame(width: 460)
        }
    }
}
