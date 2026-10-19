import SwiftUI

struct ContentView: View {
    @Environment(EntryStore.self) private var store
    @State private var selectedTab = 0
    @State private var showingEditor = false
    @State private var editingEntry: Entry?
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case 0:
                    JournalView(showEditor: { entry in
                        editingEntry = entry
                        showingEditor = true
                    })
                case 1:
                    SearchView(showEditor: { entry in
                        editingEntry = entry
                        showingEditor = true
                    })
                case 2:
                    PullOneView(showEditor: { entry in
                        editingEntry = entry
                        showingEditor = true
                    })
                case 3:
                    SettingsView()
                default:
                    JournalView(showEditor: { entry in
                        editingEntry = entry
                        showingEditor = true
                    })
                }
            }
            .safeAreaInset(edge: .bottom) {
                tabBar
            }
        }
        .sheet(isPresented: $showingEditor) {
            EntryEditorView(entry: editingEntry)
                .environment(store)
        }
        .onChange(of: showingEditor) { _, newValue in
            if !newValue {
                editingEntry = nil
            }
        }
    }
    
    private var tabBar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 0) {
                tabButton(index: 0, icon: "book", label: "Journal")
                tabButton(index: 1, icon: "magnifyingglass", label: "Search")
                tabButton(index: 2, icon: "dice", label: "Pull one")
                tabButton(index: 3, icon: "slider.horizontal.3", label: "Settings")
            }
            .padding(4)
            .glassBackground()
            .clipShape(Capsule())
            
            Button {
                editingEntry = nil
                showingEditor = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(width: 56, height: 56)
                    .background(Color.accentColor.gradient, in: Circle())
                    .shadow(color: Color.accentColor.opacity(0.4), radius: 10, y: 5)
            }
            .padding(.leading, 10)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
    
    private func tabButton(index: Int, icon: String, label: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                selectedTab = index
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundColor(selectedTab == index ? Color.accentColor : Color.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

extension View {
    @ViewBuilder
    func glassBackground() -> some View {
        if #available(iOS 26, *) {
            self.glassEffect()
        } else {
            self.background(.regularMaterial, in: Capsule())
        }
    }
}

#Preview {
    ContentView()
        .environment(EntryStore.shared)
}
