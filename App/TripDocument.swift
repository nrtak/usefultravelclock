import Foundation
import Combine
import CryptoKit
import PDFKit
import ImageIO
import UniformTypeIdentifiers
import Vision

enum TripSaveError {
    static func message(_ error: Error) -> String {
        let failure = error as NSError
        if failure.domain == NSCocoaErrorDomain && failure.code == CocoaError.fileWriteOutOfSpace.rawValue {
            return "Your iPhone does not have enough free storage. Free space in iPhone Settings, then return here and retry."
        }
        if let underlying = failure.userInfo[NSUnderlyingErrorKey] as? Error {
            let nested = underlying as NSError
            if nested.domain == NSPOSIXErrorDomain && nested.code == 28 {
                return "Your iPhone does not have enough free storage. Free space in iPhone Settings, then return here and retry."
            }
        }
        return failure.localizedDescription
    }
}

enum TripDocumentKind: String, Codable, CaseIterable, Identifiable {
    case boardingPass = "Boarding pass", confirmation = "Booking confirmation", receipt = "Receipt", other = "Other"
    var id: String { rawValue }
}

struct TripDocument: Codable, Identifiable, Equatable {
    var id = UUID()
    var recordID: UUID?
    var name: String
    var originalFilename: String
    var fileExtension: String
    var kind: TripDocumentKind = .other
    var traveler = ""
    var note = ""
    var byteCount: Int
    var updatedAt = Date()
    // Each replacement gets a new storage ID so a failed save cannot overwrite the original.
    var storageID = UUID()
    func matches(_ query: String, record: TravelRecord?) -> Bool {
        let fields = [name, originalFilename, kind.rawValue, traveler, note, record?.name ?? "", record?.reference ?? "", record?.bookingReference ?? ""]
        return query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || fields.contains { $0.localizedStandardContains(query.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }
}

struct TripDocumentPayload: Sendable, Codable {
    let data: Data
    let filename: String
    let fileExtension: String
    static let maximumBytes = 25 * 1024 * 1024
    static func read(_ url: URL) throws -> Self {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= maximumBytes else { throw TripDocumentError.tooLarge }
        return try validate(Data(contentsOf: url), filename: url.lastPathComponent)
    }
    static func validate(_ data: Data, filename: String) throws -> Self {
        guard !data.isEmpty else { throw TripDocumentError.invalidFile }
        guard data.count <= maximumBytes else { throw TripDocumentError.tooLarge }
        let ext: String
        if data.starts(with: Data("%PDF-".utf8)) {
            guard let pdf = PDFDocument(data: data), !pdf.isLocked, pdf.pageCount > 0 else { throw TripDocumentError.invalidFile }
            ext = "pdf"
        } else if let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let type = CGImageSourceGetType(source), CGImageSourceGetCount(source) > 0,
                  let imageType = UTType(type as String), imageType.conforms(to: .image),
                  CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCache: false] as CFDictionary) != nil,
                  let preferred = imageType.preferredFilenameExtension {
            ext = preferred
        } else { throw TripDocumentError.invalidFile }
        let stem = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
        let safe = stem.components(separatedBy: CharacterSet(charactersIn: "/\\:\n\r")).joined(separator: "-")
        return Self(data: data, filename: (safe.isEmpty ? "Document" : String(safe.prefix(120))) + "." + ext, fileExtension: ext)
    }
    func recognizedText() throws -> String {
        if fileExtension == "pdf", let pdf = PDFDocument(data: data) {
            let text = (0..<min(pdf.pageCount, 5)).compactMap { pdf.page(at: $0)?.string }.joined(separator: "\n")
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return String(text.prefix(12000)) }
            // Scanned PDFs still support on-device recognition from the first page.
            guard let page = pdf.page(at: 0), let cg = page.thumbnail(of: CGSize(width: 1600, height: 2000), for: .mediaBox).cgImage else { return "" }
            return try Self.recognize(VNImageRequestHandler(cgImage: cg, options: [:]))
        }
        return try Self.recognize(VNImageRequestHandler(cgImage: recognitionImage(), options: [:]))
    }
    func recognitionImage() throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 2000,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { throw TripDocumentError.invalidFile }
        return image
    }
    private static func recognize(_ handler: VNImageRequestHandler) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate; request.automaticallyDetectsLanguage = true
        try handler.perform([request])
        return String((request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n").prefix(12000))
    }
}

struct TripImportDraft: Codable, Equatable {
    var storageID = UUID()
    var recordID: UUID?
    var replacingID: UUID?
    var savedDocumentID: UUID?
    var name = ""
    var kind = TripDocumentKind.other
    var traveler = ""
    var note = ""
    var bookingReference = ""
    var recognized: String? = nil
    var recognitionDone: Bool? = nil
    func canResume(replacing target: UUID?, hasIncomingFile: Bool) -> Bool {
        !hasIncomingFile && (target == nil || replacingID == target)
    }
}

enum TripDocumentError: LocalizedError {
    case locked, invalidFile, tooLarge, missing
    var errorDescription: String? {
        switch self {
        case .locked: return "Unlock your travel details and try again."
        case .invalidFile: return "Choose a readable PDF or image. Password-protected PDFs must be unlocked first."
        case .tooLarge: return "Choose a document smaller than 25 MB."
        case .missing: return "This document is unavailable. Import the original again."
        }
    }
}

// All documents and their metadata use the existing encrypted travel vault key.
struct TripDocumentVault {
    let directory: URL
    let key: SymmetricKey
    private var manifest: URL { directory.appendingPathComponent("documents.sealed") }
    func file(_ id: UUID) -> URL { directory.appendingPathComponent(id.uuidString + ".sealed") }
    func load() throws -> [TripDocument] {
        guard FileManager.default.fileExists(atPath: manifest.path) else { return [] }
        return try JSONDecoder().decode([TripDocument].self, from: decrypt(Data(contentsOf: manifest)))
    }
    func persist(_ documents: [TripDocument]) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try encrypt(JSONEncoder().encode(documents)).write(to: manifest, options: [.atomic, .completeFileProtection])
    }
    func write(_ payload: TripDocumentPayload, id: UUID) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try encrypt(payload.data).write(to: file(id), options: [.atomic, .completeFileProtection])
    }
    func data(_ document: TripDocument) throws -> Data {
        guard FileManager.default.fileExists(atPath: file(document.storageID).path) else { throw TripDocumentError.missing }
        return try decrypt(Data(contentsOf: file(document.storageID)))
    }
    func remove(_ id: UUID) throws {
        if FileManager.default.fileExists(atPath: file(id).path) { try FileManager.default.removeItem(at: file(id)) }
    }
    func available(_ document: TripDocument) -> Bool { FileManager.default.fileExists(atPath: file(document.storageID).path) }
    func prune(except documents: [TripDocument]) {
        let keep = Set(documents.map { file($0.storageID).lastPathComponent } + [manifest.lastPathComponent])
        for url in (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? [] where url.pathExtension == "sealed" && !keep.contains(url.lastPathComponent) {
            try? FileManager.default.removeItem(at: url)
        }
    }
    private func encrypt(_ data: Data) throws -> Data {
        guard let sealed = try AES.GCM.seal(data, using: key).combined else { throw TripDocumentError.invalidFile }
        return sealed
    }
    private func decrypt(_ data: Data) throws -> Data { try AES.GCM.open(AES.GCM.SealedBox(combined: data), using: key) }
}

@MainActor final class TripDocumentInbox: ObservableObject {
    @Published private(set) var url: URL?
    @Published private(set) var currentPreserved = false
    private var pending: [URL] = []
    private var accessURLs = Set<URL>()
    func receive(_ value: URL) {
        guard value.isFileURL, value != url, !pending.contains(value) else { return }
        if value.startAccessingSecurityScopedResource() { accessURLs.insert(value) }
        if url == nil { url = value } else { pending.append(value) }
    }
    func markPreserved(_ value: URL) { if url == value { currentPreserved = true } }
    func finishCurrent(ifMatching expected: URL? = nil, preserved: Bool = true, interrupted: Bool = false) {
        guard expected == nil || url == expected, !interrupted || preserved || currentPreserved else { return }
        if let url, accessURLs.remove(url) != nil { url.stopAccessingSecurityScopedResource() }
        currentPreserved = false
        url = pending.isEmpty ? nil : pending.removeFirst()
    }
    func clear() {
        for value in accessURLs { value.stopAccessingSecurityScopedResource() }
        accessURLs.removeAll(); pending.removeAll(); currentPreserved = false; url = nil
    }
}

struct TripAirlineLink: Identifiable {
    let name: String
    let url: String
    var id: String { name }
}

enum TripBookingLink {
    // Opens in the browser. No credentials or booking references are transmitted automatically.
    static let airlines: [TripAirlineLink] = [
        .init(name: "ANA", url: "https://www.ana.co.jp/en/us/plan-book/how-to-manage-your-booking/"),
        .init(name: "Japan Airlines", url: "https://www.jal.co.jp/en-us/my-booking.html"),
        .init(name: "Delta", url: "https://www.delta.com/my-trips/search")
    ]
    static func url(_ text: String?) -> URL? {
        guard let text, let parts = URLComponents(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              parts.scheme?.lowercased() == "https", let host = parts.host, !host.isEmpty,
              parts.user == nil, parts.password == nil else { return nil }
        return parts.url
    }
}
