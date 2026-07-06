import Testing
import Foundation

// Exercises the pure root-folder label disambiguation (`RootFolderLabel`) that backs
// `InstanceRootFolder.menuLabel(among:)`. Covers the two folder layouts from #720: mounts
// that share a leaf directory, and mounts whose leaf already differs.
struct RootFolderLabelTests {
    // A zero-width space trails each separator in a multi-element label; rebuild the expected
    // values with the same constant so the assertions stay readable.
    private let sep = RootFolderLabel.separator

    // Two mounts ending in the same ".../Media/Videos" leaf grow their labels from the leaf
    // toward the root until they differ.
    @Test func disambiguatesFoldersSharingTheSameLeaf() {
        let a = "/media/nas1/Media/Videos"
        let b = "/media/nas2/Media/Videos"

        #expect(RootFolderLabel.disambiguate(a, among: [b]) == "nas1\(sep)Media\(sep)Videos")
        #expect(RootFolderLabel.disambiguate(b, among: [a]) == "nas2\(sep)Media\(sep)Videos")
    }

    // When the leaf already differs, the label stays the single leaf element.
    @Test func keepsLeafWhenAlreadyDistinct() {
        let a = "/media/nas1/Media/Movies"
        let b = "/media/nas2/Media/Videos"

        #expect(RootFolderLabel.disambiguate(a, among: [b]) == "Movies")
        #expect(RootFolderLabel.disambiguate(b, among: [a]) == "Videos")
    }

    // A folder with no siblings is always just its leaf.
    @Test func loneFolderIsJustItsLeaf() {
        #expect(RootFolderLabel.disambiguate("/media/nas1/Media/Videos", among: []) == "Videos")
    }

    // Three mounts sharing the same leaf each grow only as far as needed to become unique.
    @Test func disambiguatesAcrossMoreThanTwoFolders() {
        let a = "/media/nas1/Media/Videos"
        let b = "/media/nas2/Media/Videos"
        let c = "/mnt/nas1/Media/Videos"

        #expect(RootFolderLabel.disambiguate(a, among: [b, c]) == "media\(sep)nas1\(sep)Media\(sep)Videos")
        #expect(RootFolderLabel.disambiguate(b, among: [a, c]) == "nas2\(sep)Media\(sep)Videos")
        #expect(RootFolderLabel.disambiguate(c, among: [a, b]) == "mnt\(sep)nas1\(sep)Media\(sep)Videos")
    }
}
