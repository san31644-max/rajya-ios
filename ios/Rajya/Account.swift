import SwiftUI

struct AuthenticationView: View {
    @EnvironmentObject var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @State private var register = false
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var busy = false
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: "graduationcap.fill").font(.largeTitle).foregroundStyle(Royal.gold)
                        Text(register ? "අලුත් ගමනක් අරඹමු." : "නැවතත් සාදරයෙන්.").font(.title.bold()).foregroundStyle(Royal.wine)
                        Text("K Education (Pvt) Ltd").font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical)
                    Picker("Account", selection: $register) { Text("Sign in").tag(false); Text("Create account").tag(true) }.pickerStyle(.segmented)
                }
                Section {
                    if register { TextField("සම්පූර්ණ නම / Full name", text: $name).textContentType(.name) }
                    TextField("විද්‍යුත් තැපෑල / Email", text: $email).keyboardType(.emailAddress).textContentType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("මුරපදය / Password", text: $password).textContentType(register ? .newPassword : .password)
                    if register { Text("Use at least 10 characters for your password.").font(.caption).foregroundStyle(.secondary) }
                    ErrorNotice(message: error)
                    Button {
                        busy = true; error = nil
                        Task {
                            defer { busy = false }
                            do { try await session.authenticate(email: email, password: password, name: register ? name : nil); password = ""; dismiss() }
                            catch { self.error = error.localizedDescription }
                        }
                    } label: { HStack { Text(register ? "ගිණුම සාදන්න" : "පිවිසෙන්න"); Spacer(); if busy { ProgressView() } else { Image(systemName: "arrow.right") } } }
                        .disabled(busy || email.isEmpty || password.isEmpty || (register && (name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.count < 10)))
                }.disabled(busy)
                Section { Text("Your name and email are used to manage your account and saved learning data. You can delete your account in Account settings.").font(.footnote); Link("Privacy policy", destination: AppSession.baseURL.appendingPathComponent("privacy.php")) }
            }.navigationTitle(register ? "Create account" : "Sign in").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(busy) } }
        }.interactiveDismissDisabled(busy)
    }
}
struct AccountView: View {
    @EnvironmentObject var session: AppSession
    @State private var error: String?
    @State private var busy = false
    var body: some View {
        List {
            if let user = session.user {
                Section {
                    Label { VStack(alignment: .leading, spacing: 6) { Text(user["name"].text).font(.headline); Text(user["email"].text).font(.caption).foregroundStyle(.secondary) } } icon: { Image(systemName: "person.crop.circle.fill").font(.largeTitle).foregroundStyle(Royal.gold) }.padding(.vertical)
                    Label(session.subscription["active"].flag ? "Active membership / සක්‍රියයි" : "Free account / නොමිලේ", systemImage: "checkmark.seal")
                    if !session.subscription["expires_at"].text.isEmpty { Text("Membership ends: \(session.subscription["expires_at"].text)").font(.caption) }
                }
                Section("ඔබේ අවකාශය") {
                    NavigationLink("සටහන් සහ ලිපි / Notes & drafts") { WorkspaceView() }
                    NavigationLink("සුරැකි සංවාද / Conversations") { ConversationList() }
                    NavigationLink("ආදර්ශ විභාග / Self-assessments") { ExamLobby() }
                    NavigationLink("ලිපි ආකෘති / Letter templates") { LetterTemplates() }
                }
                Section {
                    ErrorNotice(message: error)
                    Button("Sign out", role: .destructive) {
                        busy = true
                        Task { defer { busy = false }; do { try await session.logout() } catch { self.error = error.localizedDescription } }
                    }.disabled(busy)
                    NavigationLink("Delete account and data") { DeleteAccountView() }.foregroundStyle(.red)
                }
            } else { Section { Button("Sign in / Create account") { session.showLogin = true } } }
            Section("About Rajya") {
                Text("K Education (Pvt) Ltd · Private education platform. Not a government application.").font(.footnote)
                Text("Source editions: Establishments Code I (2013), II (1999), Financial Regulations (1992), and the supplied disciplinary-procedure study reference (edition unconfirmed). Amendment coverage is unconfirmed.").font(.footnote)
                Link("Privacy policy", destination: AppSession.baseURL.appendingPathComponent("privacy.php"))
                Link("Contact support", destination: URL(string: "mailto:hello@keducation.site")!)
                Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0")").font(.caption).foregroundStyle(.secondary)
            }
        }.navigationTitle("මගේ ගිණුම").refreshable { await session.refresh() }
    }
}
struct DeleteAccountView: View {
    @EnvironmentObject var session: AppSession
    @State private var password = ""
    @State private var confirmation = ""
    @State private var confirm = false
    @State private var busy = false
    @State private var error: String?
    var body: some View {
        Form {
            Section { Notice(text: "This permanently deletes your account and associated conversations, photos, notes, bookmarks, drafts, progress, exam history and payment-request records. This cannot be undone. Operational logs may remain for up to 30 days under the privacy policy.") }
            Section {
                SecureField("Current password", text: $password).textContentType(.password)
                TextField("Type DELETE", text: $confirmation).textInputAutocapitalization(.characters).autocorrectionDisabled()
                ErrorNotice(message: error)
                Button("Permanently delete account", role: .destructive) { confirm = true }.disabled(busy || password.isEmpty || confirmation != "DELETE")
                if busy { ProgressView() }
            }
        }.navigationTitle("Delete account").confirmationDialog("Permanently delete your account and data?", isPresented: $confirm, titleVisibility: .visible) {
            Button("Delete permanently", role: .destructive) {
                busy = true
                Task {
                    defer { busy = false }
                    do { _ = try await session.request("delete_account", body: ["password": .string(password), "confirmation": .string(confirmation)]); password = ""; session.clearSession() }
                    catch { self.error = error.localizedDescription }
                }
            }
        }
    }
}
