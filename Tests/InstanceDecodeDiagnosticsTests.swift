import Testing
import Foundation
import CryptoKit

// Covers the reproducible output of `InstancesStore.decodeFailure(_:)` — the forensics it
// attaches to the breadcrumb when the persisted / iCloud `instances` value won't decode.
// `InstancesStore` is not a member of the host-less Tests target (it pulls in SwiftUI /
// Sentry — the same constraint that makes `InstanceWireFormatTests` a Foundation-only spec),
// so its heal / adopt / reconcile paths can't be driven here. What IS reachable: the `digest`
// field, built with the real `hexEncoded()` helper (`Utilities/Extensions.swift`, shared into
// Tests), and the PII-safety of the `path` / `reason` it reads off the decoder's error.
struct InstanceDecodeDiagnosticsTests {
    // The exact expression `decodeFailure(_:)` uses for its `digest` field.
    private func digest(_ raw: String) -> String {
        String(SHA256.hash(data: Data(raw.utf8)).hexEncoded().prefix(8))
    }

    @Test func digestIsEightLowercaseHexCharacters() {
        let value = digest(#"{"broken": true}"#)
        let isHexOnly = value.allSatisfy(\.isHexDigit)

        #expect(value.count == 8)
        #expect(isHexOnly)
        #expect(value == value.lowercased())
    }

    @Test func digestIsDeterministic() {
        let raw = #"[{"id": "a"}]"#

        #expect(digest(raw) == digest(raw))
    }

    // The same corrupt blob on two devices yields the same digest, so Sentry can tell a
    // shared-schema failure (identical digest everywhere) from per-device storage corruption.
    @Test func digestDistinguishesDifferentPayloads() {
        #expect(digest(#"[{"v": 1}]"#) != digest(#"[{"v": 2}]"#))
    }

    // The digest is a hash, so a secret in the payload never survives into it.
    @Test func digestDoesNotEmbedPayloadContents() {
        let apiKey = "a1b2c3d4e5f60718293a4b5c6d7e8f90"

        #expect(!digest(#"[{"apiKey": "\#(apiKey)"}]"#).contains(apiKey))
    }

    // `path` / `reason` come from the `DecodingError` context — key names, indices and type
    // names, never a stored value. A minimal record (NOT an `Instance` replica) forces the
    // error; the secret sits in the mistyped value, and must not surface in either field.
    private struct Record: Decodable {
        let url: String
    }

    @Test func loggedFieldsCarryNoStoredValues() throws {
        let secret = "5ec4e7-api-key"
        let payload = #"[{"url": {"leak": "\#(secret)"}}]"#

        let context: DecodingError.Context
        do {
            _ = try JSONDecoder().decode([Record].self, from: Data(payload.utf8))
            Issue.record("expected the decode to fail")
            return
        } catch let error as DecodingError {
            switch error {
            case .keyNotFound(_, let ctx), .valueNotFound(_, let ctx), .typeMismatch(_, let ctx): context = ctx
            case .dataCorrupted(let ctx): context = ctx
            @unknown default: context = DecodingError.Context(codingPath: [], debugDescription: "")
            }
        }

        let path = context.codingPath.map(\.stringValue).joined(separator: ".")

        #expect(!path.contains(secret))
        #expect(!context.debugDescription.contains(secret))
    }
}
