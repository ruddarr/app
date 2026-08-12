import Testing
import Foundation

// Covers the `DecodingError` helpers in `Utilities/Decoders.swift` that decide how an API decode
// failure is reported: `isUnexpectedResponseShape` gates whether it reaches Sentry at all,
// `codingPathSignature` is the Sentry fingerprint component, and `codingPathDescription` is what
// the failed-requests diagnostics list shows. All errors here come from a real `JSONDecoder`, so
// the tests pin the decoder's actual behaviour rather than a hand-built approximation.
struct DecodingErrorDiagnosticsTests {
    private struct Item: Decodable {
        let id: Int
        let title: String
        let images: [Image]?
    }

    private struct Image: Decodable {
        let remoteUrl: String
    }

    private func failure<T: Decodable>(_ type: T.Type, _ raw: String) -> DecodingError? {
        do {
            _ = try JSONDecoder().decode(type, from: Data(raw.utf8))
            return nil
        } catch let error as DecodingError {
            return error
        } catch {
            return nil
        }
    }

    // MARK: isUnexpectedResponseShape — a body that isn't shaped like our API at all

    // The canonical proxy/gateway case: an array where the endpoint returns an object.
    @Test func rootTypeMismatchIsUnexpectedShape() throws {
        let error = try #require(failure(Item.self, "[]"))

        #expect(error.context.codingPath.isEmpty)
        #expect(error.isUnexpectedResponseShape)
    }

    // The inverse: an object where a collection endpoint returns an array.
    @Test func rootTypeMismatchOnArrayIsUnexpectedShape() throws {
        let error = try #require(failure([Item].self, #"{"message": "unauthorized"}"#))

        #expect(error.isUnexpectedResponseShape)
    }

    // An HTML login page, a tunnel error page — anything that isn't JSON.
    @Test func rootDataCorruptedIsUnexpectedShape() throws {
        let error = try #require(failure([Item].self, "<html><body>Sign in</body></html>"))

        #expect(error.isUnexpectedResponseShape)
    }

    // A gateway answering `null`: no value where the payload should be.
    @Test func rootValueNotFoundIsUnexpectedShape() throws {
        let error = try #require(failure([Item].self, "null"))

        #expect(error.isUnexpectedResponseShape)
    }

    // Genuine field-level drift must stay reportable — the whole point of the classifier.
    @Test func missingFieldIsNotUnexpectedShape() throws {
        let error = try #require(failure([Item].self, #"[{"id": 1}]"#))

        #expect(!error.isUnexpectedResponseShape)
    }

    @Test func wrongFieldTypeIsNotUnexpectedShape() throws {
        let error = try #require(failure([Item].self, #"[{"id": "one", "title": "A"}]"#))

        #expect(!error.isUnexpectedResponseShape)
    }

    // A top-level key vanishing from an object response is drift, not a foreign body: the payload
    // is still shaped like ours. Only `keyNotFound` is deliberately excluded from the classifier.
    @Test func missingRootKeyIsNotUnexpectedShape() throws {
        let error = try #require(failure(Item.self, #"{"id": 1}"#))

        #expect(error.context.codingPath.isEmpty)
        #expect(!error.isUnexpectedResponseShape)
    }

    // MARK: codingPathSignature — the Sentry fingerprint, stable across items

    // JSONDecoder names array elements "Index 3" / "Index 47", so an unfiltered path would give
    // every drifted row in a library its own Sentry issue. The signature drops them.
    @Test func signatureDropsArrayIndices() throws {
        let third = try #require(failure([Item].self, #"[{"id":1,"title":"A"},{"id":2,"title":"B"},{"id":"x","title":"C"}]"#))
        let first = try #require(failure([Item].self, #"[{"id":"x","title":"C"}]"#))

        #expect(third.codingPathDescription == "Index 2.id")
        #expect(third.codingPathSignature == "id")
        #expect(first.codingPathSignature == third.codingPathSignature)
    }

    @Test func signatureKeepsNestedFieldNames() throws {
        let error = try #require(failure(
            [Item].self,
            #"[{"id":1,"title":"A","images":[{"remoteUrl":7}]}]"#
        ))

        #expect(error.codingPathSignature == "images.remoteUrl")
    }

    // `keyNotFound` carries the missing key as an associated value, not in `context.codingPath`,
    // so without appending it two different missing fields would share one fingerprint.
    @Test func signatureAppendsMissingKey() throws {
        let title = try #require(failure([Item].self, #"[{"id": 1}]"#))
        let id = try #require(failure([Item].self, #"[{"title": "A"}]"#))

        #expect(title.codingPathSignature == "title")
        #expect(id.codingPathSignature == "id")
        #expect(title.codingPathSignature != id.codingPathSignature)
    }

    @Test func signatureIsEmptyForRootFailures() throws {
        let error = try #require(failure([Item].self, "<html>"))

        #expect(error.codingPathSignature.isEmpty)
    }

    // MARK: codingPathDescription — what the diagnostics list shows, indices included

    // The human-facing path keeps the index: it points at the row a user can go inspect.
    @Test func descriptionKeepsArrayIndices() throws {
        let error = try #require(failure(
            [Item].self,
            #"[{"id":1,"title":"A"},{"id":2,"title":"B","images":[{"remoteUrl":7}]}]"#
        ))

        #expect(error.codingPathDescription == "Index 1.images.Index 0.remoteUrl")
    }
}
