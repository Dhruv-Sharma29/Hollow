import Foundation
@testable import HollowDrive

/// A fake Google server. Tests script its replies; it records every request it saw.
/// Shared state behind a lock, because URLSession calls the protocol from its own threads.
final class FakeGoogle: @unchecked Sendable {
    typealias Reply = (status: Int, headers: [String: String], body: Data)

    private let lock = NSLock()
    private var handler: @Sendable (URLRequest, Data) -> Reply = { _, _ in (500, [:], Data()) }
    private var seen: [(URLRequest, Data)] = []

    /// Each fake is found by an ID header on its own session, so suites running in parallel
    /// never reach each other's fake.
    private static let registryLock = NSLock()
    nonisolated(unsafe) private static var registry: [String: FakeGoogle] = [:]
    private let id = UUID().uuidString

    static func lookup(_ request: URLRequest) -> FakeGoogle? {
        guard let id = request.value(forHTTPHeaderField: "X-Fake-Google") else { return nil }
        return registryLock.withLock { registry[id] }
    }

    /// A Drive client whose every request goes to this fake, with no retry delays.
    func client(token: AccessToken? = AccessToken(value: "valid", expiry: .now.addingTimeInterval(3600))) -> DriveClient {
        Self.registryLock.withLock { Self.registry[id] = self }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FakeProtocol.self]
        config.httpAdditionalHeaders = ["X-Fake-Google": id]
        let session = URLSession(configuration: config)
        let tokens = TokenProvider(client: OAuthClient(id: "id", secret: "secret"), refreshToken: "refresh",
                                   current: token, session: session)
        return DriveClient(tokens: tokens, session: session, retryDelay: { _ in .zero })
    }

    func respond(_ handler: @escaping @Sendable (URLRequest, Data) -> Reply) {
        lock.withLock { self.handler = handler }
    }

    var requests: [(request: URLRequest, body: Data)] { lock.withLock { seen.map { ($0.0, $0.1) } } }

    fileprivate func handle(_ request: URLRequest, body: Data) -> Reply {
        lock.withLock { seen.append((request, body)) }
        return lock.withLock { handler }(request, body)
    }

    static func json(_ object: Any, status: Int = 200) -> Reply {
        (status, ["Content-Type": "application/json"], try! JSONSerialization.data(withJSONObject: object))
    }
}

final class FakeProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let fake = FakeGoogle.lookup(request) else { return }
        // URLSession moves httpBody into a stream before a protocol sees it.
        var body = request.httpBody ?? Data()
        if let stream = request.httpBodyStream {
            stream.open()
            var buffer = [UInt8](repeating: 0, count: 64 * 1024)
            while stream.hasBytesAvailable {
                let n = stream.read(&buffer, maxLength: buffer.count)
                if n <= 0 { break }
                body.append(buffer, count: n)
            }
            stream.close()
        }
        let reply = fake.handle(request, body: body)
        let response = HTTPURLResponse(url: request.url!, statusCode: reply.status, httpVersion: "HTTP/1.1", headerFields: reply.headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: reply.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

extension URLRequest {
    func query(_ name: String) -> String? {
        URLComponents(url: url!, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == name }?.value
    }
}
