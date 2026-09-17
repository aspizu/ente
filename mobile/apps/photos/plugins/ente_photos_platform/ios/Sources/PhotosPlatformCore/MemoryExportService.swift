import Foundation

final class MemoryExportService {
    static let shared = MemoryExportService()

    enum ExportError: Error {
        case unimplemented(String)
    }

    private init() {}

    func exportMemory(input: [String], output: URL, onProgress: (Double) -> Void) throws {
        throw ExportError.unimplemented("TODO: implement memory export and progress")
    }
}
