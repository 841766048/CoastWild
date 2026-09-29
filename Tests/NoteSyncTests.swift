import XCTest
import ImageIO
@testable import CoastWildCore

final class NoteSyncTests: XCTestCase {
    func testStagedPhotosInstallTogetherAndPreserveOriginals() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let stage = root.appendingPathComponent("stage"), live = root.appendingPathComponent("Photos")
        try FileManager.default.createDirectory(at: stage, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: live, withIntermediateDirectories: true)
        try Data([1]).write(to: live.appendingPathComponent("original.jpg"))
        try Data([2]).write(to: stage.appendingPathComponent("original.jpg"))
        try Data([3]).write(to: stage.appendingPathComponent("new.jpg"))
        XCTAssertThrowsError(try NotePhotoCodec.installRestoredFiles(["new.jpg", "missing.jpg"], from: stage, to: live))
        XCTAssertFalse(FileManager.default.fileExists(atPath: live.appendingPathComponent("new.jpg").path))
        try NotePhotoCodec.installRestoredFiles(["original.jpg", "new.jpg"], from: stage, to: live)
        XCTAssertEqual(try Data(contentsOf: live.appendingPathComponent("original.jpg")), Data([1]))
        XCTAssertEqual(try Data(contentsOf: live.appendingPathComponent("new.jpg")), Data([3]))
        XCTAssertThrowsError(try NotePhotoCodec.installRestoredFiles(["../escape.jpg"], from: stage, to: live))
    }
    func testPhotoCodecCompressesRestoresAndRejectsCorruption() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let original = folder.appendingPathComponent("original.jpg")
        let restored = folder.appendingPathComponent("reinstalled/photo.jpg")
        let context = try XCTUnwrap(CGContext(data: nil, width: 2400, height: 1800,
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        context.setFillColor(CGColor(red: 0.1, green: 0.6, blue: 0.5, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 2400, height: 1800))
        let image = try XCTUnwrap(context.makeImage())
        let output = try XCTUnwrap(CGImageDestinationCreateWithURL(original as CFURL, "public.jpeg" as CFString, 1, nil))
        CGImageDestinationAddImage(output, image, [
            kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 30.0, kCGImagePropertyGPSLatitudeRef: "N"],
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifUserComment: "private metadata"]
        ] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(output))
        let originalBytes = try Data(contentsOf: original)
        let payload = try NotePhotoCodec.compress(original)
        XCTAssertLessThanOrEqual(payload.bytes, 204800)
        XCTAssertLessThanOrEqual(max(payload.width, payload.height), 1600)
        let transported = try JSONDecoder().decode(NotePhotoPayload.self, from: JSONEncoder().encode(payload))
        try NotePhotoCodec.restore(transported, to: restored)
        XCTAssertEqual(try Data(contentsOf: restored), try payload.decodedJPEG())
        XCTAssertEqual(try Data(contentsOf: original), originalBytes)
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(restored as CFURL, nil))
        let props = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        XCTAssertNil(props[kCGImagePropertyGPSDictionary])
        let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any]
        XCTAssertNil(exif?[kCGImagePropertyExifUserComment])
        var bad = payload; bad.width += 1
        XCTAssertThrowsError(try NotePhotoCodec.restore(bad, to: restored))
        bad = payload; bad.sha256 = String(repeating: "0", count: 64)
        XCTAssertThrowsError(try NotePhotoCodec.restore(bad, to: restored))
        XCTAssertThrowsError(try NotePhotoCodec.compress(folder.appendingPathComponent("missing.jpg")))
    }
    func testPhotoBackupMigrationRequeuesOnceAndRemoteManifestWinsWithoutEcho() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try CoastStore(directory: directory)
        try store.activate(accountID: "a")
        var note = CoastEntry(title: "Photo", body: "text", date: "2026-09-24", photos: ["old.jpg"])
        try store.saveEntry(note)
        try store.acknowledgeNote(id: note.id, uploaded: note)
        try store.prepareNoteImageSync()
        XCTAssertEqual(store.pendingNoteIDs, [note.id])
        try store.acknowledgeNote(id: note.id, uploaded: note)
        let reopened = try CoastStore(directory: directory)
        try reopened.activate(accountID: "a")
        try reopened.prepareNoteImageSync()
        XCTAssertTrue(reopened.pendingNoteIDs.isEmpty)
        note.cloudPhotoIDs = ["restored"]
        note.photos = ["restored.jpg"]
        try reopened.mergeRemoteNotes([note])
        XCTAssertEqual(reopened.ledger.entries.first?.photos, ["restored.jpg"])
        XCTAssertTrue(reopened.pendingNoteIDs.isEmpty)
        note.cloudPhotoIDs = []; note.photos = []
        try reopened.mergeRemoteNotes([note])
        XCTAssertEqual(reopened.ledger.entries.first?.photos, [])
    }

    func testPhotoPayloadBoundsDigestAndSafeIDs() throws {
        let jpeg = Data([0xff, 0xd8, 0xff, 0xd9])
        let value = try NotePhotoPayload(jpeg: jpeg, width: 10, height: 20)
        XCTAssertEqual(try value.decodedJPEG(), jpeg)
        XCTAssertEqual(try NotePhotoPayload.id(filename: "abc-123.jpg"), "abc-123")
        XCTAssertThrowsError(try NotePhotoPayload.id(filename: "../private.jpg"))
        XCTAssertThrowsError(try NotePhotoPayload.id(filename: "bad.png"))
        XCTAssertThrowsError(try NotePhotoPayload(jpeg: Data(repeating: 0, count: 204801), width: 10, height: 20))
        XCTAssertThrowsError(try NotePhotoPayload(jpeg: jpeg, width: 1601, height: 20))
        var bad = value; bad.base64 = "invalid"
        XCTAssertThrowsError(try bad.decodedJPEG())
        bad = value; bad.sha256 = String(repeating: "0", count: 64)
        XCTAssertThrowsError(try bad.decodedJPEG())
        XCTAssertThrowsError(try NotePhotoPayload.validateIDs(["a", "a"]))
        XCTAssertThrowsError(try NotePhotoPayload.validateIDs(Array(repeating: "a", count: 13)))
    }

    func testNewAnonymousIdentityRequeuesLocalNotesInsteadOfErasingThem() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try CoastStore(directory: directory)
        try store.activate(accountID: "a")
        let note = CoastEntry(title: "Draft", body: "Keep me", date: "2026-09-23")
        try store.saveEntry(note)
        try store.prepareNoteSync(scope: "uid-1/device")
        try store.acknowledgeNote(id: note.id, uploaded: note)
        try store.prepareNoteSync(scope: "uid-2/device")
        try store.mergeRemoteNotes([])
        XCTAssertEqual(store.ledger.entries, [note])
        XCTAssertEqual(store.pendingNoteIDs, [note.id])
    }
    func testQueuePersistsAndDeletionSurvivesRemoteRead() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try CoastStore(directory: directory)
        try store.activate(accountID: "a")
        let note = CoastEntry(title: "Draft", body: "text", date: "2026-09-23")
        try store.saveEntry(note)
        XCTAssertEqual(store.pendingNoteIDs, [note.id])
        let reopened = try CoastStore(directory: directory)
        try reopened.activate(accountID: "a")
        XCTAssertEqual(reopened.pendingNoteIDs, [note.id])
        try reopened.deleteEntry(id: note.id)
        try reopened.mergeRemoteNotes([note])
        XCTAssertTrue(reopened.ledger.entries.isEmpty)
        XCTAssertEqual(reopened.pendingNoteIDs, [note.id])
        try reopened.acknowledgeNote(id: note.id, uploaded: nil)
        XCTAssertTrue(reopened.pendingNoteIDs.isEmpty)
    }

    func testAckDoesNotDropNewerEditAndAccountsAreIsolated() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try CoastStore(directory: directory)
        try store.activate(accountID: "a")
        var note = CoastEntry(title: "Draft", body: "old", date: "2026-09-23")
        try store.saveEntry(note)
        let uploading = note
        note.body = "new"
        try store.saveEntry(note)
        try store.acknowledgeNote(id: note.id, uploaded: uploading)
        XCTAssertEqual(store.pendingNoteIDs, [note.id])
        try store.mergeRemoteNotes([uploading])
        XCTAssertEqual(store.ledger.entries.first?.body, "new")
        try store.activate(accountID: "b")
        XCTAssertTrue(store.pendingNoteIDs.isEmpty)
        XCTAssertTrue(store.ledger.entries.isEmpty)
    }

    func testRemoteMergePreservesLocalPhotosAndQueuesNoEcho() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try CoastStore(directory: directory)
        try store.activate(accountID: "a")
        var note = CoastEntry(title: "Draft", body: "old", date: "2026-09-23", photos: ["private.jpg"])
        try store.saveEntry(note)
        try store.acknowledgeNote(id: note.id, uploaded: note)
        note.body = "remote"; note.photos = []
        try store.mergeRemoteNotes([note])
        XCTAssertEqual(store.ledger.entries.first?.photos, ["private.jpg"])
        XCTAssertEqual(store.ledger.entries.first?.body, "remote")
        XCTAssertTrue(store.pendingNoteIDs.isEmpty)
    }
}
