import SwiftUI

struct MediaLanguage: Codable {
    let id: Int
    let name: String?

    var label: String {
        name ?? String(localized: "Unknown")
    }
}

func languageSingleLabel(_ languages: [MediaLanguage]) -> String {
    if languages.isEmpty {
        return String(localized: "Unknown")
    }

    if languages.count == 1 {
        return languages[0].label

    }

    return String(localized: "Multilingual")
}

struct MediaPreviewActionModifier: ViewModifier {
    func body(content: Content) -> some View {
        if UIDevice.current.userInterfaceIdiom == .phone {
            content.frame(maxWidth: .infinity)
        } else {
            content.frame(maxWidth: 215)
        }
    }
}

struct MediaPreviewActionSpacerModifier: ViewModifier {
    func body(content: Content) -> some View {
        if UIDevice.current.userInterfaceIdiom == .phone {
            content.frame(maxWidth: .infinity)
        } else {
            content
        }
    }
}

struct MediaDetailsPosterModifier: ViewModifier {
    func body(content: Content) -> some View {
        if UIDevice.current.userInterfaceIdiom == .phone {
            content.containerRelativeFrame(.horizontal, count: 5, span: 2, spacing: 0)
        } else {
            content.frame(width: 200, height: 300)
        }
    }
}
