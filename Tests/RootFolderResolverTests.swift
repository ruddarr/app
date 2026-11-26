import Testing
import Foundation

// Exercises `RootFolderResolver`, which derives a movie's root folder from its path when the
// response (like Radarr's calendar endpoint) omits `rootFolderPath`.
struct RootFolderResolverTests {
    @Test func matchesContainingRootFolder() {
        let folders = ["/media/movies/", "/media/films/"]

        #expect(RootFolderResolver.bestPath(for: "/media/films/Heat (1995)", among: folders) == "/media/films")
    }

    // Nested root folders resolve to the deepest one, like Radarr does.
    @Test func prefersLongestRootFolder() {
        let folders = ["/media", "/media/movies/4k"]

        #expect(RootFolderResolver.bestPath(for: "/media/movies/4k/Dune (2021)", among: folders) == "/media/movies/4k")
    }

    // A root folder only matches on whole path elements.
    @Test func ignoresPartialElementMatches() {
        let folders = ["/media/movies"]

        #expect(RootFolderResolver.bestPath(for: "/media/movies-4k/Dune (2021)", among: folders) == "/media/movies-4k")
    }

    // Without a matching root folder, fall back to the parent directory.
    @Test func fallsBackToParentDirectory() {
        #expect(RootFolderResolver.bestPath(for: "/other/Heat (1995)/", among: ["/media/movies"]) == "/other")
        #expect(RootFolderResolver.bestPath(for: "/Heat (1995)", among: []) == nil)
        #expect(RootFolderResolver.bestPath(for: "", among: []) == nil)
    }

    @Test func supportsWindowsPaths() {
        let folders = [#"D:\Movies\"#]

        #expect(RootFolderResolver.bestPath(for: #"D:\Movies\Heat (1995)"#, among: folders) == #"D:\Movies"#)
    }
}
