import Foundation

extension InstanceAPI {
    static var live: Self {
        .init(command: { command, instance in
            let url = try await instance.apiURL("command")

            return try await API.request(method: .post, url: url, body: command.payload, instance: instance)
        }, downloadRelease: { payload, instance in
            let url = try await instance.apiURL("release")

            return try await API.request(method: .post, url: url, body: payload, instance: instance, timeout: .sluggish)
        }, status: { instance in
            let url = try await instance.apiURL("system/status")

            return try await API.request(url: url, instance: instance)
        }, rootFolders: { instance in
            let url = try await instance.apiURL("rootfolder")

            return try await API.request(url: url, instance: instance, timeout: .slow)
        }, qualityProfiles: { instance in
            let url = try await instance.apiURL("qualityprofile")

            return try await API.request(url: url, instance: instance)
        }, diskSpace: { instance in
            let url = try await instance.apiURL("diskspace")

            return try await API.request(url: url, instance: instance)
        }, tags: { instance in
            let url = try await instance.apiURL("tag")

            return try await API.request(url: url, instance: instance)
        }, queue: { instance in
            let url = try await instance.apiURL("queue")
                .appending(queryItems: [
                    .init(name: "includeMovie", value: "true"),
                    .init(name: "includeSeries", value: "true"),
                    .init(name: "includeEpisode", value: "true"),
                    .init(name: "pageSize", value: "250"),
                ])

            var items: QueueItems = try await API.request(url: url, instance: instance)
            items.records.stamp(instance.id)
            return items
        }, deleteQueueTask: { task, remove, block, search, instance in
            let url = try await instance.apiURL("queue")
                .appending(path: String(task))
                .appending(queryItems: [
                    .init(name: "removeFromClient", value: remove ? "true" : "false"),
                    .init(name: "blocklist", value: block ? "true" : "false"),
                    .init(name: "skipRedownload", value: search ? "false" : "true"),
                ])

            return try await API.request(method: .delete, url: url, instance: instance)
        }, importableFiles: { downloadId, instance in
            let url = try await instance.apiURL("manualimport")
                .appending(queryItems: [
                    .init(name: "downloadId", value: downloadId),
                    .init(name: "filterExistingFiles", value: "false"),
                ])

            return try await API.request(url: url, instance: instance, timeout: .sluggish)
        }, history: { type, page, limit, instance in
            var url = try await instance.apiURL("history")
                .appending(queryItems: [
                    .init(name: "page", value: String(page)),
                    .init(name: "pageSize", value: String(limit)),
                ])

            if let type {
                url = url.appending(queryItems: [.init(name: "eventType", value: String(type))])
            }

            var history: MediaHistory = try await API.request(url: url, instance: instance)
            history.records.stamp(instance.id)
            return history
        }, notifications: { instance in
            let url = try await instance.apiURL("notification")

            return try await API.request(url: url, instance: instance)
        }, createNotification: { model, instance in
            let url = try await instance.apiURL("notification")

            return try await API.request(method: .post, url: url, body: model, instance: instance)
        }, updateNotification: { model, instance in
            let url = try await instance.apiURL("notification")
                .appending(path: String(model.id ?? 0))

            return try await API.request(method: .put, url: url, body: model, instance: instance)
        }, deleteNotification: { model, instance in
            let url = try await instance.apiURL("notification")
                .appending(path: String(model.id ?? 0))

            return try await API.request(method: .delete, url: url, instance: instance)
        })
    }
}
