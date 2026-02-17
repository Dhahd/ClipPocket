import Foundation

struct Snippet: Identifiable, Codable {
    var id = UUID()
    var title: String
    var content: String  // Template string with {placeholder} variables
    var category: String
    var createdDate: Date
    var lastUsedDate: Date?

    /// Extract all unique placeholder names from the content template
    var placeholders: [String] {
        let pattern = "\\{([^}]+)\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(content.startIndex..., in: content)
        let matches = regex.matches(in: content, range: range)

        var seen = Set<String>()
        var result: [String] = []
        for match in matches {
            if let swiftRange = Range(match.range(at: 1), in: content) {
                let name = String(content[swiftRange])
                if !seen.contains(name) {
                    seen.insert(name)
                    result.append(name)
                }
            }
        }
        return result
    }

    /// Replace placeholders with provided values
    func resolve(with values: [String: String]) -> String {
        var result = content
        for (key, value) in values {
            result = result.replacingOccurrences(of: "{\(key)}", with: value)
        }
        return result
    }
}
