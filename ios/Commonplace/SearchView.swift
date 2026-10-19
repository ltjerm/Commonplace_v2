import SwiftUI

struct SearchView: View {
    @Environment(EntryStore.self) private var store
    @State private var query = ""
    @FocusState private var isSearchFocused: Bool
    
    var showEditor: (Entry?) -> Void
    
    private var searchResults: [Entry] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        
        let terms = trimmed.lowercased().components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        return store.sorted().filter { entry in
            let searchableText = [
                entry.text,
                entry.author ?? "",
                entry.tags.map { "#\($0)" }.joined(separator: " ")
            ].joined(separator: " ").lowercased()
            
            return terms.allSatisfy { term in
                if term.hasPrefix("#") {
                    let tagTerm = String(term.dropFirst())
                    return entry.tags.contains { $0.hasPrefix(tagTerm) }
                }
                return searchableText.contains(term)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    searchField
                    
                    if query.isEmpty {
                        tagBrowser
                    } else if searchResults.isEmpty {
                        noResults
                    } else {
                        resultsCount
                        
                        ForEach(searchResults) { entry in
                            EntryCardView(entry: entry)
                                .onTapGesture {
                                    showEditor(entry)
                                }
                                .contextMenu {
                                    Button {
                                        store.toggleFavorite(entry.id)
                                    } label: {
                                        Label(entry.favorite ? "Remove from Favorites" : "Add to Favorites", 
                                              systemImage: entry.favorite ? "star.slash" : "star")
                                    }
                                    
                                    Button(role: .destructive) {
                                        store.remove(entry.id)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 100)
            }
            .navigationTitle("Search")
        }
    }
    
    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            
            TextField("Words, authors, #tags", text: $query)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled()
                .focused($isSearchFocused)
                .submitLabel(.search)
            
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: Capsule())
    }
    
    @ViewBuilder
    private var tagBrowser: some View {
        let tags = store.allTags()
        
        if tags.isEmpty {
            VStack(spacing: 8) {
                Text("Search across text, authors, and tags.")
                    .foregroundStyle(.secondary)
            }
            .padding(40)
            .frame(maxWidth: .infinity)
            .cardBackground()
            .padding(.top, 20)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("Browse tags")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                
                FlowLayout(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        Button {
                            query = "#\(tag)"
                        } label: {
                            Text("#\(tag)")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(.regularMaterial, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.top, 12)
        }
    }
    
    private var noResults: some View {
        VStack(spacing: 8) {
            Text("No matches for \"\(query)\"")
                .font(.headline)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .cardBackground()
        .padding(.top, 20)
    }
    
    private var resultsCount: some View {
        HStack {
            Text("\(searchResults.count) \(searchResults.count == 1 ? "entry" : "entries")")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
    }
}

#Preview {
    SearchView(showEditor: { _ in })
        .environment(EntryStore.shared)
}
