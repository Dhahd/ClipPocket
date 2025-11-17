//
//  SyntaxHighlightedCodeView.swift
//  ClipPocket
//
//  Created by Shaneen on 10/14/24.
//

import SwiftUI

struct SyntaxHighlightedCodeView: View {
    let code: String
    let sourceIDE: SourceIDE

    var body: some View {
        syntaxHighlightedCode
    }

    var syntaxHighlightedCode: some View {
        Text(AttributedString(highlightSyntax(code)))
            .font(.system(size: 16, design: .monospaced))
            .padding(4)
    }

    private func highlightSyntax(_ code: String) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: code)
        let colorScheme = sourceIDE.colorScheme
        
        for (pattern, colorKey) in colorScheme.patterns {
            let regex = try? NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(location: 0, length: code.utf16.count)
            regex?.enumerateMatches(in: code, options: [], range: range) { match, _, _ in
                if let matchRange = match?.range {
                    attributedString.addAttribute(.foregroundColor, value: colorKey, range: matchRange)
                }
            }
        }
        
        return attributedString
    }
}
enum SourceIDE {
    case xcode
    case androidStudio
    
    var colorScheme: IDEColorScheme {
        switch self {
        case .xcode:
            return XcodeColorScheme()
        case .androidStudio:
            return AndroidStudioColorScheme()
        }
    }
}

protocol IDEColorScheme {
    var patterns: [(String, NSColor)] { get }
}

struct XcodeColorScheme: IDEColorScheme {
    var patterns: [(String, NSColor)] {
        [
            ("\\b(class|struct|enum|protocol|extension|func|var|let|if|else|guard|switch|case|default|for|while|do|try|catch|import|return|throw|throws|rethrows|inout|mutating|nonmutating|override|required|convenience|weak|unowned|lazy|final|open|public|internal|private|fileprivate|static|subscript|init|deinit|associatedtype|typealias|as|is|super|self|nil|true|false|in|where|Any|AnyObject)\\b", NSColor(red: 0.6, green: 0.2, blue: 0.8, alpha: 1)), // Keywords - Purple
            ("\\b[A-Z][A-Za-z0-9_]*\\b", NSColor(red: 0.2, green: 0.6, blue: 0.8, alpha: 1)), // Types - Light Blue
            ("\\b[a-z][A-Za-z0-9_]*(?=\\()", NSColor(red: 0.2, green: 0.6, blue: 0.2, alpha: 1)), // Function calls - Green
            ("\".*?\"", NSColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1)), // Strings - Red
            ("\\b\\d+(\\.\\d+)?\\b", NSColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1)), // Numbers - Blue
            ("//.*", NSColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1)) // Comments - Gray
        ]
    }
}

struct AndroidStudioColorScheme: IDEColorScheme {
    var patterns: [(String, NSColor)] {
        [
            ("\\b(package|import|class|interface|object|val|var|fun|if|else|when|for|while|do|try|catch|throw|return|continue|break|as|is|in|!in|!is|by|constructor|delegate|enum|this|super|null|true|false|internal|external|override|abstract|final|open|const|lateinit|vararg|noinline|crossinline|reified|tailrec|operator|infix|inline|inner|companion|sealed|suspend|typealias)\\b", NSColor(red: 0.8, green: 0.2, blue: 0.5, alpha: 1)), // Keywords - Pink
            ("\\b[A-Z][A-Za-z0-9_]*\\b", NSColor(red: 0.4, green: 0.8, blue: 0.8, alpha: 1)), // Types - Light Blue
            ("\\b[a-z][A-Za-z0-9_]*(?=\\()", NSColor(red: 0.8, green: 0.6, blue: 0.0, alpha: 1)), // Function calls - Orange
            ("\".*?\"", NSColor(red: 0.2, green: 0.8, blue: 0.2, alpha: 1)), // Strings - Green
            ("\\b\\d+(\\.\\d+)?\\b", NSColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1)), // Numbers - Blue
            ("//.*", NSColor(red: 0.4, green: 0.6, blue: 0.4, alpha: 1)) // Comments - Light Green
        ]
    }
}
