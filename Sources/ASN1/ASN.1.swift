import Stream

public struct ASN1: Equatable, Sendable {
    public var identifier: Identifier
    public var content: Content

    public init(identifier: Identifier, content: Content) {
        self.identifier = identifier
        self.content = content
    }

    public enum Integer: Equatable, Sendable {
        case sane(Int)
        // FIXME [Concurrency] compiler crash
        // case insane([UInt8])

        // workaround:
        case insane(Storage)
        public struct Storage: Equatable, ExpressibleByArrayLiteral, Sendable {
            let value: UInt2056
            let size: Int

            struct UInt128: Equatable, Sendable {
                let high: UInt64 = .init()
                let low: UInt64 = .init()
            }
            struct UInt256: Equatable, Sendable {
                let high: UInt128 = .init()
                let low: UInt128 = .init()
            }
            struct UInt512: Equatable, Sendable {
                let high: UInt256 = .init()
                let low: UInt256 = .init()
            }
            struct UInt1024: Equatable, Sendable {
                let high: UInt512 = .init()
                let low: UInt512 = .init()
            }
            struct UInt2048: Equatable, Sendable {
                let high: UInt1024 = .init()
                let low: UInt1024 = .init()
            }
            public struct UInt2056: Equatable, Sendable {
                let bytes: UInt2048 = .init()
                let byte: UInt8 = .init()
            }

            public var bytes: [UInt8] {
                withUnsafeBytes(of: value) { bytes in
                    .init(bytes.prefix(size))
                }
            }

            init(_ bytes: [UInt8]) {
                guard bytes.count <= MemoryLayout<UInt2056>.size else {
                    fatalError("unsupported .insane value size")
                }
                var value = UInt2056()
                withUnsafeMutableBytes(of: &value) { buffer in
                    buffer.copyBytes(from: bytes)
                }
                self.value = value
                self.size = bytes.count
            }

            public typealias ArrayLiteralElement = UInt8
            public init(arrayLiteral elements: UInt8...) {
                self = .init([UInt8](elements))
            }
        }
    }

    public enum Content: Equatable, Sendable {
        case boolean(Bool)
        case integer(Integer)
        case string(String)
        case data([UInt8])
        case sequence([ASN1])
        case objectIdentifier(ObjectIdentifier)
    }

    public struct Identifier: Equatable, Sendable {
        public var isConstructed: Bool
        public var `class`: Class
        public var tag: Tag

        public init(isConstructed: Bool, class: Class, tag: Tag) {
            self.isConstructed = isConstructed
            self.class = `class`
            self.tag = tag
        }

        public enum Class: UInt8, Sendable {
            case universal = 0b00
            case application = 0b01
            case contextSpecific = 0b10
            case `private` = 0b11
        }

        public enum Tag: UInt8, Sendable {
            case endOfContent = 0x00
            case boolean = 0x01
            case integer = 0x02
            case bitString = 0x03
            case octetString = 0x04
            case null = 0x05
            case objectIdentifier = 0x06
            case objectDescriptor = 0x07
            case instanceOfExternal = 0x08
            case real = 0x09
            case enumerated = 0x0a
            case embeddedPPV = 0x0b
            case utf8String = 0x0c
            case relativeOID = 0x0d
            // 0x0e & 0x0f undefined
            case sequence = 0x10
            case set = 0x11
            case numericString = 0x12
            case printableString = 0x13
            case teletexString = 0x14
            case videotexString = 0x15
            case ia5String = 0x16
            case utcTime = 0x17
            case generalizedTime = 0x18
            case graphicString = 0x19
            case visibleString = 0x1a
            case generalString = 0x1b
            case universalString = 0x1c
            case characterString = 0x1d
            case bmpString = 0x1e
        }
    }
}

extension ASN1 {
    public var isConstructed: Bool {
        return identifier.isConstructed
    }

    public var `class`: ASN1.Identifier.Class {
        return identifier.class
    }

    public var tag: ASN1.Identifier.Tag {
        return identifier.tag
    }

    public var booleanValue: Bool? {
        switch self.content {
        case .boolean(let value): return value
        default: return nil
        }
    }

    public var integerValue: Int? {
        switch self.content {
        case .integer(.sane(let value)): return value
        default: return nil
        }
    }

    public var insaneIntegerValue: [UInt8]? {
        switch self.content {
        // FIXME: [Concurrency] compiler crash
        // case .integer(.insane(let value)): return value
        case .integer(.insane(let value)): return value.bytes
        default: return nil
        }
    }

    public var stringValue: String? {
        switch self.content {
        case .string(let value):
            return value
        case .data(let bytes) where tag.isString:
            return String(decoding: bytes, as: UTF8.self)
        default:
            return nil
        }
    }

    public var dataValue: [UInt8]? {
        switch self.content {
        case .data(let value): return value
        default: return nil
        }
    }

    public var sequenceValue: [ASN1]? {
        switch self.content {
        case .sequence(let value): return value
        default: return nil
        }
    }

    public var objectIdentifierValue: ASN1.ObjectIdentifier? {
        switch self.content {
        case .objectIdentifier(let value) where tag == .objectIdentifier:
            return value
        default:
            return nil
        }
    }

    public var setValue: [ASN1]? {
        guard tag == .set else {
            return nil
        }
        return sequenceValue
    }

    /// String value encoded as ObjectIdentifier
    public var stringIdentifierValue: String? {
        guard let oid = objectIdentifierValue,
            case .other(let data) = oid else {
                return nil
        }
        return String(decoding: data, as: UTF8.self)
    }
}

extension ASN1.Identifier.Tag {
    var isString: Bool {
        switch self {
        // TODO: handle all cases (graphicString, teletexString etc.)
        case .ia5String, .visibleString, .printableString: return true
        default: return false
        }
    }
}
