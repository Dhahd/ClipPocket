import SwiftUI

struct SnippetCard: View {
    let snippet: Snippet
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 0) {
                Image(systemName: "doc.text.below.ecg")
                    .font(.system(size: settings.scaledFont(20)))
                    .padding(.leading, 12)
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(snippet.title)
                        .font(.system(size: settings.scaledFont(14), weight: .bold))
                        .lineLimit(1)
                    if !snippet.category.isEmpty {
                        Text(snippet.category)
                            .font(.system(size: settings.scaledFont(11), weight: .thin))
                    }
                }
                .padding(.trailing, 12)
            }
            .frame(height: settings.cardHeaderHeight)
            .foregroundColor(.white)
            .background(
                ZStack {
                    Color.purple.opacity(0.7)
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            Color.clear,
                            Color.black.opacity(0.2)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            )

            // Template content with highlighted placeholders
            VStack(alignment: .leading, spacing: 8) {
                SnippetTemplateText(template: snippet.content)
                    .lineLimit(4)

                Spacer(minLength: 0)

                // Footer
                HStack {
                    if !snippet.placeholders.isEmpty {
                        Text("\(snippet.placeholders.count) placeholder\(snippet.placeholders.count == 1 ? "" : "s")")
                            .font(.system(size: settings.scaledFont(10)))
                            .foregroundColor(.purple.opacity(0.9))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.15))
                            .cornerRadius(4)
                    }
                    Spacer()
                    Text(snippet.createdDate, style: .relative)
                        .font(.system(size: settings.scaledFont(10)))
                        .foregroundColor(.gray)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: settings.cardWidth, height: settings.cardHeight)
        .background(
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                LinearGradient(
                    colors: [
                        Color.purple.opacity(0.05),
                        Color.clear,
                        Color.black.opacity(0.15)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .cornerRadius(settings.cardCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: settings.cardCornerRadius)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.purple.opacity(0.4),
                            Color.purple.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

struct SnippetTemplateText: View {
    let template: String
    private let settings = SettingsManager.shared

    var body: some View {
        Text(highlightedTemplate)
            .font(.system(size: settings.scaledFont(12)))
    }

    private var highlightedTemplate: AttributedString {
        var result = AttributedString(template)
        result.foregroundColor = Color(NSColor.labelColor)

        let pattern = "\\{[^}]+\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return result }
        let nsString = template as NSString
        let matches = regex.matches(in: template, range: NSRange(location: 0, length: nsString.length))

        for match in matches {
            if let swiftRange = Range(match.range, in: template),
               let attrRange = result.range(of: String(template[swiftRange])) {
                result[attrRange].foregroundColor = .purple
                result[attrRange].font = .system(size: settings.scaledFont(12), weight: .bold)
            }
        }
        return result
    }
}
