import Foundation

enum EntryType: String, Codable, CaseIterable, Identifiable {
    case quote, thought, idea
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .quote: return "Quote"
        case .thought: return "Thought"
        case .idea: return "Idea"
        }
    }
    
    var placeholder: String {
        switch self {
        case .quote: return "Type or paste the quote…"
        case .thought: return "What's on your mind?"
        case .idea: return "Capture the idea before it slips away…"
        }
    }
    
    var authorLabel: String {
        self == .quote ? "Author" : "Source (optional)"
    }
    
    var authorPlaceholder: String {
        self == .quote ? "Marcus Aurelius" : "Book, podcast, conversation…"
    }
}

struct Entry: Codable, Identifiable, Hashable {
    var id: UUID
    var type: EntryType
    var text: String
    var author: String?
    var tags: [String]
    var favorite: Bool
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        type: EntryType = .quote,
        text: String = "",
        author: String? = nil,
        tags: [String] = [],
        favorite: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.text = text
        self.author = author?.trimmingCharacters(in: .whitespaces).isEmpty == true ? nil : author
        self.tags = Entry.normalizeTags(tags)
        self.favorite = favorite
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    static func normalizeTags(_ input: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for tag in input {
            let normalized = tag
                .trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: "^#+", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
                .lowercased()
                .replacingOccurrences(of: "\\s+", with: "-", options: .regularExpression)
            if !normalized.isEmpty && !seen.contains(normalized) {
                seen.insert(normalized)
                result.append(normalized)
            }
        }
        return result
    }
    
    static func normalizeTags(from string: String) -> [String] {
        let parts = string.components(separatedBy: CharacterSet(charactersIn: ", "))
        return normalizeTags(parts)
    }
}

struct ExportFile: Codable {
    var app: String = "Commonplace"
    var version: Int = 1
    var exportedAt: Date
    var entries: [Entry]
    
    init(entries: [Entry]) {
        self.exportedAt = Date()
        self.entries = entries
    }
}
