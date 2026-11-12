import Foundation

/// One file or folder in Drive, with just the fields Hollow needs.
public struct DriveFile: Decodable, Sendable, Equatable, Identifiable {
    public static let folderMIMEType = "application/vnd.google-apps.folder"

    public let id: String
    public let name: String
    public let mimeType: String
    public let size: Int64?
    public let modifiedTime: Date?
    public let parents: [String]?

    public var isFolder: Bool { mimeType == Self.folderMIMEType }

    /// The field list to ask Drive for, matching the properties above.
    static let fields = "id,name,mimeType,size,modifiedTime,parents"

    enum CodingKeys: String, CodingKey { case id, name, mimeType, size, modifiedTime, parents }

    public init(id: String, name: String, mimeType: String, size: Int64? = nil,
                modifiedTime: Date? = nil, parents: [String]? = nil) {
        self.id = id
        self.name = name
        self.mimeType = mimeType
        self.size = size
        self.modifiedTime = modifiedTime
        self.parents = parents
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        mimeType = try c.decode(String.self, forKey: .mimeType)
        // Drive sends sizes as strings ("1048576"), and omits them for folders and Google Docs.
        size = try c.decodeIfPresent(String.self, forKey: .size).flatMap(Int64.init)
        modifiedTime = try c.decodeIfPresent(String.self, forKey: .modifiedTime)
            .flatMap { try? Date($0, strategy: .iso8601.year().month().day().time(includingFractionalSeconds: true)) }
        parents = try c.decodeIfPresent([String].self, forKey: .parents)
    }
}
