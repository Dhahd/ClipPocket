import Foundation
import CryptoKit

class HistoryEncryptor {
    static let shared = HistoryEncryptor()

    private let keyFileName = ".clippocket_encryption_key"

    private init() {}

    // MARK: - Public API

    func encrypt(_ data: Data) throws -> Data {
        let key = try getOrCreateKey()
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combined = sealedBox.combined else {
            throw EncryptionError.sealingFailed
        }
        return combined
    }

    func decrypt(_ data: Data) throws -> Data {
        let key = try getOrCreateKey()
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }

    // MARK: - File-Based Key Management

    private var keyFileURL: URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let appDirectory = appSupport.appendingPathComponent("ClipPocket", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        return appDirectory.appendingPathComponent(keyFileName)
    }

    private func getOrCreateKey() throws -> SymmetricKey {
        if let existingKeyData = loadKeyFromFile() {
            return SymmetricKey(data: existingKeyData)
        }

        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }
        try saveKeyToFile(keyData)
        return newKey
    }

    private func loadKeyFromFile() -> Data? {
        guard let url = keyFileURL else { return nil }
        return try? Data(contentsOf: url)
    }

    private func saveKeyToFile(_ keyData: Data) throws {
        guard let url = keyFileURL else {
            throw EncryptionError.keySaveFailed
        }
        try keyData.write(to: url, options: [.atomic, .completeFileProtection])
    }

    // MARK: - Errors

    enum EncryptionError: LocalizedError {
        case sealingFailed
        case keySaveFailed

        var errorDescription: String? {
            switch self {
            case .sealingFailed:
                return "Failed to seal data for encryption"
            case .keySaveFailed:
                return "Failed to save encryption key"
            }
        }
    }
}
