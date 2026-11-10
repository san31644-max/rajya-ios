import SwiftUI

struct WorkspaceDraft: Identifiable { let id: Int; let kind: String; var title: String; var body: String }
struct WorkspaceView: View {
    @EnvironmentObject var session: AppSession
    @State private var items: [Value] = []
    @State private var error: String?
    @State private var loading = false
    @State private var editor: WorkspaceDraft?
    @State private var deletion: Int?
    var body: some View {
        Group {
            if session.user == nil { SignInPrompt() }
            else {
                List {
                    ErrorNotice(message: error)
                    if loading { ProgressView() }
                    if items.isEmpty && !loading { ContentUnavailableView("ඔබේ සටහන් මෙතැනින්", systemImage: "square.and.pencil", description: Text("Create a note or generate a letter from a template.")) }
                    ForEach(items) { item in
                        if item["kind"].text == "pagebookmark" {
                            SourceLinks(sources: [item["metadata"].decoded])
                        }
                        Button { editor = WorkspaceDraft(id: item["id"].int, kind: item["kind"].text, title: item["title"].text, body: item["body"].text) } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: item["kind"].text == "draft" ? "doc.text" : "note.text").foregroundStyle(Royal.gold)
                                VStack(alignment: .leading, spacing: 7) { Text(item["title"].text).font(.headline); Text(item["body"].text).font(.caption).lineLimit(2).foregroundStyle(.secondary); Text(item["updated_at"].text).font(.caption2).foregroundStyle(.secondary) }
                            }.padding(.vertical, 7)
                        }.buttonStyle(.plain).swipeActions { Button("Delete", role: .destructive) { deletion = item["id"].int } }
                    }
                }.task { await load() }.refreshable { await load() }
            }
        }.navigationTitle("මගේ අවකාශය")
            .toolbar { if session.user != nil { Button { editor = WorkspaceDraft(id: 0, kind: "note", title: "", body: "") } label: { Image(systemName: "square.and.pencil") }.accessibilityLabel("Create note") } }
            .sheet(item: $editor, onDismiss: { Task { await load() } }) { draft in NoteEditor(draft: draft) }
            .confirmationDialog("Delete this saved item?", isPresented: Binding(get: { deletion != nil }, set: { if !$0 { deletion = nil } }), titleVisibility: .visible) {
                Button("Delete", role: .destructive) { if let id = deletion { Task { do { _ = try await session.request("delete_workspace", body: ["id": .id(id)]); await load() } catch { self.error = error.localizedDescription }; deletion = nil } } }
            }
    }
    @MainActor private func load() async { guard session.user != nil else { return }; loading = true; defer { loading = false }; do { items = try await session.request("workspace")["items"].list; error = nil } catch { self.error = error.localizedDescription } }
}
struct NoteEditor: View {
    @EnvironmentObject var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @State var draft: WorkspaceDraft
    @State private var busy = false
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section { TextField("මාතෘකාව / Title", text: $draft.title); TextEditor(text: $draft.body).frame(minHeight: 280) }
                ErrorNotice(message: error)
                Section { ShareLink(item: draft.title + "\n\n" + draft.body) { Label("Share / Save to Files", systemImage: "square.and.arrow.up") } }
            }.disabled(busy).navigationTitle(draft.kind == "draft" ? "ලිපි කෙටුම්පත" : "සටහන")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(busy) }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") {
                        busy = true
                        Task { defer { busy = false }; do { _ = try await session.request("save_workspace", body: ["id": .id(draft.id), "kind": .string(draft.kind), "title": .string(draft.title), "body": .string(draft.body)]); dismiss() } catch { self.error = error.localizedDescription } }
                    }.disabled(busy || draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft.title.count > 190 || draft.body.count > 100000) }
                }
        }.interactiveDismissDisabled(busy)
    }
}
struct LetterTemplates: View {
    @EnvironmentObject var session: AppSession
    @State private var templates: [Value] = []
    @State private var error: String?
    var body: some View {
        List {
            Notice(text: "Generic draft templates, not institution-approved forms. Check every detail before using a letter.")
            ErrorNotice(message: error)
            ForEach(templates) { template in
                NavigationLink { LetterForm(template: template) } label: { VStack(alignment: .leading, spacing: 8) { Text(template["title"].text).font(.headline); Text(template["description"].text).font(.caption).foregroundStyle(.secondary); ReviewStatus(status: template["status"].text) } }
            }
        }.navigationTitle("ලිපි ආකෘති").task { do { templates = try await session.request("templates").list } catch { self.error = error.localizedDescription } }
    }
}
struct LetterForm: View {
    @EnvironmentObject var session: AppSession
    let template: Value
    @State private var values: [String: String] = [:]
    @State private var error: String?
    @State private var busy = false
    @State private var draft: WorkspaceDraft?
    var body: some View {
        Form {
            Notice(text: "Review all personal details before saving or sharing. Generated letters are saved privately to your account.")
            ForEach(Array(template["fields"].list.enumerated()), id: \.offset) { _, field in
                TextField(field["label"].text + (field["required"].flag ? " *" : ""), text: Binding(get: { values[field["name"].text] ?? "" }, set: { values[field["name"].text] = $0 }), axis: .vertical)
            }
            ErrorNotice(message: error)
            Button("ලිපිය සාදන්න / Generate draft") {
                guard session.user != nil else { session.showLogin = true; return }
                busy = true
                Task {
                    defer { busy = false }
                    do {
                        let result = try await session.request("make_letter", body: ["template_id": .id(template["id"].int), "values": .object(values.mapValues { .string($0) })])
                        draft = WorkspaceDraft(id: result["id"].int, kind: "draft", title: result["title"].text, body: result["body"].text)
                    } catch { self.error = error.localizedDescription }
                }
            }.disabled(busy || template["fields"].list.contains(where: { $0["required"].flag && (values[$0["name"].text] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }))
        }.disabled(busy).navigationTitle(template["title"].text).navigationBarTitleDisplayMode(.inline)
            .sheet(item: $draft) { draft in NoteEditor(draft: draft) }
    }
}
