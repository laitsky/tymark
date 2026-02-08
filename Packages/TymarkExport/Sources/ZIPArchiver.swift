import Foundation

// MARK: - Minimal ZIP Archiver

/// A minimal ZIP archive builder for creating DOCX files.
/// Uses STORED (uncompressed) entries for simplicity and correctness.
final class ZIPArchiver {

    // MARK: - Types

    private struct ArchiveEntry {
        let path: String
        let data: Data
        let crc32: UInt32
    }

    // MARK: - Properties

    private var entries: [ArchiveEntry] = []

    // MARK: - Public API

    /// Add a file entry to the archive.
    func addEntry(path: String, data: Data) {
        let crc = CRC32.calculate(data: data)
        entries.append(ArchiveEntry(path: path, data: data, crc32: crc))
    }

    /// Add a text file entry (UTF-8 encoded).
    func addEntry(path: String, content: String) {
        addEntry(path: path, data: Data(content.utf8))
    }

    /// Build the final ZIP archive.
    func build() -> Data {
        var archive = Data()
        var centralDirectory = Data()
        var localHeaderOffsets: [Int] = []

        // Write local file headers and file data
        for entry in entries {
            localHeaderOffsets.append(archive.count)
            archive.append(buildLocalFileHeader(entry))
            archive.append(entry.data)
        }

        // Write central directory
        let centralDirectoryOffset = archive.count

        for (index, entry) in entries.enumerated() {
            centralDirectory.append(buildCentralDirectoryEntry(entry, localHeaderOffset: localHeaderOffsets[index]))
        }

        archive.append(centralDirectory)

        // Write end of central directory
        archive.append(buildEndOfCentralDirectory(
            entryCount: entries.count,
            centralDirectorySize: centralDirectory.count,
            centralDirectoryOffset: centralDirectoryOffset
        ))

        return archive
    }

    // MARK: - ZIP Structure Builders

    private func buildLocalFileHeader(_ entry: ArchiveEntry) -> Data {
        var header = Data()
        let pathData = Data(entry.path.utf8)

        header.appendUInt32(0x04034b50)                                     // Local file header signature
        header.appendUInt16(20)                                             // Version needed (2.0)
        header.appendUInt16(0)                                              // General purpose bit flag
        header.appendUInt16(0)                                              // Compression method (STORED)
        header.appendUInt16(0)                                              // Last mod file time
        header.appendUInt16(0)                                              // Last mod file date
        header.appendUInt32(entry.crc32)                                    // CRC-32
        header.appendUInt32(UInt32(entry.data.count))                       // Compressed size (same as uncompressed for STORED)
        header.appendUInt32(UInt32(entry.data.count))                       // Uncompressed size
        header.appendUInt16(UInt16(pathData.count))                         // File name length
        header.appendUInt16(0)                                              // Extra field length
        header.append(pathData)                                             // File name

        return header
    }

    private func buildCentralDirectoryEntry(_ entry: ArchiveEntry, localHeaderOffset: Int) -> Data {
        var record = Data()
        let pathData = Data(entry.path.utf8)

        record.appendUInt32(0x02014b50)                                     // Central directory header signature
        record.appendUInt16(20)                                             // Version made by
        record.appendUInt16(20)                                             // Version needed
        record.appendUInt16(0)                                              // General purpose bit flag
        record.appendUInt16(0)                                              // Compression method (STORED)
        record.appendUInt16(0)                                              // Last mod file time
        record.appendUInt16(0)                                              // Last mod file date
        record.appendUInt32(entry.crc32)                                    // CRC-32
        record.appendUInt32(UInt32(entry.data.count))                       // Compressed size (same as uncompressed)
        record.appendUInt32(UInt32(entry.data.count))                       // Uncompressed size
        record.appendUInt16(UInt16(pathData.count))                         // File name length
        record.appendUInt16(0)                                              // Extra field length
        record.appendUInt16(0)                                              // File comment length
        record.appendUInt16(0)                                              // Disk number start
        record.appendUInt16(0)                                              // Internal file attributes
        record.appendUInt32(0)                                              // External file attributes
        record.appendUInt32(UInt32(localHeaderOffset))                      // Relative offset of local header
        record.append(pathData)                                             // File name

        return record
    }

    private func buildEndOfCentralDirectory(entryCount: Int, centralDirectorySize: Int, centralDirectoryOffset: Int) -> Data {
        var eocd = Data()

        eocd.appendUInt32(0x06054b50)                                       // End of central directory signature
        eocd.appendUInt16(0)                                                // Number of this disk
        eocd.appendUInt16(0)                                                // Disk where central directory starts
        eocd.appendUInt16(UInt16(entryCount))                               // Number of central directory records on this disk
        eocd.appendUInt16(UInt16(entryCount))                               // Total number of central directory records
        eocd.appendUInt32(UInt32(centralDirectorySize))                     // Size of central directory
        eocd.appendUInt32(UInt32(centralDirectoryOffset))                   // Offset of start of central directory
        eocd.appendUInt16(0)                                                // Comment length

        return eocd
    }
}

// MARK: - CRC32

enum CRC32 {
    private static let table: [UInt32] = {
        (0..<256).map { i -> UInt32 in
            var crc = UInt32(i)
            for _ in 0..<8 {
                if crc & 1 == 1 {
                    crc = (crc >> 1) ^ 0xEDB88320
                } else {
                    crc = crc >> 1
                }
            }
            return crc
        }
    }()

    static func calculate(data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = (crc >> 8) ^ table[index]
        }
        return crc ^ 0xFFFFFFFF
    }
}

// MARK: - Data Extensions

extension Data {
    mutating func appendUInt16(_ value: UInt16) {
        var le = value.littleEndian
        append(Data(bytes: &le, count: 2))
    }

    mutating func appendUInt32(_ value: UInt32) {
        var le = value.littleEndian
        append(Data(bytes: &le, count: 4))
    }
}
