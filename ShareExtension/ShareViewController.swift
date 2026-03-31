import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    private let supportedDomains = [
        "letterboxd.com",
        "rottentomatoes.com",
        "imdb.com",
        "themoviedb.org",
        "trakt.tv",
        "thetvdb.com",
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.isHidden = true
        processInput()
    }

    private func processInput() {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = item.attachments else {
            showUnsupportedURL()
            return
        }

        for provider in attachments {
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.url.identifier) { [weak self] data, _ in
                    guard let url = data as? URL else {
                        DispatchQueue.main.async { self?.showUnsupportedURL() }
                        return
                    }
                    Task { @MainActor in
                        await self?.handleURL(url)
                    }
                }
                return
            }

            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { [weak self] data, _ in
                    guard let text = data as? String, let url = URL(string: text), url.host != nil else {
                        DispatchQueue.main.async { self?.showUnsupportedURL() }
                        return
                    }
                    Task { @MainActor in
                        await self?.handleURL(url)
                    }
                }
                return
            }
        }

        showUnsupportedURL()
    }

    private func handleURL(_ url: URL) async {
        guard let host = url.host?.lowercased() else {
            showUnsupportedURL()
            return
        }

        if host.contains("letterboxd.com") {
            await handleLetterboxd(url)
        } else if host.contains("rottentomatoes.com") {
            handleRottenTomatoes(url)
        } else if host.contains("imdb.com") {
            await handleIMDb(url)
        } else if host.contains("themoviedb.org") {
            handleTMDB(url)
        } else if host.contains("trakt.tv") {
            handleTrakt(url)
        } else if host.contains("thetvdb.com") {
            handleTVDB(url)
        } else {
            showUnsupportedURL()
        }
    }

    // MARK: - Letterboxd

    private func handleLetterboxd(_ url: URL) async {
        if let title = await fetchPageTitle(url) {
            var name = title

            // Remove " | Letterboxd" suffix
            for separator in [" | Letterboxd", " \u{2014} Letterboxd", " - Letterboxd"] {
                if let range = name.range(of: separator, options: .caseInsensitive) {
                    name = String(name[..<range.lowerBound])
                }
            }

            // Remove "directed by..." or "review by..." suffixes
            if let range = name.range(of: " directed by", options: .caseInsensitive) {
                name = String(name[..<range.lowerBound])
            }
            if let range = name.range(of: " review by", options: .caseInsensitive) {
                name = String(name[..<range.lowerBound])
            }

            name = name.trimmingCharacters(
                in: CharacterSet(charactersIn: "'\"\u{200E}\u{200F}\u{2018}\u{2019}\u{201C}\u{201D}")
            )
            name = decodeHTMLEntities(name)
            name = name.trimmingCharacters(in: .whitespacesAndNewlines)

            if !name.isEmpty {
                openSearch(query: name, type: .movie)
                return
            }
        }

        // Fallback: extract from URL slug
        let segments = url.pathComponents

        if let filmIndex = segments.firstIndex(of: "film"), filmIndex + 1 < segments.count {
            let slug = segments[filmIndex + 1]
            let name = cleanSlug(slug)
            openSearch(query: name, type: .movie)
        } else {
            showUnsupportedURL()
        }
    }

    // MARK: - Rotten Tomatoes

    private func handleRottenTomatoes(_ url: URL) {
        let segments = url.pathComponents

        guard segments.count >= 3 else {
            showUnsupportedURL()
            return
        }

        let category = segments[1] // "m" or "tv"
        let slug = segments[2]
        let name = cleanSlug(slug, separator: "_")

        openSearch(query: name, type: category == "tv" ? .series : .movie)
    }

    // MARK: - IMDb

    private func handleIMDb(_ url: URL) async {
        let path = url.absoluteString

        guard let range = path.range(of: "tt\\d+", options: .regularExpression) else {
            showUnsupportedURL()
            return
        }

        let imdbId = String(path[range])

        // Download page to determine type
        var mediaType: MediaType = .movie

        if let title = await fetchPageTitle(url) {
            if title.contains("TV Series")
                || title.contains("TV Mini Series")
                || title.contains("TV Short")
            {
                mediaType = .series
            }
        }

        openSearch(query: "imdb:\(imdbId)", type: mediaType)
    }

    // MARK: - TMDB

    private func handleTMDB(_ url: URL) {
        let segments = url.pathComponents

        guard segments.count >= 3 else {
            showUnsupportedURL()
            return
        }

        let type = segments[1] // "movie" or "tv"
        let slug = segments[2] // "12345-movie-name"

        if let tmdbId = slug.split(separator: "-", maxSplits: 1).first, Int(tmdbId) != nil {
            openSearch(query: "tmdb:\(tmdbId)", type: type == "tv" ? .series : .movie)
        } else {
            showUnsupportedURL()
        }
    }

    // MARK: - Trakt

    private func handleTrakt(_ url: URL) {
        let segments = url.pathComponents

        guard segments.count >= 3 else {
            showUnsupportedURL()
            return
        }

        let category = segments[1] // "movies", "shows", or "search"

        if category == "search", segments.count >= 3 {
            // URL: /search/tmdb/12345?id_type=movie or /search/tvdb/12345?id_type=show
            let idType = segments[2] // "tmdb" or "tvdb"

            guard segments.count >= 4 else {
                showUnsupportedURL()
                return
            }

            let id = segments[3]
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let mediaTypeParam = components?.queryItems?.first { $0.name == "id_type" }?.value

            if idType == "tmdb", let _ = Int(id) {
                let type: MediaType = mediaTypeParam == "show" ? .series : .movie
                openSearch(query: "tmdb:\(id)", type: type)
            } else if idType == "tvdb", let _ = Int(id) {
                openSearch(query: "tvdb:\(id)", type: .series)
            } else {
                showUnsupportedURL()
            }
        } else if category == "movies" {
            let name = cleanSlug(segments[2])
            openSearch(query: name, type: .movie)
        } else if category == "shows" {
            let name = cleanSlug(segments[2])
            openSearch(query: name, type: .series)
        } else {
            showUnsupportedURL()
        }
    }

    // MARK: - TVDB

    private func handleTVDB(_ url: URL) {
        let segments = url.pathComponents

        // Old format: ?tab=series&id=12345
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)

        if let tab = components?.queryItems?.first(where: { $0.name == "tab" })?.value,
           let id = components?.queryItems?.first(where: { $0.name == "id" })?.value,
           let _ = Int(id)
        {
            let type: MediaType = tab == "series" ? .series : .movie
            openSearch(query: "tvdb:\(id)", type: type)
            return
        }

        // Modern format: /series/slug or /movies/slug
        guard segments.count >= 3 else {
            showUnsupportedURL()
            return
        }

        let category = segments[1] // "series" or "movies"
        let name = cleanSlug(segments[2])

        if category == "series" {
            openSearch(query: name, type: .series)
        } else if category == "movies" {
            openSearch(query: name, type: .movie)
        } else {
            showUnsupportedURL()
        }
    }

    // MARK: - Search

    private enum MediaType {
        case movie
        case series
    }

    private func openSearch(query: String, type: MediaType) {
        let path = type == .movie ? "movies" : "series"
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? query

        guard let url = URL(string: "ruddarr://\(path)/search/\(encoded)") else {
            close()
            return
        }

        extensionContext?.open(url) { [weak self] _ in
            self?.close()
        }
    }

    // MARK: - Unsupported URL

    private func showUnsupportedURL() {
        view.isHidden = false
        view.backgroundColor = .systemBackground

        let image = UIImageView(image: UIImage(systemName: "link.badge.plus"))
        image.tintColor = .secondaryLabel
        image.contentMode = .scaleAspectFit
        image.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = NSLocalizedString("Unsupported URL", comment: "")
        titleLabel.font = .preferredFont(forTextStyle: .title2, compatibleWith: .init(legibilityWeight: .bold))
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let domains = supportedDomains.map { "  \u{2022} \($0)" }.joined(separator: "\n")
        let descriptionLabel = UILabel()
        descriptionLabel.text = String(
            format: NSLocalizedString("Share a link from a supported site:\n%@", comment: ""),
            domains
        )
        descriptionLabel.font = .preferredFont(forTextStyle: .subheadline)
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.textAlignment = .center
        descriptionLabel.numberOfLines = 0
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false

        let closeButton = UIButton(type: .system)
        closeButton.setTitle(NSLocalizedString("Close", comment: ""), for: .normal)
        closeButton.titleLabel?.font = .preferredFont(forTextStyle: .body, compatibleWith: .init(legibilityWeight: .bold))
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [image, titleLabel, descriptionLabel, closeButton])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.setCustomSpacing(4, after: titleLabel)
        stack.setCustomSpacing(24, after: descriptionLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)

        NSLayoutConstraint.activate([
            image.widthAnchor.constraint(equalToConstant: 48),
            image.heightAnchor.constraint(equalToConstant: 48),

            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32),
        ])
    }

    @objc private func closeTapped() {
        close()
    }

    // MARK: - Helpers

    private func close() {
        extensionContext?.completeRequest(returningItems: nil)
    }

    private func fetchPageTitle(_ url: URL) async -> String? {
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 10

            let (data, _) = try await URLSession.shared.data(for: request)
            guard let html = String(data: data, encoding: .utf8) else { return nil }

            guard let startRange = html.range(of: "<title", options: .caseInsensitive) else { return nil }
            let afterTag = html[startRange.upperBound...]
            guard let closingBracket = afterTag.range(of: ">") else { return nil }
            let contentStart = closingBracket.upperBound
            guard let endRange = html.range(of: "</title>", options: .caseInsensitive, range: contentStart..<html.endIndex) else { return nil }

            return String(html[contentStart..<endRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    private func cleanSlug(_ slug: String, separator: Character = "-") -> String {
        var name = slug

        // Remove trailing year pattern like "-2023"
        if let range = name.range(of: "-\\d{4}$", options: .regularExpression) {
            // Keep year in parentheses for better search
            let year = String(name[range].dropFirst())
            name = String(name[..<range.lowerBound])
            name = name.replacingOccurrences(of: String(separator), with: " ")
            name = decodeHTMLEntities(name)
            return "\(name.capitalized) (\(year))"
        }

        name = name.replacingOccurrences(of: String(separator), with: " ")
        name = decodeHTMLEntities(name)
        return name.capitalized
    }

    private func decodeHTMLEntities(_ string: String) -> String {
        var result = string
        result = result.replacingOccurrences(of: "&#039;", with: "'")
        result = result.replacingOccurrences(of: "&#x27;", with: "'")
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&apos;", with: "'")
        return result
    }
}
