import Foundation
import CoreFoundation

struct ImportedText {
    let text: String
    let encodingName: String
    let droppedControls: Int
}

enum ArchiveDecoder {
    enum DecodeFailure: LocalizedError {
        case empty, tooLarge, binary, undecodable
        var errorDescription: String? {
            switch self {
            case .empty: return "내용이 없는 파일입니다."
            case .tooLarge: return "파일이 100MB를 초과합니다. 큰 파일은 나누어 가져와 주세요."
            case .binary: return "PDF·이미지·압축파일 등 텍스트가 아닌 자료로 보입니다."
            case .undecodable: return "텍스트 인코딩을 해석할 수 없습니다. UTF-8이나 CP949인지 확인해 주세요."
            }
        }
    }

    static func read(_ data: Data) throws -> ImportedText {
        guard !data.isEmpty else { throw DecodeFailure.empty }
        guard data.count <= 100 * 1024 * 1024 else { throw DecodeFailure.tooLarge }
        let bytes = [UInt8](data.prefix(8192))
        let magic: [[UInt8]] = [
            [0x25, 0x50, 0x44, 0x46], // PDF
            [0x89, 0x50, 0x4e, 0x47], // PNG
            [0xff, 0xd8, 0xff],       // JPEG
            [0x50, 0x4b, 0x03, 0x04], // ZIP
            [0x7f, 0x45, 0x4c, 0x46]  // executable
        ]
        if magic.contains(where: { bytes.starts(with: $0) }) { throw DecodeFailure.binary }
        var decoded: String?
        var encoding = ""
        if bytes.starts(with: [0xef, 0xbb, 0xbf]) {
            decoded = String(data: data.dropFirst(3), encoding: .utf8); encoding = "UTF-8 BOM"
        } else if bytes.starts(with: [0xff, 0xfe]) {
            decoded = String(data: data, encoding: .utf16LittleEndian); encoding = "UTF-16 LE"
        } else if bytes.starts(with: [0xfe, 0xff]) {
            decoded = String(data: data, encoding: .utf16BigEndian); encoding = "UTF-16 BE"
        } else {
            let evenNul = stride(from: 0, to: bytes.count, by: 2).reduce(0) { $0 + (bytes[$1] == 0 ? 1 : 0) }
            let oddNul = stride(from: 1, to: bytes.count, by: 2).reduce(0) { $0 + (bytes[$1] == 0 ? 1 : 0) }
            let slots = max(1, bytes.count / 2)
            if Double(oddNul) / Double(slots) > 0.28 && evenNul < slots / 10 {
                decoded = String(data: data, encoding: .utf16LittleEndian); encoding = "UTF-16 LE (BOM 없음)"
            } else if Double(evenNul) / Double(slots) > 0.28 && oddNul < slots / 10 {
                decoded = String(data: data, encoding: .utf16BigEndian); encoding = "UTF-16 BE (BOM 없음)"
            } else {
                decoded = String(data: data, encoding: .utf8)
                if decoded != nil { encoding = "UTF-8" }
                if decoded == nil {
                    let korean = CFStringConvertIANACharSetNameToEncoding(CFStringCreateWithCString(kCFAllocatorDefault, "windows-949", CFStringBuiltInEncodings.UTF8.rawValue))
                    if korean != kCFStringEncodingInvalidId {
                        let nsEncoding = CFStringConvertEncodingToNSStringEncoding(korean)
                        decoded = String(data: data, encoding: String.Encoding(rawValue: nsEncoding))
                        if decoded != nil { encoding = "CP949" }
                    }
                }
                if decoded == nil {
                    let korean = CFStringConvertIANACharSetNameToEncoding(CFStringCreateWithCString(kCFAllocatorDefault, "EUC-KR", CFStringBuiltInEncodings.UTF8.rawValue))
                    if korean != kCFStringEncodingInvalidId {
                        decoded = String(data: data, encoding: String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(korean)))
                        if decoded != nil { encoding = "EUC-KR" }
                    }
                }
            }
        }
        guard let text = decoded, !text.isEmpty else { throw DecodeFailure.undecodable }
        let scalars = text.unicodeScalars
        let invalid = scalars.filter { $0.value == 0 || ($0.value < 32 && $0 != "\n" && $0 != "\r" && $0 != "\t") }
        if Double(invalid.count) / Double(max(1, scalars.count)) > 0.03 { throw DecodeFailure.binary }
        let clean = String(String.UnicodeScalarView(scalars.filter {
            $0.value != 0 && ($0.value >= 32 || $0 == "\n" || $0 == "\r" || $0 == "\t")
        }))
        return ImportedText(text: clean, encodingName: encoding, droppedControls: invalid.count)
    }
}
