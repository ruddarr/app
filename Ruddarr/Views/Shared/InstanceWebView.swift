import SwiftUI
import WebKit

struct InstanceWebView: View {
    var instance: Instance
    var path: String = ""

    @State private var page: WebPage

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    init(instance: Instance, path: String = "") {
        self.instance = instance
        self.path = path

        var configuration = WebPage.Configuration()
        configuration.websiteDataStore = .default() // persists logins, erased by `clearWebsiteData()`

        self._page = State(initialValue: WebPage(configuration: configuration))
    }

    var body: some View {
        NavigationStack {
            WebView(page)
                .overlay {
                    if page.isLoading && page.url == nil {
                        Loading()
                    }
                }
                .navigationTitle(instance.label)
                .safeNavigationBarTitleDisplayMode(.inline)
                .toolbar {
                    toolbarButtons
                }
        }
        .task {
            await load()
        }
        #if os(macOS)
            .frame(minWidth: 800, minHeight: 500)
        #endif
    }

    @ToolbarContentBuilder
    var toolbarButtons: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
            }
            .tint(.primary)
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                if let url = page.url ?? URL(string: instance.url) {
                    openURL(url)
                }
            } label: {
                Image(systemName: "safari")
            }
            .tint(.primary)
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                page.reload()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .tint(.primary)
        }
    }

    func load() async {
        guard page.url == nil else { return }
        guard let baseURL = (try? await instance.baseURL()) ?? URL(string: instance.url) else { return }

        let url = path.isEmpty ? baseURL : baseURL.appending(path: path)

        var request = URLRequest(url: url)

        for header in instance.headers {
            request.setValue(header.value, forHTTPHeaderField: header.name)
        }

        page.load(request)
    }

    @MainActor
    static func clearWebsiteData() {
        Task {
            await WKWebsiteDataStore.default().removeData(
                ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                modifiedSince: .distantPast
            )
        }
    }
}

struct InstanceWebPresentation: Identifiable {
    var instance: Instance
    var path: String = ""

    var id: String {
        "\(instance.id.uuidString)/\(path)"
    }
}

extension View {
    func instanceWebSheet() -> some View {
        modifier(InstanceWebSheetViewModifier())
    }
}

private struct InstanceWebSheetViewModifier: ViewModifier {
    @State private var presentation: InstanceWebPresentation?

    func body(content: Content) -> some View {
        content
            .environment(\.presentInstanceWeb, $presentation)
            .sheet(item: $presentation) { presentation in
                InstanceWebView(instance: presentation.instance, path: presentation.path)
            }
    }
}

#Preview {
    InstanceWebView(instance: .radarrDummy)
}
