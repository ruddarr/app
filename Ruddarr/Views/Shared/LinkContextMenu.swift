import SwiftUI

struct LinkContextMenu: View {
    var url: URL

    @Environment(\.openURL) private var openURL

    init(_ url: URL) {
        self.url = url
    }

    var body: some View {
        Button("Copy Link", systemImage: "document.on.document") {
            #if os(macOS)
                NSPasteboard.general.setString(url.absoluteString, forType: .URL)
            #else
                UIPasteboard.general.string = url.absoluteString
            #endif

            dependencies.toast.show(.linkCopied)
        }

        #if os(iOS)
            if let url = chromeUrl {
                Button("Open in \(String("Chrome"))", systemImage: "arrow.up.right.square") {
                    openURL(url)
                }
            }

            if let url = firefoxUrl {
                Button("Open in \(String("Firefox"))", systemImage: "arrow.up.right.square") {
                    openURL(url)
                }
            }
        #endif
    }

#if os(iOS)
    var chromeUrl: URL? {
        guard UIApplication.shared.canOpenURL(URL(string: "googlechrome://")!) else {
            return nil
        }

        let chromeUrl = url.absoluteString.replacingOccurrences(
            of: "^https?://",
            with: "googlechrome://",
            options: .regularExpression
        )

        return URL(string: chromeUrl)
    }

    var firefoxUrl: URL? {
        guard UIApplication.shared.canOpenURL(URL(string: "firefox://")!) else {
            return nil
        }

        let allowedEscapes = CharacterSet.urlQueryAllowed.symmetricDifference(
            CharacterSet(charactersIn: "?=&")
        )

        let escapedUrl = url.absoluteString
            .addingPercentEncoding(withAllowedCharacters: allowedEscapes)

        return URL(string: "firefox://open-url?url=\(escapedUrl ?? url.absoluteString)")
    }
#endif
}
