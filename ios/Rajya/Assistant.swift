import SwiftUI
import PhotosUI
import UIKit

struct ChatMessage: Identifiable {
    let id: UUID = UUID()
    let role: String
    let content: String
    let sources: [Value]
    var hasPhoto = false
}
struct ChatView: View {
    @EnvironmentObject var session: AppSession
    let existingID: Int
    @State private var conversationID: Int
    @State private var messages: [ChatMessage] = []
    @State private var text = ""
    @State private var language = "si"
    @State private var mode = "knowledge"
    @State private var busy = false
    @State private var loading = false
    @State private var error: String?
    @State private var consent = false
    @State private var showConsent = false
    @State private var report: ReportDraft?
    @State private var photo: PhotosPickerItem?
    @State private var image: Data?
    @State private var imageLoading = false
    @State private var pendingToken: String?
    init(conversationID: Int = 0) { existingID = conversationID; _conversationID = State(initialValue: conversationID) }
    var body: some View {
        Group {
            if session.user == nil { SignInPrompt() }
            else { chatBody }
        }.navigationTitle("බුද්ධිමත් සහායක").navigationBarTitleDisplayMode(.inline)
            .toolbar { NavigationLink { ConversationList() } label: { Image(systemName: "clock.arrow.circlepath") }.accessibilityLabel("Saved conversations") }
            .task { if existingID > 0 { await loadConversation() } }
            .sheet(isPresented: $showConsent) { consentSheet }
            .sheet(item: $report) { draft in ReportView(answer: draft.answer) }
            .task(id: photo) { await preparePhoto() }
    }
    private var chatBody: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("Language", selection: $language) { Text("සිංහල").tag("si"); Text("தமிழ்").tag("ta"); Text("English").tag("en") }
                Picker("Mode", selection: $mode) { Text("Knowledge").tag("knowledge"); Text("Scenario").tag("scenario"); Text("General").tag("general") }
            }.font(.caption).padding(.horizontal).disabled(busy || loading)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        if messages.isEmpty && !loading {
                            VStack(alignment: .leading, spacing: 16) {
                                Image(systemName: "sparkles").font(.largeTitle).foregroundStyle(Royal.gold)
                                Text("අද ඔබට දැනගන්න\nඅවශ්‍ය කුමක්ද?").font(.title.bold()).foregroundStyle(Royal.wine)
                                Notice(text: "AI can make mistakes. Check the cited original PDF pages. Do not send confidential or personal information.")
                            }.padding(.vertical, 20)
                        }
                        if loading { ProgressView() }
                        ForEach(messages) { message in
                            VStack(alignment: .leading, spacing: 12) {
                                Label(message.role == "user" ? "ඔබ" : "රාජ්‍ය AI", systemImage: message.role == "user" ? "person" : "sparkles").font(.caption.bold())
                                if message.hasPhoto { Label("Photo included", systemImage: "photo").font(.caption) }
                                Text(message.content).textSelection(.enabled).lineSpacing(5)
                                if message.role == "assistant" {
                                    SourceLinks(sources: message.sources)
                                    HStack { ShareLink(item: message.content) { Label("Share", systemImage: "square.and.arrow.up") }; Spacer(); Button("Report answer") { report = ReportDraft(answer: message.content) } }.font(.caption)
                                }
                            }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                                .background(message.role == "user" ? Royal.wine.opacity(0.08) : Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
                                .id(message.id)
                        }
                        if busy { HStack { ProgressView(); Text("පිළිතුර සකසමින්…").font(.caption) }.padding() }
                        Color.clear.frame(height: 1).id("bottom")
                    }.padding(18)
                }.onChange(of: messages.count) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
                    .onChange(of: busy) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
            }
            VStack(alignment: .leading, spacing: 10) {
                ErrorNotice(message: error)
                if let image, let uiImage = UIImage(data: image) {
                    HStack {
                        Image(uiImage: uiImage).resizable().scaledToFit().frame(height: 72).clipShape(RoundedRectangle(cornerRadius: 8))
                        Text("This photo will be sent to Google Gemini with your question. Remove personal details before choosing it.").font(.caption)
                        Button { Task { await removePhoto() } } label: { Image(systemName: "xmark.circle.fill") }.accessibilityLabel("Remove photo").disabled(busy)
                    }
                }
                HStack(alignment: .bottom, spacing: 12) {
                    PhotosPicker(selection: $photo, matching: .images) { Image(systemName: "photo.badge.plus").font(.title2).padding(.vertical, 8) }.disabled(busy || loading || imageLoading || pendingToken != nil).accessibilityLabel("Choose a photo")
                    TextField("ඔබේ ප්‍රශ්නය ලියන්න…", text: $text, axis: .vertical).lineLimit(1...5).padding(12).background(Royal.paper, in: RoundedRectangle(cornerRadius: 12))
                    Button { if consent { Task { await send() } } else { showConsent = true } } label: { Image(systemName: "arrow.up.circle.fill").font(.largeTitle) }
                        .disabled(busy || loading || imageLoading || (text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && image == nil) || text.count > 5000).accessibilityLabel("Send question")
                }
                if imageLoading { ProgressView("Preparing photo…") }
            }.padding(14).background(.background)
        }.background(Color(uiColor: .systemGroupedBackground))
    }
    private var consentSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 22) {
                Image(systemName: "hand.raised.fill").font(.largeTitle).foregroundStyle(Royal.gold)
                Text("AI භාවිතයට පෙර").font(.title.bold())
                Text("Your question, relevant conversation history and selected photos are sent to Google Gemini to generate a response. Conversations are saved to your account on the Rajya server. Remove confidential information and other people’s personal data before sending. AI can be wrong; check original sources.")
                Text("By continuing, you agree to this data being sent for AI processing.").font(.callout.bold())
                Link("Read the privacy policy", destination: AppSession.baseURL.appendingPathComponent("privacy.php"))
                Button("Agree and send") { consent = true; showConsent = false; Task { await send() } }.buttonStyle(.borderedProminent)
                Button("Cancel", role: .cancel) { showConsent = false }
                Spacer()
            }.padding(26).navigationTitle("AI disclosure")
        }
    }
    @MainActor private func preparePhoto() async {
        guard let photo else { return }
        imageLoading = true; defer { imageLoading = false }
        do {
            guard let raw = try await photo.loadTransferable(type: Data.self), let source = UIImage(data: raw) else { throw ServiceError(message: "This photo could not be opened.") }
            let longest = max(source.size.width, source.size.height)
            let ratio = min(1, 2048 / max(1, longest))
            let size = CGSize(width: source.size.width * ratio, height: source.size.height * ratio)
            let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
            let rendered = UIGraphicsImageRenderer(size: size, format: format).image { context in
                UIColor.white.setFill(); context.fill(CGRect(origin: .zero, size: size)); source.draw(in: CGRect(origin: .zero, size: size))
            }
            guard let jpeg = rendered.jpegData(compressionQuality: 0.8), jpeg.count <= 4_194_304 else { throw ServiceError(message: "Choose a smaller photo (maximum 4 MB).") }
            image = jpeg; error = nil
        } catch { self.error = error.localizedDescription }
    }
    @MainActor private func removePhoto() async {
        if let pendingToken {
            do { _ = try await session.request("delete_image", body: ["token": .string(pendingToken)]); self.pendingToken = nil }
            catch { self.error = error.localizedDescription; return }
        }
        image = nil; photo = nil
    }
    @MainActor private func send() async {
        guard !busy, consent else { return }
        let question = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty || image != nil else { return }
        busy = true; error = nil; defer { busy = false }
        do {
            if let image, pendingToken == nil {
                let uploaded = try await session.request("upload_image", body: ["image": .string("data:image/jpeg;base64," + image.base64EncodedString()), "name": .string("question.jpg")])
                let token = uploaded["token"].text
                guard !token.isEmpty else { throw ServiceError(message: "The photo upload could not be confirmed.") }
                pendingToken = token
            }
            let tokens = pendingToken.map { [Value.string($0)] } ?? []
            let result = try await session.request("chat", body: ["message": .string(question), "language": .string(language), "mode": .string(mode), "conversation_id": .id(conversationID), "redact": .bool(true), "image_consent": .bool(true), "attachment_ids": .array(tokens)])
            conversationID = result["conversation_id"].int
            messages.append(ChatMessage(role: "user", content: result["submitted_message"].text, sources: [], hasPhoto: !tokens.isEmpty))
            messages.append(ChatMessage(role: "assistant", content: result["answer"].text, sources: result["sources"].list))
            text = ""; image = nil; photo = nil; pendingToken = nil
            session.subscription = result["subscription"]
        } catch { self.error = error.localizedDescription }
    }
    @MainActor private func loadConversation() async {
        loading = true; defer { loading = false }
        do {
            let result = try await session.request("conversation", query: ["id": String(existingID)])
            language = result["language"].text; mode = result["mode"].text
            messages = result["messages"].list.map { ChatMessage(role: $0["role"].text, content: $0["content"].text, sources: $0["sources"].list, hasPhoto: !$0["attachments"].list.isEmpty) }
        } catch { self.error = error.localizedDescription }
    }
}
struct ReportDraft: Identifiable { let id = UUID(); let answer: String }
struct ReportView: View {
    @EnvironmentObject var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @State var answer: String
    @State private var category = "inaccurate"
    @State private var note = ""
    @State private var consent = false
    @State private var busy = false
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section { Notice(text: "Only the copy you submit here is sent to K Education reviewers. Remove personal information before submitting.") }
                Picker("Reason", selection: $category) { Text("Inaccurate").tag("inaccurate"); Text("Harmful").tag("harmful"); Text("Offensive").tag("offensive"); Text("Privacy").tag("privacy"); Text("Other").tag("other") }
                Section("Editable answer copy") { TextEditor(text: $answer).frame(minHeight: 160) }
                Section { TextField("Additional details", text: $note, axis: .vertical); Toggle("I reviewed this copy and agree to submit it", isOn: $consent); ErrorNotice(message: error) }
                Button("Submit report") {
                    busy = true
                    Task { defer { busy = false }; do { _ = try await session.request("report_ai_content", body: ["answer": .string(answer), "category": .string(category), "note": .string(note), "consent": .bool(consent)]); dismiss() } catch { self.error = error.localizedDescription } }
                }.disabled(!consent || busy || answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || answer.count > 30000 || note.count > 3000)
            }.disabled(busy).navigationTitle("Report AI answer").toolbar { Button("Cancel") { dismiss() }.disabled(busy) }
        }.interactiveDismissDisabled(busy)
    }
}
struct ConversationList: View {
    @EnvironmentObject var session: AppSession
    @State private var rows: [Value] = []
    @State private var error: String?
    @State private var deletion: Int?
    @State private var loading = false
    var body: some View {
        Group {
            if session.user == nil { SignInPrompt() }
            else {
                List {
                    ErrorNotice(message: error)
                    if loading { ProgressView() }
                    if rows.isEmpty && !loading { Text("No saved conversations yet.").foregroundStyle(.secondary) }
                    ForEach(rows) { row in
                        NavigationLink { ChatView(conversationID: row["id"].int) } label: { VStack(alignment: .leading) { Text(row["title"].text); Text(row["updated_at"].text).font(.caption).foregroundStyle(.secondary) } }
                            .swipeActions { Button("Delete", role: .destructive) { deletion = row["id"].int } }
                    }
                }.refreshable { await load() }.task { await load() }
            }
        }.navigationTitle("සංවාද").confirmationDialog("Delete this conversation and its photos?", isPresented: Binding(get: { deletion != nil }, set: { if !$0 { deletion = nil } }), titleVisibility: .visible) {
            Button("Delete", role: .destructive) { if let id = deletion { Task { do { _ = try await session.request("delete_conversation", body: ["id": .id(id)]); await load() } catch { self.error = error.localizedDescription }; deletion = nil } } }
        }
    }
    @MainActor private func load() async { loading = true; defer { loading = false }; do { rows = try await session.request("conversations").list; error = nil } catch { self.error = error.localizedDescription } }
}
