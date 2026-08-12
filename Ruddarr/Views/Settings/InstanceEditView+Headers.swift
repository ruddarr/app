import SwiftUI

extension InstanceEditView {
    var headersSection: some View {
        Section {
            ForEach($instance.headers.indices, id: \.self) { index in
                InstanceHeaderRow(header: $instance.headers[index])
                    .swipeActions {
                        Button("Delete") {
                            instance.headers.remove(at: index)
                        }
                        .tint(.red)
                    }
            }

            Button {
                instance.headers.append(InstanceHeader())
            } label: {
                Text("Add Header", comment: "Add HTTP Header to instance")
            }
            #if os(macOS)
                .buttonStyle(.link)
                .foregroundStyle(settings.theme.tint)
            #endif

            Button {
                showBasicAuthentication = true
            } label: {
                Text("Add Authentication", comment: "Add Basic HTTP Authentication to instance")
            }
            #if os(macOS)
                .buttonStyle(.link)
                .foregroundStyle(settings.theme.tint)
            #endif
        } header: {
            HStack {
                Text("Headers", comment: "HTTP Headers")
                Spacer()
                pasteButton(pasteHeader)
            }
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                Text("Custom Headers can be used to access instances protected by Zero Trust services.")
                Text("Basic Authentication is for advanced server management tools and will not work with regular \(instance.type.rawValue) login credentials.")
            }
            #if os(macOS)
            .foregroundStyle(.secondary)
            .font(.footnote)
            #endif
        }
    }

    func pasteButton(_ callback: @escaping () -> Void) -> some View {
        #if os(macOS)
            EmptyView()
        #else
            Button(String(localized: "Paste", comment: "Paste from clipboard"), action: callback)
                .buttonStyle(.plain)
                .foregroundStyle(settings.theme.tint)
        #endif
    }

    func pasteHeader() {
        #if os(macOS)
            let string = ""
        #else
            guard let string = UIPasteboard.general.string else { return }
        #endif

        let lines = string.components(separatedBy: .newlines)

        for line in lines {
            if line.contains(":") {
                createHeader(from: line)
            } else {
                appendHeader(from: line)
            }
        }
    }

    func createHeader(from line: String) {
        let components = line.components(separatedBy: ":")

        instance.headers.append(InstanceHeader(
            name: components[0],
            value: components[1]
        ))
    }

    func appendHeader(from value: String) {
        if var header = instance.headers.last {
            let index = instance.headers.count - 1

            if header.name.isEmpty {
                header.name = value
                instance.headers[index] = header
            } else if header.value.isEmpty {
                header.value = value
                instance.headers[index] = header
            } else {
                instance.headers.append(InstanceHeader(name: value, value: ""))
            }
        } else {
            instance.headers.append(InstanceHeader(name: value, value: ""))
        }
    }
}

struct InstanceHeaderRow: View {
    @Binding var header: InstanceHeader

    var body: some View {
        VStack {
            TextField("Header name", text: $header.name)
            .autocorrectionDisabled(true)
            #if os(iOS)
                .textInputAutocapitalization(.never)
            #endif

            TextField("Header value", text: $header.value)
            .autocorrectionDisabled(true)
            #if os(iOS)
                .textInputAutocapitalization(.never)
            #endif
        }
    }
}

#Preview {
    dependencies.router.selectedTab = .settings

    dependencies.router.settingsPath.append(
        SettingsView.Path.createInstance
    )

    return ContentView()
        .withAppState()
        .macPreviewFrame()
}
