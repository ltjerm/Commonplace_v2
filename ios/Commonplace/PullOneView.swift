import SwiftUI

enum PullMode: String, CaseIterable, Identifiable {
    case smart, quotes, favorites, all
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .smart: return "Best of"
        case .quotes: return "Quotes"
        case .favorites: return "★ Favorites"
        case .all: return "Anything"
        }
    }
}

struct PullOneView: View {
    @Environment(EntryStore.self) private var store
    @State private var mode: PullMode = .smart
    @State private var currentEntry: Entry?
    @State private var lastPulledId: UUID?
    @State private var animationTrigger = false
    
    var showEditor: (Entry?) -> Void
    
    private var pool: [Entry] {
        switch mode {
        case .smart, .all: return store.entries
        case .quotes: return store.entries.filter { $0.type == .quote }
        case .favorites: return store.entries.filter { $0.favorite }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    modeChips
                    
                    if pool.isEmpty {
                        emptyState
                    } else if let entry = currentEntry {
                        pullCard(entry)
                        actionButtons(entry)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 100)
            }
            .navigationTitle("Pull one")
            .onAppear {
                if currentEntry == nil || !pool.contains(where: { $0.id == currentEntry?.id }) {
                    pullRandom()
                }
            }
            .onChange(of: mode) { _, _ in
                pullRandom()
            }
        }
    }
    
    private var modeChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PullMode.allCases) { pullMode in
                    FilterChip(
                        label: pullMode.label,
                        isSelected: mode == pullMode
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            mode = pullMode
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
        }
        .scrollClipDisabled()
    }
    
    private func pullCard(_ entry: Entry) -> some View {
        let quoteGlyph = String(UnicodeScalar(0x201C)!)
        return VStack(alignment: .leading, spacing: 16) {
            if entry.type == .quote {
                Text(quoteGlyph)
                    .font(.system(size: 72, design: .serif))
                    .foregroundStyle(Color.accentColor.opacity(0.7))
                    .frame(height: 40)
            }
            
            Text(entry.text)
                .font(.system(size: 24, design: .serif))
                .italic(entry.type == .quote)
                .lineSpacing(4)
            
            if let author = entry.author, !author.isEmpty {
                Text("— \(author)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            
            HStack(spacing: 8) {
                TypePill(type: entry.type)
                
                if entry.favorite {
                    Text("★")
                        .foregroundStyle(.yellow)
                }
                
                Text(formatDate(entry.createdAt))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                
                ForEach(entry.tags, id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(28)
        .background {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
        }
        .scaleEffect(animationTrigger ? 1 : 0.95)
        .opacity(animationTrigger ? 1 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: animationTrigger)
        .onTapGesture {
            showEditor(entry)
        }
    }
    
    private func actionButtons(_ entry: Entry) -> some View {
        HStack(spacing: 12) {
            ShareLink(item: shareText(for: entry)) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 52, height: 52)
                    .background(.regularMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            
            Button {
                pullRandom()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "shuffle")
                    Text("Pull another")
                }
                .font(.headline)
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.accentColor.gradient, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 20)
    }
    
    private var emptyState: some View {
        let quoteGlyph = String(UnicodeScalar(0x201C)!)
        return VStack(spacing: 8) {
            Text(quoteGlyph)
                .font(.system(size: 64, design: .serif))
                .foregroundStyle(Color.accentColor)
                .opacity(0.8)
            
            Text("Nothing to pull yet.")
                .font(.headline)
            
            Text(emptyMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(40)
        .frame(maxWidth: .infinity)
        .cardBackground()
        .padding(.top, 20)
    }
    
    private var emptyMessage: String {
        switch mode {
        case .favorites: return "Star a few entries first."
        case .quotes: return "Add a quote first."
        default: return "Add a few entries first."
        }
    }
    
    private func pullRandom() {
        guard !pool.isEmpty else {
            currentEntry = nil
            return
        }
        
        animationTrigger = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            var candidates = pool
            if candidates.count > 1, let lastId = lastPulledId {
                candidates = candidates.filter { $0.id != lastId }
            }
            
            let selected: Entry
            if mode == .smart {
                selected = weightedRandom(from: candidates)
            } else {
                selected = candidates.randomElement() ?? candidates[0]
            }
            
            currentEntry = selected
            lastPulledId = selected.id
            
            withAnimation {
                animationTrigger = true
            }
        }
    }
    
    private func weightedRandom(from entries: [Entry]) -> Entry {
        let weights = entries.map { entry -> Double in
            var w = 1.0
            if entry.type == .quote { w *= 3.0 }
            if entry.favorite { w *= 3.0 }
            return w
        }
        
        let totalWeight = weights.reduce(0, +)
        var random = Double.random(in: 0..<totalWeight)
        
        for (index, weight) in weights.enumerated() {
            random -= weight
            if random <= 0 {
                return entries[index]
            }
        }
        
        return entries.last!
    }
    
    private func shareText(for entry: Entry) -> String {
        var text = entry.text
        if let author = entry.author, !author.isEmpty {
            text += "\n— \(author)"
        }
        return text
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        if Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year) {
            formatter.dateFormat = "MMM d"
        } else {
            formatter.dateFormat = "MMM d, yyyy"
        }
        return formatter.string(from: date)
    }
}

#Preview {
    PullOneView(showEditor: { _ in })
        .environment(EntryStore.shared)
}
