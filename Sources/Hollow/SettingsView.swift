import SwiftUI

struct SettingsView: View {
    let drive: Drive
    @AppStorage(Drive.cacheLimitKey) private var cacheLimitGB = Drive.defaultCacheLimitGB

    var body: some View {
        Form {
            Section("General") {
                Toggle("Open Hollow at login", isOn: Binding(get: { drive.opensAtLogin }, set: drive.setOpensAtLogin))
                if let error = drive.loginItemError {
                    Text(error).font(.footnote).foregroundStyle(.red)
                }
                LabeledContent("Search shortcut", value: "⌃⌥H")
            }

            Section {
                Picker("Keep on this Mac", selection: $cacheLimitGB) {
                    ForEach([5, 10, 25, 50, 100], id: \.self) { Text("Up to \($0) GB") }
                }
            } header: {
                Text("Storage")
            } footer: {
                Text("Files you've opened recently stay on your Mac up to this size, so they open instantly next time. Changes apply the next time Hollow mounts.")
                    .foregroundStyle(.secondary)
            }

            Section("Account") {
                LabeledContent("Google Drive", value: drive.signedIn ? "Connected" : "Not connected")
                if drive.signedIn {
                    Button("Sign Out", role: .destructive) { Task { await drive.signOut() } }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}
