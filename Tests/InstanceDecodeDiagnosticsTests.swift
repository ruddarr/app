import Testing
import Foundation
import CryptoKit

// Covers the reproducible, PII-free output of `InstancesStore.decodeFailure(_:)` — the forensics
// it attaches to the breadcrumb when the persisted / iCloud `instances` value won't decode.
// `InstancesStore` is not a member of the host-less Tests target (it pulls in SwiftUI / Sentry —
// the same constraint that makes `InstanceWireFormatTests` a Foundation-only spec), so this can't
// call `decodeFailure` directly. It exercises the reachable pieces: the `digest`, built with the
// real `hexEncoded()` helper (shared into Tests), and the value-free classification the diagnostic
// derives from the decoder's `DecodingError` — never its `debugDescription`, which a raw-value
// enum bakes the rejected value into.
struct InstanceDecodeDiagnosticsTests {
    // MARK: digest — the exact expression `decodeFailure(_:)` uses, via the real helper

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

    // MARK: classification — value-free, mirrors `InstancesStore.describe(_:)`

    // A raw-value enum, like `Instance.type`: its decode failure is `dataCorrupted` whose
    // debugDescription embeds the rejected value — the exact leak the diagnostic must avoid.
    // NOT an `Instance` replica.
    private enum Category: String, Decodable { case radarr, sonarr }
    private struct Record: Decodable { let category: Category }

    private func failure(_ raw: String) -> DecodingError? {
        do {
            _ = try JSONDecoder().decode([Record].self, from: Data(raw.utf8))
            return nil
        } catch let error as DecodingError {
            return error
        } catch {
            return nil
        }
    }

    private func context(_ error: DecodingError) -> DecodingError.Context {
        switch error {
        case .keyNotFound(_, let ctx), .valueNotFound(_, let ctx), .typeMismatch(_, let ctx): return ctx
        case .dataCorrupted(let ctx): return ctx
        @unknown default: return DecodingError.Context(codingPath: [], debugDescription: "")
        }
    }

    private func classify(_ error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, _): return "keyNotFound(\(key.stringValue))"
        case .typeMismatch(let type, _): return "typeMismatch(\(type))"
        case .valueNotFound(let type, _): return "valueNotFound(\(type))"
        case .dataCorrupted: return "dataCorrupted"
        @unknown default: return "unknown"
        }
    }

    // The hazard, made explicit: `debugDescription` DOES carry the rejected value. This is what
    // the diagnostic's old `reason` field surfaced, and why it is no longer logged.
    @Test func debugDescriptionExposesTheRejectedValue() throws {
        let error = try #require(failure(#"[{"category": "5ec4e7-api-key"}]"#))

        #expect(context(error).debugDescription.contains("5ec4e7-api-key"))
    }

    // The fix: the fields the diagnostic actually emits — `kind` and `path` — never carry a
    // stored value, for the raw-enum leak vector or a plain type mismatch.
    @Test(arguments: [
        #"[{"category": "5ec4e7-api-key"}]"#,
        #"[{"category": {"leak": "5ec4e7-api-key"}}]"#,
    ])
    func emittedFieldsOmitStoredValues(_ payload: String) throws {
        let error = try #require(failure(payload))

        let kind = classify(error)
        let path = context(error).codingPath.map(\.stringValue).joined(separator: ".")

        #expect(!kind.contains("5ec4e7-api-key"))
        #expect(!path.contains("5ec4e7-api-key"))
    }

    // Still useful: a missing key is localized by its schema name, never a value.
    @Test func classificationNamesTheSchemaKey() throws {
        let error = try #require(failure(#"[{}]"#))

        #expect(classify(error) == "keyNotFound(category)")
    }
}
