import ASN1
import Stream

extension TBSCertificate {
    public struct Extension: Equatable {
        var id: ASN1.ObjectIdentifier
        var isCritical: Bool
        var value: Variant

        enum Variant: Equatable {
        // id-ce-*
        case subjectKeyIdentifier(SubjectKeyIdentifier)
        case keyUsage(KeyUsage)
        case basicConstrains(BasicConstrains)
        case crlDistributionPoints(CRLDistributionPoints)
        case authorityKeyIdentifier(AuthorityKeyIdentifier)
        // id-pe-*
        case authorityInfoAccessMethod(AuthorityInfoAccess)
        }
    }
}

// https://tools.ietf.org/html/rfc5280#section-4.2

extension Array where Element == TBSCertificate.Extension {
    // Extensions  ::=  SEQUENCE SIZE (1..MAX) OF Extension
    public init(from asn1: ASN1) throws {
        guard let contextSpecific = asn1.sequenceValue,
            let container = contextSpecific.first,
            let sequence = container.sequenceValue else
        {
            throw X509.Error(.invalidExtensions, asn1)
        }
        self = try sequence.map(TBSCertificate.Extension.init)
    }
}

extension TBSCertificate.Extension {
    // Extension  ::=  SEQUENCE  {
    //   extnID      OBJECT IDENTIFIER,
    //   critical    BOOLEAN DEFAULT FALSE,
    //   extnValue   OCTET STRING
    //               -- contains the DER encoding of an ASN.1 value
    //               -- corresponding to the extension type identified
    //               -- by extnID
    //   }
    public init(from asn1: ASN1) throws {
        guard let values = asn1.sequenceValue,
            values.count >= 2 && values.count <= 3,
            let id = values[0].objectIdentifierValue else
        {
            throw X509.Error(.invalidExtension, asn1)
        }

        self.id = id

        if values.count == 2 {
            self.isCritical = false
        } else  {
            guard let isCritical = values[1].booleanValue else {
                throw X509.Error(.invalidExtension, asn1)
            }
            self.isCritical = isCritical
        }

        guard let bytes = values.last?.dataValue else {
            throw X509.Error(.invalidExtension, asn1)
        }
        let value = try ASN1(from: bytes)

        switch id {
        case .certificateExtension(.some(.subjectKeyIdentifier)):
            self.value = .subjectKeyIdentifier(try .init(from: value))
        case .certificateExtension(.some(.keyUsage)):
            self.value = .keyUsage(try .init(from: value))
        case .certificateExtension(.some(.basicConstrains)):
            self.value = .basicConstrains(try .init(from: value))
        case .certificateExtension(.some(.crlDistributionPoints)):
            self.value = .crlDistributionPoints(try .init(from: value))
        case .certificateExtension(.some(.authorityKeyIdentifier)):
            self.value = .authorityKeyIdentifier(try .init(from: value))
        case .pkix(.some(.extension(.authorityInfoAccessSyntax))):
            self.value = .authorityInfoAccessMethod(try .init(from: value))
        default:
            throw X509.Error(.unimplementedExtension, asn1)
        }
    }
}