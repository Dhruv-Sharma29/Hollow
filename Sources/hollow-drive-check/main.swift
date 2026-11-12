import Foundation
import HollowDrive

// Live check of HollowDrive against your real Google Drive.
//
//   swift run hollow-drive-check ~/Downloads/client_secret_….json
//
// Uses the sign-in Hollow already saved (its rclone.conf). It creates a test folder, uploads a
// 3 MiB file in chunks with a deliberate interruption, reads slices back and compares them,
// renames, then moves everything to Drive's bin. drive.file means it can't see anything else.
// Never prints the client secret or tokens.

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("✗ \(message)\n".utf8))
    exit(1)
}

func step(_ message: String) { print("✓ \(message)") }

// The client, from Google's downloaded JSON.
guard CommandLine.arguments.count == 2 else { fail("usage: hollow-drive-check <client_secret.json>") }
struct ClientFile: Decodable { struct Installed: Decodable { let client_id: String; let client_secret: String }; let installed: Installed }
guard let clientData = FileManager.default.contents(atPath: CommandLine.arguments[1]),
      let clientFile = try? JSONDecoder().decode(ClientFile.self, from: clientData)
else { fail("couldn't read a Desktop app client from \(CommandLine.arguments[1])") }
let client = OAuthClient(id: clientFile.installed.client_id, secret: clientFile.installed.client_secret)

// The refresh token from Hollow's saved sign-in.
let config = URL.applicationSupportDirectory.appending(path: "Hollow/rclone.conf")
guard let text = try? String(contentsOf: config, encoding: .utf8),
      let line = text.split(separator: "\n").first(where: { $0.hasPrefix("token = ") }),
      let saved = try? JSONSerialization.jsonObject(with: Data(line.dropFirst("token = ".count).utf8)) as? [String: Any],
      let refreshToken = saved["refresh_token"] as? String
else { fail("no saved sign-in in \(config.path); connect Hollow to Google Drive first") }
if let savedClient = text.split(separator: "\n").first(where: { $0.hasPrefix("client_id = ") }),
   !savedClient.hasSuffix(client.id) {
    fail("Hollow signed in with a different client than this JSON; use the matching client file")
}

let drive = DriveClient(tokens: TokenProvider(client: client, refreshToken: refreshToken))

do {
    let stamp = Date.now.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false)).replacing(":", with: ".")
    let folder = try await drive.createFolder(named: "Hollow drive check \(stamp)", in: "root")
    step("created folder \"\(folder.name)\"")

    // A 3 MiB file with varied bytes, so any gap or repeat would show up when comparing.
    let size = 3 * 1024 * 1024
    var bytes = [UInt8](repeating: 0, count: size)
    for i in bytes.indices { bytes[i] = UInt8(truncatingIfNeeded: i &* 2654435761 >> 13) }
    let original = Data(bytes)
    let local = URL.temporaryDirectory.appending(path: "hollow-drive-check-\(UUID()).bin")
    try original.write(to: local)
    defer { try? FileManager.default.removeItem(at: local) }

    let session = try await drive.startUpload(name: "check.bin", in: folder.id, size: Int64(size))
    let chunk = 1024 * 1024
    do {
        _ = try await drive.upload(session, from: local, chunkSize: chunk) { sent in
            if sent > 0 { throw CancellationError() }   // pretend the Mac went to sleep after one chunk
        }
        fail("the deliberate interruption didn't happen")
    } catch is CancellationError {
        let (received, _) = try await drive.uploadStatus(session)
        step("interrupted the upload after \(received / 1024) KiB; Drive kept it")
    }
    let uploaded = try await drive.upload(session, from: local, chunkSize: chunk)
    guard uploaded.size == Int64(size) else { fail("uploaded size \(uploaded.size ?? -1), expected \(size)") }
    step("resumed and finished the upload (\(size / 1024) KiB)")

    let listed = try await drive.list(in: folder.id)
    guard listed.map(\.id) == [uploaded.id] else { fail("folder listing didn't show exactly the uploaded file") }
    step("listed the folder")

    for range in [0..<4096, 1_500_000..<1_504_096, size - 4096..<size] {
        let slice = try await drive.read(id: uploaded.id, range: Int64(range.lowerBound)..<Int64(range.upperBound))
        guard slice == original.subdata(in: range) else { fail("bytes \(range) don't match what was uploaded") }
    }
    step("read three 4 KiB slices (start, middle, end); each matches byte for byte and nothing else was downloaded")

    let renamed = try await drive.update(id: uploaded.id, newName: "renamed.bin")
    guard renamed.name == "renamed.bin", try await drive.find(named: "renamed.bin", in: folder.id)?.id == uploaded.id
    else { fail("rename didn't stick") }
    step("renamed the file")

    try await drive.trash(id: uploaded.id)
    try await drive.trash(id: folder.id)
    step("moved the test file and folder to Drive's bin")
    print("\nAll checks passed.")
} catch {
    fail("\(error)")
}
