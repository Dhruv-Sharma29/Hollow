import AppKit

/// Puts Hollow's window above whatever app you're in. A menu-bar app isn't active by default,
/// so opening a window alone leaves it behind other apps.
@MainActor
enum BringForward {
    static func now() {
        // Asking to become active is honoured after a click on Hollow, but often refused right
        // after launch. orderFrontRegardless() raises the window either way.
        NSApp.activate()
        Task {
            // SwiftUI creates the window a moment later, so wait for it (up to about a second).
            for _ in 0..<20 {
                let windows = NSApp.windows.filter { $0.isVisible && $0.canBecomeMain }
                if !windows.isEmpty {
                    for window in windows {
                        window.orderFrontRegardless()
                        window.makeKey()
                    }
                    return
                }
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }
}
