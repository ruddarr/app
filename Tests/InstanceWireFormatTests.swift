import Testing
import Foundation

// Locks the cross-version wire format of the `instances` value that syncs through
// `NSUbiquitousKeyValueStore` (key "instances", or "debugInstances" in DEBUG).
//
// WHY THIS EXISTS: `@CloudStorage` builds shipped before #698 remain installed in
// the field and are *writers* to the same iCloud value. They decode it strictly:
// `string(forKey:).flatMap([Instance].init(rawValue:)) ?? []`. If a schema change
// makes the stored JSON undecodable by those builds, they silently read `[]` and —
// the moment the user touches instances on that device — write `[]` back to iCloud,
// wiping every device. See the "BE CAREFUL CHANGING" note in `Instance.swift` and
// the adoption logic in `InstancesStore`.
//
// The fixtures below freeze a payload exactly as a shipped build persists it. The
// asserted keys are the ones `Instance.init(from:)` decodes with non-optional
// `decode(...)` — the set whose removal, rename, or retype breaks in-field builds.
// `tags`, `name`, `version`, and `stats` are decoded optionally and may be absent.
//
// CONTRACT: do not edit a fixture just to make a failing build pass. A change here
// means the wire format changed — and that change must be additive (new keys read
// with `decodeIfPresent` + a default) or gated behind a migration that keeps old
// builds readable. This is a structural spec (Foundation only); the host-less test
// target can't link `Instance.swift` without its full dependency graph, so keep
// these fixtures in lockstep with `Instance.init(from:)`.
struct InstanceWireFormatTests {
    // Two instances as written by a shipped `@CloudStorage` build: a Radarr in
    // `.normal` mode and a Sonarr in `.slow` mode.
    private let goldenPayload = """
    [
      {
        "id": "6C7E1B2A-1111-2222-3333-444455556666",
        "type": "Radarr",
        "mode": { "normal": {} },
        "label": "Home",
        "url": "https://radarr.example.com",
        "apiKey": "a1b2c3d4e5f60718293a4b5c6d7e8f90",
        "headers": [
          { "id": "0A1B2C3D-0001-0002-0003-000400050006", "name": "X-Proxy", "value": "ruddarr" }
        ],
        "rootFolders": [
          { "id": 1, "accessible": true, "path": "/volume1/Movies", "freeSpace": 1000000000000 }
        ],
        "qualityProfiles": [
          { "id": 1, "name": "HD-1080p" }
        ],
        "tags": [],
        "name": "Radarr (Home)",
        "version": "5.14.0.9383",
        "stats": { "movies": 1234, "series": 0, "episodes": 0, "size": 987654321000 }
      },
      {
        "id": "7D8E2F3A-2222-3333-4444-555566667777",
        "type": "Sonarr",
        "mode": { "slow": {} },
        "label": "Seedbox",
        "url": "https://sonarr.example.com",
        "apiKey": "112233445566778899aabbccddeeff00",
        "headers": [],
        "rootFolders": [
          { "id": 1, "accessible": true, "path": "/volume1/TV", "freeSpace": 2000000000000 }
        ],
        "qualityProfiles": [
          { "id": 2, "name": "WEB-1080p" }
        ],
        "tags": []
      }
    ]
    """

    // The minimum a shipped build needs to decode an instance: every non-optional
    // key in `Instance.init(from:)`, and nothing else.
    private let minimalPayload = """
    [
      {
        "id": "00112233-4455-6677-8899-AABBCCDDEEFF",
        "type": "Radarr",
        "mode": { "normal": {} },
        "label": "",
        "url": "https://example.com",
        "apiKey": "key",
        "headers": [],
        "rootFolders": [],
        "qualityProfiles": []
      }
    ]
    """

    // Keys `Instance.init(from:)` reads with non-optional `decode(...)`.
    private let requiredKeys = [
        "id", "type", "mode", "label", "url", "apiKey",
        "headers", "rootFolders", "qualityProfiles",
    ]

    private func instances(_ json: String) throws -> [[String: Any]] {
        let object = try JSONSerialization.jsonObject(with: Data(json.utf8))
        return try #require(object as? [[String: Any]])
    }

    @Test func goldenPayloadParsesAsInstanceArray() throws {
        let parsed = try instances(goldenPayload)
        #expect(parsed.count == 2)
    }

    @Test func everyInstanceCarriesRequiredKeysWithExpectedTypes() throws {
        for instance in try instances(goldenPayload) {
            for key in requiredKeys {
                #expect(instance[key] != nil, "missing required key: \(key)")
            }

            let id = try #require(instance["id"] as? String)
            #expect(UUID(uuidString: id) != nil, "id is not a UUID string: \(id)")

            let type = try #require(instance["type"] as? String)
            #expect(["Radarr", "Sonarr"].contains(type), "unexpected type: \(type)")

            #expect(instance["label"] as? String != nil)
            #expect(instance["url"] as? String != nil)
            #expect(instance["apiKey"] as? String != nil)
            #expect(instance["headers"] as? [Any] != nil)
            #expect(instance["rootFolders"] as? [Any] != nil)
            #expect(instance["qualityProfiles"] as? [Any] != nil)
        }
    }

    // `InstanceMode` is a Swift-synthesized enum (SE-0295): a case with no
    // associated values serializes as a single-key object like {"normal":{}}, NOT
    // a bare string. Giving `InstanceMode` a raw value would silently change this
    // to "normal" and break every in-field `@CloudStorage` decoder. Pin the shape.
    @Test func modeIsASingleKeyObjectNotAString() throws {
        let knownCases = ["normal", "slow", "large"]

        for instance in try instances(goldenPayload) {
            #expect(instance["mode"] as? String == nil, "mode must not be a bare string")

            let mode = try #require(instance["mode"] as? [String: Any])
            #expect(mode.count == 1, "mode must encode exactly one case")

            let caseName = try #require(mode.keys.first)
            #expect(knownCases.contains(caseName), "unknown mode case: \(caseName)")
            #expect(mode[caseName] as? [String: Any] != nil, "mode case payload must be an object")
        }
    }

    @Test func minimalPayloadCarriesEveryRequiredKey() throws {
        let parsed = try instances(minimalPayload)
        #expect(parsed.count == 1)

        let instance = try #require(parsed.first)
        for key in requiredKeys {
            #expect(instance[key] != nil, "missing required key: \(key)")
        }
    }
}
