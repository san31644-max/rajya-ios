import SwiftUI
import PDFKit

struct ReferenceBook: Codable, Identifiable, Hashable {
    let id: Int
    let slug: String
    let title: String
    let edition: String
    let pages: Int
    let sha256: String
    var url: URL? { Bundle.main.url(forResource: slug, withExtension: "pdf") }
    static let all: [ReferenceBook] = {
        guard let url = Bundle.main.url(forResource: "catalog", withExtension: "json"),
              let data = try? Data(contentsOf: url), let catalog = try? JSONDecoder().decode(Catalog.self, from: data) else { return [] }
        return catalog.books
    }()
    private struct Catalog: Decodable { let books: [ReferenceBook] }
}
struct LibraryView: View {
    @State private var search = ""
    var body: some View {
        List {
            Section { Notice(text: "Available offline · අන්තර්ජාලය නොමැතිව කියවන්න. These are the supplied editions; current amendment coverage has not been confirmed.") }.listRowBackground(Color.clear)
            ForEach(ReferenceBook.all.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || $0.slug.localizedCaseInsensitiveContains(search) }) { book in
                NavigationLink { BookReader(book: book) } label: {
                    HStack(alignment: .top, spacing: 16) {
                        Image(systemName: "book.closed.fill").font(.title).foregroundStyle(Royal.gold).padding(.top, 5)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(book.title).font(.headline)
                            Text(book.edition).font(.caption).foregroundStyle(.secondary)
                            Label("\(book.pages) පිටු · Offline", systemImage: "arrow.down.circle.fill").font(.caption).foregroundStyle(Royal.wine)
                        }.padding(.vertical, 10)
                    }
                }
            }
            if ReferenceBook.all.isEmpty { Text("Reference files are missing. Run the iOS preparation script before building.").foregroundStyle(.red) }
            Section { NavigationLink("වගන්ති සොයන්න / Search provisions") { ClausesView() } }
        }.navigationTitle("පුස්තකාලය").searchable(text: $search, prompt: "පොතක් සොයන්න")
    }
}
@MainActor final class PDFReaderState: ObservableObject {
    let view = PDFView()
    @Published var page = 1
    @Published var query = ""
    @Published var matches: [PDFSelection] = []
    @Published var searchIndex = 0
    @Published var searching = false
    @Published var documentMissing = false
    private var observer: NSObjectProtocol?
    init(book: ReferenceBook, page: Int) {
        view.autoScales = true
        view.displayDirection = .vertical
        view.displayMode = .singlePageContinuous
        view.backgroundColor = UIColor(Royal.paper)
        if let url = book.url, let document = PDFDocument(url: url) {
            view.document = document
            if let initial = document.page(at: max(0, min(page - 1, document.pageCount - 1))) { view.go(to: initial) }
        } else { documentMissing = true }
        observer = NotificationCenter.default.addObserver(forName: .PDFViewPageChanged, object: view, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, let current = self.view.currentPage, let document = self.view.document else { return }
                self.page = document.index(for: current) + 1
            }
        }
        self.page = max(1, page)
    }
    deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }
    func jump(_ page: Int) { if let target = view.document?.page(at: page - 1) { view.go(to: target) } }
    func search() async {
        guard let url = view.document?.documentURL else { return }
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        searching = true
        // Search a separate PDFDocument away from the UI thread, return page indices only.
        let pages = await Task.detached(priority: .userInitiated) { () -> [Int] in
            guard !term.isEmpty, let document = PDFDocument(url: url) else { return [] }
            return document.findString(term, withOptions: .caseInsensitive).compactMap { $0.pages.first.map { document.index(for: $0) } }
        }.value
        matches = Array(Set(pages)).sorted().compactMap { index in
            guard let page = view.document?.page(at: index) else { return nil }
            return page.selection(for: page.bounds(for: .mediaBox))
        }
        searchIndex = 0; searching = false
        if let first = pages.first { jump(first + 1) }
    }
    func nextMatch() {
        guard !matches.isEmpty else { return }
        searchIndex = (searchIndex + 1) % matches.count
        view.go(to: matches[searchIndex]); view.setCurrentSelection(matches[searchIndex], animate: false)
    }
}
struct PDFSurface: UIViewRepresentable {
    @ObservedObject var reader: PDFReaderState
    func makeUIView(context: Context) -> PDFView { reader.view }
    func updateUIView(_ uiView: PDFView, context: Context) {}
}
struct BookReader: View {
    @EnvironmentObject var session: AppSession
    let book: ReferenceBook
    @StateObject private var reader: PDFReaderState
    @State private var jumpText = ""
    @State private var showJump = false
    @State private var bookmarkMessage = ""
    @State private var showBookmarkMessage = false
    @State private var saving = false
    init(book: ReferenceBook, page: Int = 1) {
        self.book = book
        _reader = StateObject(wrappedValue: PDFReaderState(book: book, page: page))
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("පොත තුළ සොයන්න", text: $reader.query).textInputAutocapitalization(.never).submitLabel(.search).onSubmit { Task { await reader.search() } }
                if reader.searching { ProgressView() }
                else { Button { Task { await reader.search() } } label: { Image(systemName: "magnifyingglass") }.accessibilityLabel("Search this PDF") }
                if !reader.matches.isEmpty { Button("\(reader.searchIndex + 1)/\(reader.matches.count)") { reader.nextMatch() } }
            }.padding(14).background(Royal.paper)
            if reader.documentMissing { ContentUnavailableView("Book unavailable", systemImage: "doc.questionmark", description: Text("The bundled source file could not be opened.")) }
            else { PDFSurface(reader: reader) }
            HStack {
                Button { reader.jump(max(1, reader.page - 1)) } label: { Image(systemName: "chevron.left") }.accessibilityLabel("Previous page")
                Spacer()
                Button("පිටුව \(reader.page) / \(book.pages)") { jumpText = String(reader.page); showJump = true }
                Spacer()
                Button { reader.jump(min(book.pages, reader.page + 1)) } label: { Image(systemName: "chevron.right") }.accessibilityLabel("Next page")
            }.padding(18).background(Royal.paper)
        }.navigationTitle(book.title).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button {
                    guard session.user != nil else { session.showLogin = true; return }
                    let page = reader.page
                    saving = true
                    Task {
                        defer { saving = false; showBookmarkMessage = true }
                        do {
                            _ = try await session.request("save_workspace", body: ["kind": .string("pagebookmark"), "title": .string("\(book.title) · PDF \(page)"), "body": .string("\(book.edition)\nPDF page \(page)"), "metadata": .object(["book_id": .id(book.id), "page_number": .id(page)])])
                            bookmarkMessage = "Page saved in your workspace."
                        } catch { bookmarkMessage = error.localizedDescription }
                    }
                } label: { Image(systemName: "bookmark") }.disabled(saving).accessibilityLabel("Save this page to your workspace")
                if let url = book.url { ShareLink(item: url) { Image(systemName: "square.and.arrow.up") } }
            }
            .alert("Saved page", isPresented: $showBookmarkMessage) { Button("OK", role: .cancel) {} } message: { Text(bookmarkMessage) }
            .alert("පිටුවට යන්න / Go to page", isPresented: $showJump) {
                TextField("1–\(book.pages)", text: $jumpText).keyboardType(.numberPad)
                Button("Go") { if let page = Int(jumpText), (1...book.pages).contains(page) { reader.jump(page) } }
                Button("Cancel", role: .cancel) {}
            }
    }
}
struct SourceLinks: View {
    let sources: [Value]
    var body: some View {
        ForEach(Array(sources.enumerated()), id: \.offset) { _, source in
            if let book = ReferenceBook.all.first(where: { $0.id == source["book_id"].int }) {
                NavigationLink { BookReader(book: book, page: max(1, source["page_number"].int)) } label: {
                    Label("\(book.title) · PDF \(max(1, source["page_number"].int))", systemImage: "doc.text.magnifyingglass").font(.caption)
                }
            } else if source["type"].text == "clause", source["id"].int > 0 {
                NavigationLink("වගන්තිය \(source["reference"].text)") { ClauseDetail(id: source["id"].int) }.font(.caption)
            }
        }
    }
}
struct ClausesView: View {
    @EnvironmentObject var session: AppSession
    @State private var query = ""
    @State private var page = 1
    @State private var rows: [Value] = []
    @State private var total = 0
    @State private var error: String?
    @State private var loading = false
    var body: some View {
        List {
            Notice(text: "Machine-extracted provisions may be incomplete. Review the source PDF and amendment coverage.")
            ErrorNotice(message: error)
            if loading { ProgressView() }
            ForEach(rows) { row in
                NavigationLink { ClauseDetail(id: row["id"].int) } label: {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(row["reference"].text).font(.caption.bold()).foregroundStyle(Royal.gold)
                        Text(row["title"].text).lineLimit(3)
                        Text(row["book_title"].text).font(.caption).foregroundStyle(.secondary)
                        ReviewStatus(status: row["status"].text)
                    }.padding(.vertical, 5)
                }
            }
            HStack { Button("Previous") { page -= 1 }.disabled(page <= 1); Spacer(); Text("\(page) / \(max(1, (total + 29) / 30))").font(.caption); Spacer(); Button("Next") { page += 1 }.disabled(page * 30 >= total) }.disabled(loading)
        }.navigationTitle("වගන්ති සෙවුම").searchable(text: $query)
            .task(id: "\(query)|\(page)") {
                do {
                    loading = true; defer { loading = false }
                    try await Task.sleep(for: .milliseconds(300)); try Task.checkCancellation()
                    let result = try await session.request("clause_index", query: ["q": query, "page": String(page)])
                    try Task.checkCancellation(); rows = result["rows"].list; total = result["total"].int; error = nil
                } catch is CancellationError {} catch { self.error = error.localizedDescription }
            }.onChange(of: query) { _, _ in page = 1 }
    }
}
struct ReviewStatus: View {
    let status: String
    var body: some View { Text(status == "verified" ? "Reviewed · සමාලෝචිත" : "Draft / unreviewed · කෙටුම්පත")
        .font(.caption2.weight(.medium)).foregroundStyle(status == "verified" ? Color.green : Color.orange) }
}
struct ClauseDetail: View {
    @EnvironmentObject var session: AppSession
    let id: Int
    @State private var clause: Value = .null
    @State private var error: String?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ErrorNotice(message: error)
                if clause == .null && error == nil { ProgressView() }
                else if clause != .null {
                    ReviewStatus(status: clause["status"].text)
                    Text(clause["title"].text).font(.title2.bold())
                    Notice(text: "Check the complete provision in the original PDF. Current amendment coverage is unconfirmed.")
                    Text(clause["official_text"].text).textSelection(.enabled)
                    if !clause["explanation"].text.isEmpty { Text("සරල පැහැදිලි කිරීම").font(.headline); Text(clause["explanation"].text).textSelection(.enabled) }
                    SourceLinks(sources: [clause])
                }
            }.padding(22)
        }.navigationTitle("වගන්තිය \(clause["reference"].text)").task {
            do { clause = try await session.request("clause_detail", query: ["id": String(id)]) } catch { self.error = error.localizedDescription }
        }
    }
}
