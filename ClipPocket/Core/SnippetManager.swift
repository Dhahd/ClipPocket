import Foundation
import Combine

class SnippetManager: ObservableObject {
    @Published var snippets: [Snippet] = []
    private let maxSnippets = 200

    init() {
        loadSnippets()
        if snippets.isEmpty {
            seedExampleSnippets()
        }
    }

    // MARK: - CRUD

    func addSnippet(_ snippet: Snippet) {
        snippets.insert(snippet, at: 0)
        if snippets.count > maxSnippets {
            snippets = Array(snippets.prefix(maxSnippets))
        }
        saveSnippets()
    }

    func updateSnippet(_ snippet: Snippet) {
        if let index = snippets.firstIndex(where: { $0.id == snippet.id }) {
            snippets[index] = snippet
            saveSnippets()
        }
    }

    func deleteSnippet(_ snippet: Snippet) {
        snippets.removeAll { $0.id == snippet.id }
        saveSnippets()
    }

    func markUsed(_ snippet: Snippet) {
        if let index = snippets.firstIndex(where: { $0.id == snippet.id }) {
            snippets[index].lastUsedDate = Date()
            saveSnippets()
        }
    }

    // MARK: - Example Snippets

    func loadExamples() {
        seedExampleSnippets()
    }

    private func seedExampleSnippets() {
        let examples = [
            Snippet(
                title: "Quick Email Reply",
                content: "Hi {name},\n\nThanks for reaching out about {topic}. I'll look into it and get back to you by {date}.\n\nBest,\nShaneen",
                category: "Email",
                createdDate: Date()
            ),
            Snippet(
                title: "Bug Report",
                content: "## Bug: {title}\n\n**Steps to reproduce:**\n1. {step1}\n2. {step2}\n\n**Expected:** {expected}\n**Actual:** {actual}\n\n**Device:** {device}",
                category: "Dev",
                createdDate: Date()
            ),
            Snippet(
                title: "Meeting Notes",
                content: "Meeting: {meeting_name}\nDate: {date}\nAttendees: {attendees}\n\n## Key Points\n- {point1}\n- {point2}\n\n## Action Items\n- {action1}",
                category: "Work",
                createdDate: Date()
            ),
        ]
        snippets = examples
        saveSnippets()
    }

    // MARK: - Persistence

    private var snippetsFileURL: URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let appDir = appSupport.appendingPathComponent("ClipPocket", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("snippets.json")
    }

    private func loadSnippets() {
        guard let url = snippetsFileURL,
              FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            snippets = try JSONDecoder().decode([Snippet].self, from: data)
            print("✅ Loaded \(snippets.count) snippets")
        } catch {
            print("❌ Failed to load snippets: \(error)")
            snippets = []
        }
    }

    private func saveSnippets() {
        guard let url = snippetsFileURL else { return }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(snippets)
            try data.write(to: url, options: .atomic)
        } catch {
            print("❌ Failed to save snippets: \(error)")
        }
    }
}
