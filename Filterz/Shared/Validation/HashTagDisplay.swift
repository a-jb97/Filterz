import Foundation

nonisolated func displayHashTag(_ tag: String) -> String {
    let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
    let normalized = trimmed.drop { $0 == "#" }
    return String(normalized)
}
