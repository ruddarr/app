import SwiftUI
import QuickLook

struct PosterQuickLook: ViewModifier {
    let remote: String?
    let filename: String?

    @State private var url: URL?
    @State private var isLoading = false

    func body(content: Content) -> some View {
        content
            .onTapGesture {
                Task {
                    if Images.hasLocalCopy(of: remote, named: filename) == nil {
                        isLoading = true
                    }

                    defer { isLoading = false }
                    url = await Images.localCopy(of: remote, named: filename)
                }
            }
            .allowsHitTesting(!isLoading)
            .overlay {
                if isLoading {
                    ZStack {
                        Color.black.opacity(0.7)
                        ProgressView().tint(.white)
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isLoading)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .quickLookPreview($url)
    }
}

extension View {
    func posterQuickLook(_ remote: String?, named filename: String? = nil) -> some View {
        modifier(PosterQuickLook(remote: remote, filename: filename))
    }
}
