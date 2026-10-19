import SwiftUI

struct EntryEditorView: View {
    @Environment(EntryStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    
    let entry: Entry?
    
    @State private var type: EntryType
    @State private var text: String
    @State private var author: String
    @State private var tagsString: String
    @State private var favorite: Bool
    
    @State private var showDeleteConfirmation = false
    @FocusState private var focusedField: Field?
    
    private enum Field {
        case text, author, tags
    }
    
    private var isEditing: Bool { entry != nil }
    
    private var hasChanges: Bool {
        guard let entry = entry else {
            return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return type != entry.type ||
               text != entry.text ||
               author != (entry.author ?? "") ||
               Entry.normalizeTags(from: tagsString) != entry.tags ||
               favorite != entry.favorite
    }
    
    init(entry: Entry?) {
        self.entry = entry
        _type = State(initialValue: entry?.type ?? .quote)
        _text = State(initialValue: entry?.text ?? "")
        _author = State(initialValue: entry?.author ?? "")
        _tagsString = State(initialValue: entry?.tags.joined(separator: ", ") ?? "")
        _favorite = State(initialValue: entry?.favorite ?? false)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    typePicker
                    textEditor
                    authorField
                    tagsField
                    tagSuggestions
                    favoriteToggle
                    
                    if isEditing {
                        deleteButton
                        timestamps
                    }
                }
                .padding()
                .padding(.bottom, 40)
            }
            .navigationTitle(isEditing ? "Edit" : "New entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .fontWeight(.semibold)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .confirmationDialog("Delete this entry?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let entry = entry {
                        store.remove(entry.id)
                    }
                    dismiss()
                }
            } message: {
                Text("This can't be undone.")
            }
            .onAppear {
                if !isEditing {
                    focusedField = .text
                }
            }
        }
        .interactiveDismissDisabled(hasChanges)
    }
    
    private var typePicker: some View {
        Picker("Type", selection: $type) {
            ForEach(EntryType.allCases) { entryType in
                Text(entryType.label).tag(entryType)
            }
        }
        .pickerStyle(.segmented)
    }
    
    private var textEditor: some View {
        TextField(type.placeholder, text: $text, axis: .vertical)
            .font(.system(size: 20, design: .serif))
            .lineLimit(5...20)
            .padding(16)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .focused($focusedField, equals: .text)
    }
    
    private var authorField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(type.authorLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
            
            TextField(type.authorPlaceholder, text: $author)
                .textContentType(.name)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(Color(.secondarySystemBackground), in: Capsule())
                .focused($focusedField, equals: .author)
                .submitLabel(.next)
                .onSubmit {
                    focusedField = .tags
                }
        }
    }
    
    private var tagsField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tags")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
            
            TextField("discipline, stoic, work", text: $tagsString)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(Color(.secondarySystemBackground), in: Capsule())
                .focused($focusedField, equals: .tags)
                .submitLabel(.done)
                .onSubmit {
                    focusedField = nil
                }
        }
    }
    
    @ViewBuilder
    private var tagSuggestions: some View {
        let currentTags = Set(Entry.normalizeTags(from: tagsString))
        let suggestions = store.allTags().filter { !currentTags.contains($0) }.prefix(12)
        
        if !suggestions.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(suggestions), id: \.self) { tag in
                        Button {
                            addTag(tag)
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
            .scrollClipDisabled()
        }
    }
    
    private var favoriteToggle: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                favorite.toggle()
            }
        } label: {
            HStack {
                Text(favorite ? "★" : "☆")
                    .font(.title2)
                    .foregroundColor(favorite ? Color.yellow : Color.secondary)
                
                Text("Favorite")
                    .foregroundColor(favorite ? Color.primary : Color.secondary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    
    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            Text("Delete entry")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .foregroundStyle(.red)
        .padding(.top, 8)
    }
    
    @ViewBuilder
    private var timestamps: some View {
        if let entry = entry {
            let dateFormatter: DateFormatter = {
                let f = DateFormatter()
                f.dateStyle = .medium
                f.timeStyle = .short
                return f
            }()
            
            VStack(spacing: 2) {
                Text("Created \(dateFormatter.string(from: entry.createdAt))")
                if entry.updatedAt != entry.createdAt {
                    Text("Edited \(dateFormatter.string(from: entry.updatedAt))")
                }
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
            .padding(.top, 8)
        }
    }
    
    private func addTag(_ tag: String) {
        let current = Entry.normalizeTags(from: tagsString)
        if !current.contains(tag) {
            if tagsString.isEmpty {
                tagsString = tag
            } else {
                tagsString = tagsString.trimmingCharacters(in: .whitespaces)
                if !tagsString.hasSuffix(",") {
                    tagsString += ", "
                } else {
                    tagsString += " "
                }
                tagsString += tag
            }
        }
    }
    
    private func save() {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        var updatedEntry = entry ?? Entry()
        updatedEntry.type = type
        updatedEntry.text = trimmedText
        updatedEntry.author = author.trimmingCharacters(in: .whitespaces).isEmpty ? nil : author.trimmingCharacters(in: .whitespaces)
        updatedEntry.tags = Entry.normalizeTags(from: tagsString)
        updatedEntry.favorite = favorite
        
        store.upsert(updatedEntry)
        dismiss()
    }
}

#Preview("New") {
    EntryEditorView(entry: nil)
        .environment(EntryStore.shared)
}

#Preview("Edit") {
    EntryEditorView(entry: Entry(
        type: .quote,
        text: "Sample quote text",
        author: "Author Name",
        tags: ["tag1", "tag2"],
        favorite: true
    ))
    .environment(EntryStore.shared)
}
