import SwiftUI

enum FilterKind: String, CaseIterable, Identifiable {
    case all, quote, thought, idea, favorites
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .all: return "All"
        case .quote: return "Quotes"
        case .thought: return "Thoughts"
        case .idea: return "Ideas"
        case .favorites: return "★ Favorites"
        }
    }
}

struct JournalView: View {
    @Environment(EntryStore.self) private var store
    @State private var filterKind: FilterKind = .all
    @State private var filterTag: String?
    
    var showEditor: (Entry?) -> Void
    
    private var filteredEntries: [Entry] {
        var list = store.sorted()
        
        switch filterKind {
        case .all: break
        case .quote: list = list.filter { $0.type == .quote }
        case .thought: list = list.filter { $0.type == .thought }
        case .idea: list = list.filter { $0.type == .idea }
        case .favorites: list = list.filter { $0.favorite }
        }
        
        if let tag = filterTag {
            list = list.filter { $0.tags.contains(tag) }
        }
        
        return list
    }
    
    private var groupedEntries: [(String, [Entry])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: filteredEntries) { entry in
            dayLabel(for: entry.createdAt)
        }
        
        let orderedKeys = filteredEntries.map { dayLabel(for: $0.createdAt) }
        var seen = Set<String>()
        let uniqueKeys = orderedKeys.filter { seen.insert($0).inserted }
        
        return uniqueKeys.compactMap { key in
            guard let entries = groups[key] else { return nil }
            return (key, entries)
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12, pinnedViews: []) {
                    filterChips
                    tagChips
                    
                    if filteredEntries.isEmpty {
                        emptyState
                    } else {
                        ForEach(groupedEntries, id: \.0) { day, entries in
                            Section {
                                ForEach(entries) { entry in
                                    EntryCardView(entry: entry, onTagTap: { tag in
                                        filterTag = tag
                                    })
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
                                            withAnimation {
                                                store.remove(entry.id)
                                            }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            } header: {
                                HStack {
                                    Text(day)
                                        .font(.title2.bold())
                                    Spacer()
                                }
                                .padding(.horizontal, 4)
                                .padding(.top, 16)
                                .padding(.bottom, 4)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 100)
            }
            .navigationTitle("Commonplace")
        }
    }
    
    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(FilterKind.allCases) { kind in
                    FilterChip(
                        label: kind.label,
                        isSelected: filterKind == kind
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            filterKind = kind
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
        }
        .scrollClipDisabled()
    }
    
    @ViewBuilder
    private var tagChips: some View {
        let tags = store.allTags()
        if !tags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        FilterChip(
                            label: "#\(tag)\(filterTag == tag ? " ✕" : "")",
                            isSelected: filterTag == tag,
                            isTag: true
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                filterTag = filterTag == tag ? nil : tag
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
            }
            .scrollClipDisabled()
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("\u{201C}")
                .font(.system(size: 64, design: .serif))
                .foregroundStyle(.accent)
                .opacity(0.8)
            
            if store.entries.isEmpty {
                Text("Your commonplace book is empty.")
                    .font(.headline)
                Text("Tap **+** to capture a quote, a thought, or an idea.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Nothing here yet.")
                    .font(.headline)
                Text("No entries match this filter.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
        .padding(40)
        .frame(maxWidth: .infinity)
        .cardBackground()
        .padding(.top, 20)
    }
    
    private func dayLabel(for date: Date) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let entryDay = calendar.startOfDay(for: date)
        let diff = calendar.dateComponents([.day], from: entryDay, to: today).day ?? 0
        
        if diff == 0 { return "Today" }
        if diff == 1 { return "Yesterday" }
        
        let formatter = DateFormatter()
        if diff < 7 {
            formatter.dateFormat = "EEEE"
        } else if calendar.component(.year, from: date) == calendar.component(.year, from: Date()) {
            formatter.dateFormat = "MMMM d"
        } else {
            formatter.dateFormat = "MMMM d, yyyy"
        }
        return formatter.string(from: date)
    }
}

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    var isTag: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isSelected ? (isTag ? .primary : .white) : (isTag ? .secondary : .primary))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background {
                    if isSelected {
                        if isTag {
                            Capsule().fill(.primary.opacity(0.15))
                        } else {
                            Capsule().fill(Color.primary)
                        }
                    } else {
                        Capsule().fill(.regularMaterial)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

extension View {
    func cardBackground() -> some View {
        self.background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.regularMaterial)
        }
    }
}

#Preview {
    JournalView(showEditor: { _ in })
        .environment(EntryStore.shared)
}
