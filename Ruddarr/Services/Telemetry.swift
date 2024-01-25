import os
import SwiftUI
import CloudKit

class Telemetry {
    static let shared: Telemetry = Telemetry()
    private let log: Logger = logger("telemetry")

    private let container: CKContainer
    private let database: CKDatabase
    private var accountStatus: CKAccountStatus?

    enum Meta: String {
        case appVersion
        case appBuild
        case systemVersion
        case systemName
        case deviceId
        case cloudkitStatus
        case cloudkitUserId
    }

    init() {
        container = CKContainer.default()
        database = container.publicCloudDatabase

        CKContainer.default().accountStatus { status, error in
            if let error = error {
                self.log.error("Failed to determine CloudKit account status: \(error.localizedDescription)")
            } else {
                self.accountStatus = status
            }
        }
    }

    func metadata() async -> [Meta: String] {
        var data = [Meta: String]()

        data[.systemName] = await UIDevice.current.systemName
        data[.systemVersion] = await UIDevice.current.systemVersion

        if let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
            data[.appBuild] = buildNumber
        }

        if let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            data[.appVersion] = appVersion
        }

        if let deviceId = await UIDevice.current.identifierForVendor?.uuidString {
            data[.deviceId] = deviceId
        }

        data[.cloudkitStatus] = accountStatusString()

        if let userRecordId = try? await container.userRecordID() {
            data[.cloudkitUserId] = userRecordId.recordName
        }

        return data
    }

    func maybeUploadTelemetry() {
        let key = "lastTelemetryDate"
        var lastTelemetryDate: Date

        if let storedDate = UserDefaults.standard.object(forKey: key) as? Date {
            lastTelemetryDate = storedDate
        } else {
            lastTelemetryDate = Calendar.current.date(byAdding: .hour, value: -24, to: Date())!
        }

        #if DEBUG
        lastTelemetryDate = Calendar.current.date(byAdding: .hour, value: -24, to: Date())!
        #endif

        let hoursSincePing = Calendar.current.dateComponents([.hour], from: lastTelemetryDate, to: Date()).hour

        guard hoursSincePing! > 12 else {
            return
        }

        Task(priority: .background) {
            do {
                try await uploadTelemetryData()
                UserDefaults.standard.set(Date(), forKey: key)
            } catch {
                self.log.error("Telemetry upload failed: \(error, privacy: .public)")
            }
        }
    }

    private func uploadTelemetryData() async throws {
        let metadata = await metadata()

        guard let deviceId = metadata[.deviceId] else {
            return self.log.notice("No device identifier")
        }

        guard accountStatus == .available else {
            return self.log.notice("iCloud account not available: \(self.accountStatusString(), privacy: .public)")
        }

        guard let record = await fetchOrCreateRecord(CKRecord.ID(recordName: deviceId)) else {
            return
        }

        if let userId = metadata[.cloudkitUserId] {
            record["user"] = CKRecord.Reference(recordID: CKRecord.ID(recordName: userId), action: .none)
        }

        for (key, value) in metadata {
            guard [.deviceId, .cloudkitStatus, .cloudkitUserId].contains(key) else { return }
            record.setValue(value, forKey: key.rawValue)
        }

        try await database.save(record)
    }

    private func fetchOrCreateRecord(_ recordId: CKRecord.ID) async -> CKRecord? {
        do {
            return try await database.record(for: recordId)
        } catch CKError.unknownItem {
            return CKRecord(recordType: "Telemetry", recordID: recordId)
        } catch {
            self.log.warning("Failed to retrieve Telemetry record: \(error, privacy: .public)")
        }

        return nil
    }

    private func accountStatusString() -> String {
        switch accountStatus {
        case .couldNotDetermine: "couldNotDetermine"
        case .available: "available"
        case .restricted: "restricted"
        case .noAccount: "noAccount"
        case .temporarilyUnavailable: "temporarilyUnavailable"
        case .none: "nil"
        @unknown default: "unknown"
        }
    }
}
