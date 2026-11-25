import Testing
import Foundation

struct FoldedTextTests {
    private func contains(_ text: String, _ query: String) -> Bool {
        FoldedText(text).contains(FoldedText(query))
    }

    @Test func ignoresCase() {
        #expect(contains("The Matrix", "matrix"))
        #expect(contains("The Matrix", "MATRIX"))
        #expect(contains("the matrix", "The M"))
    }

    @Test func matchesAnywhereInTheText() {
        #expect(contains("The Matrix", "the"))
        #expect(contains("The Matrix", "trix"))
        #expect(contains("The Matrix", "e Ma"))
        #expect(contains("The Matrix", "the matrix"))
    }

    @Test func rejectsTextThatIsNotThere() {
        #expect(!contains("The Matrix", "matrices"))
        #expect(!contains("The Matrix", "the matrix reloaded"))
        #expect(!contains("The Matrix", "xirtam"))
        #expect(!contains("", "matrix"))
    }

    @Test func emptyQueryMatchesEverything() {
        #expect(contains("The Matrix", ""))
        #expect(contains("", ""))
    }

    @Test func retriesAfterAPartialMatch() {
        #expect(contains("aaab", "aab"))
        #expect(contains("matmatrix", "matrix"))
        #expect(!contains("matmatri", "matrix"))
    }

    @Test func handlesAccentsAndOtherScripts() {
        #expect(contains("Amélie", "ÉLIE"))
        #expect(contains("Amélie", "amélie"))
        #expect(!contains("Amélie", "amelie"))
        #expect(contains("アイス・エイジ", "エイジ"))
        #expect(contains("Բարբի", "բարբի"))
        #expect(contains("Åsa", "åsa"))
    }

    @Test func agreesWithLocalizedCaseInsensitiveContains() {
        let texts = [
            "The Matrix Reloaded", "Amélie", "Léon: The Professional", "エルフ サンタの国からやってきた",
            "Բարբի", "باربی", "Ice Age 4: Continental Drift", "Åsa-Nisse", "Crème Brûlée", "12 Angry Men",
        ]

        let queries = ["the", "matrix", "AMÉLIE", "léon", "エルフ", "ice age", "Åsa", "brûl", "12", "zzz", "é", "ア", "a"]

        for text in texts {
            for query in queries {
                #expect(
                    contains(text, query) == text.localizedCaseInsensitiveContains(query),
                    "'\(text)' contains '\(query)'"
                )
            }
        }
    }
}
