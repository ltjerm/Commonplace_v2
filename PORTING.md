# Commonplace → SwiftUI

Export from Settings → Export JSON. File shape:

```json
{ "app": "Commonplace", "version": 1, "exportedAt": "2026-10-17T05:22:59Z",
  "entries": [ { "id": "UUID", "type": "quote|thought|idea", "text": "…", "author": "…or null",
                 "tags": ["stoic"], "favorite": true,
                 "createdAt": "2026-10-17T05:22:51Z", "updatedAt": "2026-10-17T05:22:51Z" } ] }
```

```swift
enum EntryType: String, Codable, CaseIterable { case quote, thought, idea }

struct Entry: Codable, Identifiable, Hashable {
    var id: UUID
    var type: EntryType
    var text: String
    var author: String?      // author for quotes, source otherwise
    var tags: [String]       // lowercase, no "#"
    var favorite: Bool
    var createdAt: Date
    var updatedAt: Date
}

struct ExportFile: Codable { var app: String; var version: Int; var exportedAt: Date; var entries: [Entry] }

let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .iso8601   // dates are written without fractional seconds
let file = try decoder.decode(ExportFile.self, from: data)
```

Import in the web app accepts the same shape (or a bare array of entries) and merges by `id`, newer `updatedAt` wins, so the native app can export back to the same format.
