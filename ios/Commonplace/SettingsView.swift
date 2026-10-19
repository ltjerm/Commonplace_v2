import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(EntryStore.self) private var store
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var showingEraseConfirmation = false
    @State private var showingFinalEraseConfirmation = false
    @State private var importResult: ImportResult?
    @State private var showingImportResult = false
    @State private var importError: String?
    @State private var showingImportError = false
    
    private struct ImportResult {
        let added: Int
        let updated: Int
    }
    
    var body: some View {
        NavigationStack {
            List {
                librarySection
                dataSection
                dangerSection
                footerSection
            }
            .navigationTitle("Settings")
            .fileExporter(
                isPresented: $showingExporter,
                document: ExportDocument(store: store),
                contentType: .json,
                defaultFilename: "commonplace-\(dateString()).json"
            ) { result in
                if case .failure(let error) = result {
                    print("Export failed: \(error)")
                }
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
            .alert("Import Complete", isPresented: $showingImportResult) {
                Button("OK", role: .cancel) { }
            } message: {
                if let result = importResult {
                    Text("\(result.added) new, \(result.updated) updated")
                }
            }
            .alert("Import Failed", isPresented: $showingImportError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(importError ?? "Unknown error")
            }
            .confirmationDialog("Erase everything?", isPresented: $showingEraseConfirmation, titleVisibility: .visible) {
                Button("Erase All \(store.entries.count) Entries", role: .destructive) {
                    showingFinalEraseConfirmation = true
                }
            } message: {
                Text("Export first if you want a backup. This can't be undone.")
            }
            .confirmationDialog("Are you sure?", isPresented: $showingFinalEraseConfirmation, titleVisibility: .visible) {
                Button("Yes, Erase Everything", role: .destructive) {
                    store.eraseAll()
                }
            } message: {
                Text("This will permanently delete all \(store.entries.count) entries.")
            }
        }
    }
    
    private var librarySection: some View {
        Section("Library") {
            HStack {
                Text("Entries")
                Spacer()
                Text("\(store.stats.total)")
                    .fontWeight(.semibold)
            }
            
            let s = store.stats
            Text("\(s.quotes) quotes · \(s.thoughts) thoughts · \(s.ideas) ideas · \(s.favorites) favorites")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private var dataSection: some View {
        Section("Data") {
            Button {
                showingExporter = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Export JSON")
                            .foregroundStyle(.primary)
                        Text("Back up, or move to another device")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(.accent)
                }
            }
            
            Button {
                showingImporter = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Import JSON")
                            .foregroundStyle(.primary)
                        Text("Merges by id; newer edits win")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "square.and.arrow.down")
                        .foregroundStyle(.accent)
                }
            }
        }
    }
    
    private var dangerSection: some View {
        Section("Danger Zone") {
            Button {
                if store.entries.isEmpty {
                    return
                }
                showingEraseConfirmation = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Erase everything")
                            .foregroundStyle(store.entries.isEmpty ? .secondary : .red)
                        Text("Export first. Can't be undone.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "trash")
                        .foregroundStyle(store.entries.isEmpty ? .secondary : .red)
                }
            }
            .disabled(store.entries.isEmpty)
        }
    }
    
    private var footerSection: some View {
        Section {
            VStack(spacing: 4) {
                Text("Commonplace stores everything on this device only.")
                Text("No accounts, no servers.")
            }
            .font(.footnote)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
        }
    }
    
    private func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            guard url.startAccessingSecurityScopedResource() else {
                importError = "Couldn't access the file"
                showingImportError = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            
            do {
                let data = try Data(contentsOf: url)
                let (added, updated) = try store.importData(data)
                importResult = ImportResult(added: added, updated: updated)
                showingImportResult = true
            } catch {
                importError = error.localizedDescription
                showingImportError = true
            }
            
        case .failure(let error):
            importError = error.localizedDescription
            showingImportError = true
        }
    }
}

struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    
    let data: Data
    
    init(store: EntryStore) {
        self.data = store.exportData() ?? Data()
    }
    
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

#Preview {
    SettingsView()
        .environment(EntryStore.shared)
}
