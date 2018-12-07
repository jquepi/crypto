import ASN1

extension Extension {
    public struct BasicConstrains: Equatable {
        public let isCA: Bool
        public let pathLen: Int?

        public init(
            isCA: Bool = false,
            pathLen: Int? = nil)
        {
            self.isCA = isCA
            self.pathLen = pathLen
        }
    }
}

// MARK: Coding - https://tools.ietf.org/html/rfc5280#section-4.2.1.9

extension Extension.BasicConstrains {
    public init(from asn1: ASN1) throws {
        guard let sequence = asn1.sequenceValue,
            // TODO: test
            sequence.count <= 2 else
        {
            throw X509.Error.invalidASN1(asn1, in: .basicConstrains(.format))
        }

        // DEFAULT FALSE
        if sequence.count >= 1 {
            guard let isCA = sequence[0].booleanValue else {
                throw X509.Error.invalidASN1(asn1, in: .basicConstrains(.isCA))
            }
            self.isCA = isCA
        } else {
            self.isCA = false
        }

        // OPTIONAL
        if sequence.count == 2 {
            guard let pathLen = sequence[1].integerValue else {
                throw X509.Error.invalidASN1(asn1, in: .basicConstrains(.pathLen))
            }
            self.pathLen = pathLen
        } else {
            self.pathLen = nil
        }
    }
}

// MARK: Error

extension Extension.BasicConstrains {
    public enum Error {
        public enum Origin {
            case format
            case isCA
            case pathLen
        }
    }
}
