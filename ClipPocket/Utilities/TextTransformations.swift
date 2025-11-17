import Foundation

enum TextTransformation: String, CaseIterable {
    case uppercase = "UPPERCASE"
    case lowercase = "lowercase"
    case titleCase = "Title Case"
    case camelCase = "camelCase"
    case snakeCase = "snake_case"
    case kebabCase = "kebab-case"
    case removeWhitespace = "Remove Whitespace"
    case trimWhitespace = "Trim Whitespace"
    case removeDuplicateLines = "Remove Duplicate Lines"
    case sortLines = "Sort Lines"
    case reverseLines = "Reverse Lines"
    case base64Encode = "Base64 Encode"
    case base64Decode = "Base64 Decode"
    case urlEncode = "URL Encode"
    case urlDecode = "URL Decode"
    case jsonPrettify = "JSON Prettify"
    case jsonMinify = "JSON Minify"

    var icon: String {
        switch self {
        case .uppercase, .lowercase, .titleCase:
            return "textformat"
        case .camelCase, .snakeCase, .kebabCase:
            return "text.cursor"
        case .removeWhitespace, .trimWhitespace:
            return "space"
        case .removeDuplicateLines, .sortLines, .reverseLines:
            return "list.bullet"
        case .base64Encode, .base64Decode:
            return "lock.shield"
        case .urlEncode, .urlDecode:
            return "link"
        case .jsonPrettify, .jsonMinify:
            return "curlybraces"
        }
    }

    func apply(to text: String) -> String {
        switch self {
        case .uppercase:
            return text.uppercased()

        case .lowercase:
            return text.lowercased()

        case .titleCase:
            return text.titlecased()

        case .camelCase:
            return text.toCamelCase()

        case .snakeCase:
            return text.toSnakeCase()

        case .kebabCase:
            return text.toKebabCase()

        case .removeWhitespace:
            return text.replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)

        case .trimWhitespace:
            return text.trimmingCharacters(in: .whitespacesAndNewlines)

        case .removeDuplicateLines:
            let lines = text.components(separatedBy: .newlines)
            let unique = Array(Set(lines))
            return unique.joined(separator: "\n")

        case .sortLines:
            let lines = text.components(separatedBy: .newlines)
            let sorted = lines.sorted()
            return sorted.joined(separator: "\n")

        case .reverseLines:
            let lines = text.components(separatedBy: .newlines)
            let reversed = lines.reversed()
            return reversed.joined(separator: "\n")

        case .base64Encode:
            return text.data(using: .utf8)?.base64EncodedString() ?? text

        case .base64Decode:
            guard let data = Data(base64Encoded: text),
                  let decoded = String(data: data, encoding: .utf8) else {
                return text
            }
            return decoded

        case .urlEncode:
            return text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text

        case .urlDecode:
            return text.removingPercentEncoding ?? text

        case .jsonPrettify:
            guard let data = text.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data),
                  let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
                  let prettyString = String(data: prettyData, encoding: .utf8) else {
                return text
            }
            return prettyString

        case .jsonMinify:
            guard let data = text.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data),
                  let minifiedData = try? JSONSerialization.data(withJSONObject: json, options: []),
                  let minifiedString = String(data: minifiedData, encoding: .utf8) else {
                return text
            }
            return minifiedString
        }
    }
}

// MARK: - String Extensions
extension String {
    func titlecased() -> String {
        return self.capitalized
    }

    func toCamelCase() -> String {
        let words = self.components(separatedBy: CharacterSet.alphanumerics.inverted)
        let filtered = words.filter { !$0.isEmpty }
        guard !filtered.isEmpty else { return self }

        let first = filtered[0].lowercased()
        let rest = filtered.dropFirst().map { $0.capitalized }
        return ([first] + rest).joined()
    }

    func toSnakeCase() -> String {
        let pattern = "([a-z0-9])([A-Z])"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(self.startIndex..., in: self)
        let result = regex?.stringByReplacingMatches(
            in: self,
            range: range,
            withTemplate: "$1_$2"
        ) ?? self
        return result.lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
    }

    func toKebabCase() -> String {
        return self.toSnakeCase().replacingOccurrences(of: "_", with: "-")
    }
}
