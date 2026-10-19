import SwiftUI

struct EntryCardView: View {
    @Environment(EntryStore.self) private var store
    let entry: Entry
    var onTagTap: ((String) -> Void)?
    var highlightTerms: [String] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TypePill(type: entry.type)
                
                Text(formatDate(entry.createdAt))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                
                Spacer()
                
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        store.toggleFavorite(entry.id)
                    }
                } label: {
                    Image(systemName: entry.favorite ? "star.fill" : "star")
                        .font(.system(size: 18))
                        .foregroundColor(entry.favorite ? Color.yellow : Color.secondary.opacity(0.6))
                        .symbolEffect(.bounce, value: entry.favorite)
                }
                .buttonStyle(.plain)
            }
            
            Text(entry.text)
                .font(.system(size: 18, design: .serif))
                .italic(entry.type == .quote)
                .lineLimit(9)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if let author = entry.author, !author.isEmpty {
                Text("— \(author)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            
            if !entry.tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(entry.tags, id: \.self) { tag in
                        Button {
                            onTagTap?(tag)
                        } label: {
                            Text("#\(tag)")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.primary.opacity(0.06), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .cardBackground()
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year) 
            ? "MMM d · h:mm a" 
            : "MMM d, yyyy · h:mm a"
        return formatter.string(from: date)
    }
}

struct TypePill: View {
    let type: EntryType
    
    var color: Color {
        switch type {
        case .quote: return .orange
        case .thought: return .teal
        case .idea: return .purple
        }
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .shadow(color: color, radius: 4)
            
            Text(type.label)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(color.opacity(0.15), in: Capsule())
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), 
                                  proposal: .unspecified)
        }
    }
    
    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX)
        }
        
        return (CGSize(width: maxX, height: currentY + lineHeight), positions)
    }
}

#Preview {
    VStack {
        EntryCardView(entry: Entry(
            type: .quote,
            text: "The impediment to action advances action. What stands in the way becomes the way.",
            author: "Marcus Aurelius",
            tags: ["stoic", "discipline"],
            favorite: true
        ))
        
        EntryCardView(entry: Entry(
            type: .thought,
            text: "Need to revisit the architecture of the notification system.",
            tags: ["work"]
        ))
        
        EntryCardView(entry: Entry(
            type: .idea,
            text: "A mobile app that helps track daily habits with gentle reminders."
        ))
    }
    .padding()
    .environment(EntryStore.shared)
}
