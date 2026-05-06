
import Foundation

enum MultipartFormDataBuilder {
    static func write(
        fields: [String: String],
        files: [MultipartFile],
        boundary: String,
        to destinationURL: URL
    ) throws {
        try validateHeaderMetadata(fields: fields, files: files, boundary: boundary)

        FileManager.default.createFile(atPath: destinationURL.path, contents: nil)
        let output = try FileHandle(forWritingTo: destinationURL)

        do {
            for key in fields.keys.sorted() {
                guard let value = fields[key] else { continue }
                try output.writeString("--\(boundary)\r\n")
                try output.writeString("Content-Disposition: form-data; name=\"\(escape(key))\"\r\n\r\n")
                try output.writeString("\(value)\r\n")
            }

            for file in files {
                try output.writeString("--\(boundary)\r\n")
                try output.writeString(
                    "Content-Disposition: form-data; name=\"\(escape(file.fieldName))\"; filename=\"\(escape(file.fileName))\"\r\n"
                )
                try output.writeString("Content-Type: \(file.contentType)\r\n\r\n")
                try copyFile(at: file.fileURL, to: output)
                try output.writeString("\r\n")
            }

            try output.writeString("--\(boundary)--\r\n")
            try output.close()
        } catch {
            try? output.close()
            throw error
        }
    }

    private static func copyFile(at fileURL: URL, to output: FileHandle) throws {
        let input = try FileHandle(forReadingFrom: fileURL)

        do {
            while true {
                try Task.checkCancellation()
                guard let chunk = try input.read(upToCount: 64 * 1024), !chunk.isEmpty else { break }
                try output.write(contentsOf: chunk)
            }
            try input.close()
        } catch {
            try? input.close()
            throw error
        }
    }

    private static func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static func validateHeaderMetadata(
        fields: [String: String],
        files: [MultipartFile],
        boundary: String
    ) throws {
        try validateHeaderMetadataValue(boundary, name: "multipart boundary")

        for fieldName in fields.keys {
            try validateHeaderMetadataValue(fieldName, name: "multipart field name")
        }

        for file in files {
            try validateHeaderMetadataValue(file.fieldName, name: "multipart file field name")
            try validateHeaderMetadataValue(file.fileName, name: "multipart file name")
            try validateHeaderMetadataValue(file.contentType, name: "multipart file content type")
        }
    }

    private static func validateHeaderMetadataValue(_ value: String, name: String) throws {
        let containsControlCharacter = value.unicodeScalars.contains { scalar in
            scalar.value < 0x20 || scalar.value == 0x7F
        }
        guard !containsControlCharacter else {
            throw NetworkError.requestFailed("Invalid \(name): control characters are not allowed")
        }
    }
}

private extension FileHandle {
    func writeString(_ string: String) throws {
        try write(contentsOf: Data(string.utf8))
    }
}
