import Foundation

public enum DriveError: Error, Equatable, Sendable {
    /// Google said the sign-in is no longer valid (revoked, or the refresh token expired).
    case signedOut
    case notFound
    /// Drive answered with an HTTP status Hollow doesn't handle; `message` is Google's text.
    case http(status: Int, message: String)
    /// An upload's resume point didn't match what Hollow expected.
    case uploadOutOfSync(expected: Int64, serverHas: Int64)
}
