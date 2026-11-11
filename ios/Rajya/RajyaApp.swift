import SwiftUI

@main struct RajyaApp: App {
    @StateObject private var session = AppSession()
    var body: some Scene {
        WindowGroup {
            AppTabs().environmentObject(session).tint(Royal.wine)
                .task { await session.refresh() }
                .sheet(isPresented: $session.showLogin) { AuthenticationView().environmentObject(session) }
        }
    }
}
struct AppTabs: View {
    @EnvironmentObject var session: AppSession
    @State private var tab = 0
    var body: some View {
        TabView(selection: $tab) {
            NavigationStack { HomeView(tab: $tab) }.tabItem { Label("මුල් පිටුව", systemImage: "house") }.tag(0)
            NavigationStack { LibraryView() }.tabItem { Label("පුස්තකාලය", systemImage: "books.vertical") }.tag(1)
            NavigationStack { LearningView() }.tabItem { Label("ඉගෙනුම", systemImage: "graduationcap") }.tag(2)
            NavigationStack { ChatView() }.tabItem { Label("සහායක", systemImage: "sparkles") }.tag(3)
            NavigationStack { AccountView() }.tabItem { Label("ගිණුම", systemImage: "person.crop.circle") }.tag(4)
        }.id(session.generation)
    }
}
struct HomeView: View {
    @EnvironmentObject var session: AppSession
    @Binding var tab: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("K EDUCATION · රාජ්‍ය").font(.caption.weight(.semibold)).foregroundStyle(Royal.gold)
                    Text("ආයුබෝවන්\(session.user.map { ", " + $0["name"].text.components(separatedBy: " ").first! } ?? "").")
                        .font(.largeTitle.bold()).foregroundStyle(Royal.wine)
                    Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide)).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 18) {
                    Image(systemName: "sparkles").font(.largeTitle).foregroundStyle(Royal.gold)
                    Text("දැනුමෙන්\nවිශ්වාසයෙන් ඉදිරියට.").font(.title.bold()).foregroundStyle(.white)
                    Text("ඔබේ රාජ්‍ය සේවා දැනුම් සහකරු").foregroundStyle(.white.opacity(0.8))
                    Button { tab = 3 } label: { Label("සහායකගෙන් අසන්න", systemImage: "arrow.up.right") }
                        .buttonStyle(.borderedProminent).tint(Royal.gold).foregroundStyle(Royal.wine)
                }.padding(26).frame(maxWidth: .infinity, alignment: .leading)
                    .background(LinearGradient(colors: [Royal.wine, Color(red: 0.17, green: 0.025, blue: 0.06)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 26))
                HStack(spacing: 14) {
                    metric(String(ReferenceBook.all.count), "මූලාශ්‍ර පොත්", "books.vertical")
                    metric(String(ReferenceBook.all.reduce(0) { $0 + $1.pages }), "මුල් PDF පිටු", "doc.text")
                }
                Text("අද ඉගෙන ගනිමු").font(.title2.bold())
                quickLink("දැනුම් පුස්තකාලය", "Read your reference collection offline", "book.closed") { tab = 1 }
                quickLink("පාඩම් සහ පුහුණුව", "Lessons and source-based questions", "graduationcap") { tab = 2 }
                NavigationLink { ClausesView() } label: { tile("වගන්ති සෙවුම", "Find the original provision", "text.magnifyingglass") }.buttonStyle(.plain)
                NavigationLink { WorkspaceView() } label: { tile("මගේ අවකාශය", "Your notes and letter drafts", "square.and.pencil") }.buttonStyle(.plain)
                if let error = session.error { Notice(text: error); Button("Retry connection") { Task { await session.refresh() } } }
                Notice(text: "K Education (Pvt) Ltd is a private education provider, not a government app. Amendment coverage is unconfirmed. Check original sources before acting.")
            }.padding(22).opacity(visible ? 1 : 0).offset(y: visible ? 0 : 12)
        }.background(Royal.paper).navigationTitle("රාජ්‍ය").navigationBarTitleDisplayMode(.inline)
            .onAppear { withAnimation(reduceMotion ? nil : .easeOut(duration: 0.45)) { visible = true } }
    }
    private func metric(_ value: String, _ title: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) { Image(systemName: symbol).foregroundStyle(Royal.gold); Text(value).font(.title.bold()); Text(title).font(.caption).foregroundStyle(.secondary) }
            .frame(maxWidth: .infinity, alignment: .leading).padding(18).background(.background, in: RoundedRectangle(cornerRadius: 18))
    }
    private func tile(_ title: String, _ subtitle: String, _ symbol: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: symbol).font(.title2).foregroundStyle(Royal.gold).frame(width: 42)
            VStack(alignment: .leading, spacing: 5) { Text(title).font(.headline); Text(subtitle).font(.caption).foregroundStyle(.secondary) }
            Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
        }.padding(20).background(.background, in: RoundedRectangle(cornerRadius: 18))
    }
    private func quickLink(_ title: String, _ subtitle: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { tile(title, subtitle, symbol) }.buttonStyle(.plain)
    }
}
