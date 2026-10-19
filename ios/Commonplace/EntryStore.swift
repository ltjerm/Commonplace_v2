import Foundation
import SwiftUI

@Observable
final class EntryStore {
    private(set) var entries: [Entry] = []
    
    private let fileURL: URL
    
    static let shared = EntryStore()
    
    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent("commonplace-entries.json")
        load()
    }
    
    private static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = iso8601Formatter.date(from: string) {
                return date
            }
            let flexibleFormatter = ISO8601DateFormatter()
            flexibleFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = flexibleFormatter.date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(string)")
        }
        return d
    }()
    
    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            let string = iso8601Formatter.string(from: date)
            try container.encode(string)
        }
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()
    
    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            entries = []
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let stored = try Self.decoder.decode(StoredData.self, from: data)
            entries = stored.entries
        } catch {
            print("Failed to load entries: \(error)")
            entries = []
        }
    }
    
    private func save() {
        do {
            let stored = StoredData(version: 1, entries: entries)
            let data = try Self.encoder.encode(stored)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save entries: \(error)")
        }
    }
    
    func sorted() -> [Entry] {
        entries.sorted { $0.createdAt > $1.createdAt }
    }
    
    func get(_ id: UUID) -> Entry? {
        entries.first { $0.id == id }
    }
    
    func upsert(_ entry: Entry) {
        var updated = entry
        updated.updatedAt = Date()
        
        if let author = updated.author, author.trimmingCharacters(in: .whitespaces).isEmpty {
            updated.author = nil
        }
        updated.tags = Entry.normalizeTags(updated.tags)
        
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = updated
        } else {
            updated.createdAt = Date()
            entries.append(updated)
        }
        save()
    }
    
    func toggleFavorite(_ id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].favorite.toggle()
        entries[index].updatedAt = Date()
        save()
    }
    
    func remove(_ id: UUID) {
        entries.removeAll { $0.id == id }
        save()
    }
    
    func allTags() -> [String] {
        var counts: [String: Int] = [:]
        for entry in entries {
            for tag in entry.tags {
                counts[tag, default: 0] += 1
            }
        }
        return counts.sorted { ($0.value, $1.key) > ($1.value, $0.key) }.map(\.key)
    }
    
    func merge(_ incoming: [Entry]) -> (added: Int, updated: Int) {
        var added = 0
        var updated = 0
        
        for entry in incoming {
            if let existingIndex = entries.firstIndex(where: { $0.id == entry.id }) {
                if entry.updatedAt > entries[existingIndex].updatedAt {
                    entries[existingIndex] = entry
                    updated += 1
                }
            } else {
                entries.append(entry)
                added += 1
            }
        }
        save()
        return (added, updated)
    }
    
    func exportData() -> Data? {
        let export = ExportFile(entries: sorted())
        return try? Self.encoder.encode(export)
    }
    
    func importData(_ data: Data) throws -> (added: Int, updated: Int) {
        if let export = try? Self.decoder.decode(ExportFile.self, from: data) {
            return merge(export.entries)
        }
        let entries = try Self.decoder.decode([Entry].self, from: data)
        return merge(entries)
    }
    
    func eraseAll() {
        entries = []
        save()
    }
    
    var stats: (total: Int, quotes: Int, thoughts: Int, ideas: Int, favorites: Int) {
        let total = entries.count
        let quotes = entries.filter { $0.type == .quote }.count
        let thoughts = entries.filter { $0.type == .thought }.count
        let ideas = entries.filter { $0.type == .idea }.count
        let favorites = entries.filter { $0.favorite }.count
        return (total, quotes, thoughts, ideas, favorites)
    }
}

private struct StoredData: Codable {
    var version: Int
    var entries: [Entry]
}
