import FSKit

/// Spike: the smallest FSKit file system that mounts. One empty, read-only volume named "Hollow Drive".
/// It answers one question: does macOS run it and show a disk with Eject?
@main
struct HollowFSExtension: UnaryFileSystemExtension {
    var fileSystem: HollowFileSystem { HollowFileSystem() }
}

final class HollowFileSystem: FSUnaryFileSystem, FSUnaryFileSystemOperations {
    func probeResource(resource: FSResource, replyHandler: @escaping (FSProbeResult?, (any Error)?) -> Void) {
        replyHandler(.usable(name: "Hollow Drive", containerID: FSContainerIdentifier(uuid: HollowVolume.containerUUID)), nil)
    }

    func loadResource(resource: FSResource, options: FSTaskOptions,
                      replyHandler: @escaping (FSVolume?, (any Error)?) -> Void) {
        containerStatus = .ready
        replyHandler(HollowVolume(), nil)
    }

    func unloadResource(resource: FSResource, options: FSTaskOptions, replyHandler: @escaping ((any Error)?) -> Void) {
        replyHandler(nil)
    }
}

final class HollowVolume: FSVolume, FSVolume.Operations {
    static let containerUUID = UUID(uuidString: "5B0D2C1E-8A1F-4E7B-9C3D-1A2B3C4D5E6F")!
    let root = FSItem()

    init() {
        super.init(volumeID: FSVolume.Identifier(uuid: UUID()), volumeName: FSFileName(string: "Hollow Drive"))
    }

    // MARK: Volume facts

    var supportedVolumeCapabilities: FSVolume.SupportedCapabilities {
        let caps = FSVolume.SupportedCapabilities()
        caps.supports64BitObjectIDs = true
        caps.supportsPersistentObjectIDs = true
        caps.caseFormat = .insensitiveCasePreserving
        return caps
    }

    var volumeStatistics: FSStatFSResult {
        let stats = FSStatFSResult(fileSystemTypeName: "hollowdrive")
        stats.blockSize = 4096
        stats.ioSize = 4096
        stats.totalBlocks = 1 << 28        // advertise 1 TB, like a cloud drive would
        stats.availableBlocks = 1 << 28
        stats.freeBlocks = 1 << 28
        stats.totalFiles = 1
        stats.freeFiles = 1_000_000
        return stats
    }

    var maximumLinkCount: Int { 1 }
    var maximumNameLength: Int { 255 }
    var restrictsOwnershipChanges: Bool { true }
    var truncatesLongNames: Bool { false }

    // MARK: Lifecycle

    func mount(options: FSTaskOptions) async throws {}
    func unmount() async {}
    func activate(options: FSTaskOptions) async throws -> FSItem { root }
    func deactivate(options: FSDeactivateOptions) async throws {}
    func synchronize(flags: FSSyncFlags) async throws {}

    // MARK: The one item: an empty root folder

    func attributes(_ request: FSItem.GetAttributesRequest, of item: FSItem) async throws -> FSItem.Attributes {
        guard item === root else { throw fs_errorForPOSIXError(ENOENT) }
        let attrs = FSItem.Attributes()
        attrs.type = .directory
        attrs.mode = UInt32(S_IFDIR | 0o755)
        attrs.linkCount = 2
        attrs.uid = getuid()
        attrs.gid = getgid()
        attrs.fileID = .rootDirectory
        attrs.parentID = .parentOfRoot
        var now = timespec()
        clock_gettime(CLOCK_REALTIME, &now)
        attrs.modifyTime = now
        attrs.changeTime = now
        attrs.accessTime = now
        attrs.birthTime = now
        return attrs
    }

    func lookupItem(named name: FSFileName, inDirectory directory: FSItem) async throws -> (FSItem, FSFileName) {
        throw fs_errorForPOSIXError(ENOENT)
    }

    func enumerateDirectory(_ directory: FSItem, startingAt cookie: FSDirectoryCookie, verifier: FSDirectoryVerifier,
                            attributes: FSItem.GetAttributesRequest?, packer: FSDirectoryEntryPacker) async throws -> FSDirectoryVerifier {
        verifier   // empty folder: nothing to pack
    }

    func reclaimItem(_ item: FSItem) async throws {}

    // MARK: Read-only: every change is refused

    func setAttributes(_ request: FSItem.SetAttributesRequest, on item: FSItem) async throws -> FSItem.Attributes {
        throw fs_errorForPOSIXError(EROFS)
    }
    func createItem(named name: FSFileName, type: FSItem.ItemType, inDirectory directory: FSItem,
                    attributes: FSItem.SetAttributesRequest) async throws -> (FSItem, FSFileName) {
        throw fs_errorForPOSIXError(EROFS)
    }
    func createSymbolicLink(named name: FSFileName, inDirectory directory: FSItem, attributes: FSItem.SetAttributesRequest,
                            linkContents contents: FSFileName) async throws -> (FSItem, FSFileName) {
        throw fs_errorForPOSIXError(EROFS)
    }
    func createLink(to item: FSItem, named name: FSFileName, inDirectory directory: FSItem) async throws -> FSFileName {
        throw fs_errorForPOSIXError(EROFS)
    }
    func removeItem(_ item: FSItem, named name: FSFileName, fromDirectory directory: FSItem) async throws {
        throw fs_errorForPOSIXError(EROFS)
    }
    func renameItem(_ item: FSItem, inDirectory sourceDirectory: FSItem, named sourceName: FSFileName, to destinationName: FSFileName,
                    inDirectory destinationDirectory: FSItem, overItem: FSItem?) async throws -> FSFileName {
        throw fs_errorForPOSIXError(EROFS)
    }
    func readSymbolicLink(_ item: FSItem) async throws -> FSFileName {
        throw fs_errorForPOSIXError(EINVAL)
    }
}
