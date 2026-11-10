import Foundation
import SwiftUI

// PHP PDO may encode database IDs/counts as strings or JSON numbers.
enum Value: Codable, Equatable, Sendable, Identifiable {
    var id: String { self["id"].text }
    case object([String: Value]), array([Value]), string(String), number(Double), bool(Bool), null
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([String: Value].self) { self = .object(v) }
        else { self = .array(try c.decode([Value].self)) }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .object(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .bool(let v): try c.encode(v)
        case .null: try c.encodeNil()
        }
    }
    subscript(_ key: String) -> Value { if case .object(let v) = self { return v[key] ?? .null }; return .null }
    var text: String {
        switch self {
        case .string(let v): return v
        case .number(let v): return v.rounded() == v ? String(format: "%.0f", v) : String(v)
        case .bool(let v): return v ? "true" : "false"
        default: return ""
        }
    }
    var int: Int { Int(text) ?? 0 }
    var flag: Bool { self == .bool(true) || text == "1" }
    var decoded: Value {
        if case .string(let v) = self, let data = v.data(using: .utf8), let result = try? JSONDecoder().decode(Value.self, from: data) { return result }
        return self
    }
    var list: [Value] { if case .array(let v) = decoded { return v }; return [] }
    var dictionary: [String: Value] { if case .object(let v) = decoded { return v }; return [:] }
    static func id(_ n: Int) -> Value { .number(Double(n)) }
}

struct ServiceError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

@MainActor final class AppSession: ObservableObject {
    static let baseURL = URL(string: Bundle.main.object(forInfoDictionaryKey: "RajyaAPIBaseURL") as? String ?? "https://exam.keducation.site/")!
    @Published var user: Value? = nil
    @Published var subscription: Value = .null
    @Published var booting = true
    @Published var error: String?
    @Published var generation = UUID()
    @Published var showLogin = false
    private var csrf: String?
    private var statusTask: Task<Value, Error>?
    private let network: URLSession
    init(network: URLSession? = nil) {
        if let network { self.network = network; return }
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = true
        config.httpCookieAcceptPolicy = .always
        config.timeoutIntervalForRequest = 90
        config.httpAdditionalHeaders = ["User-Agent": "RajyaNativeIOS/1", "Accept": "application/json"]
        self.network = URLSession(configuration: config)
    }
    func request(_ action: String, query: [String: String] = [:], body: [String: Value]? = nil) async throws -> Value {
        if action == "status" { return try await fetchStatus() }
        // Establish one session cookie before any parallel online screen requests.
        if csrf == nil { _ = try await fetchStatus() }
        return try await perform(action, query: query, body: body)
    }
    private func fetchStatus() async throws -> Value {
        if let statusTask { return try await statusTask.value }
        let task = Task { try await perform("status") }
        statusTask = task
        defer { statusTask = nil }
        return try await task.value
    }
    private func perform(_ action: String, query: [String: String] = [:], body: [String: Value]? = nil) async throws -> Value {
        var url = URLComponents(url: Self.baseURL.appendingPathComponent("api.php"), resolvingAgainstBaseURL: false)!
        url.queryItems = [URLQueryItem(name: "action", value: action)] + query.sorted(by: { $0.key < $1.key }).map { URLQueryItem(name: $0.key, value: $0.value) }
        var urlRequest = URLRequest(url: url.url!)
        urlRequest.cachePolicy = .reloadIgnoringLocalCacheData
        if let body {
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.setValue(csrf, forHTTPHeaderField: "X-CSRF-Token")
            urlRequest.httpBody = try JSONEncoder().encode(Value.object(body))
        }
        let (data, response) = try await network.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else { throw ServiceError(message: "The server did not respond.") }
        guard let value = try? JSONDecoder().decode(Value.self, from: data) else { throw ServiceError(message: "The service is unavailable. Please try again.") }
        if http.statusCode == 401 { user = nil; subscription = .null; csrf = nil; generation = UUID() }
        guard (200..<300).contains(http.statusCode) else {
            throw ServiceError(message: value["error"].text.isEmpty ? "Request failed (\(http.statusCode))." : value["error"].text)
        }
        if !value["csrf"].text.isEmpty { csrf = value["csrf"].text }
        return value
    }
    func refresh() async {
        defer { booting = false }
        do {
            let value = try await request("status")
            user = value["user"] == .null ? nil : value["user"]
            subscription = value["subscription"]
            error = value["ready"].flag ? nil : "Online services are unavailable. Your offline library is still available."
        } catch { self.error = error.localizedDescription }
    }
    func authenticate(email: String, password: String, name: String?) async throws {
        var body: [String: Value] = ["email": .string(email.trimmingCharacters(in: .whitespacesAndNewlines)), "password": .string(password)]
        if let name { body["name"] = .string(name) }
        _ = try await request(name == nil ? "login" : "register", body: body)
        await refresh()
        guard user != nil else { throw ServiceError(message: error ?? "Sign-in could not be confirmed. Try again.") }
        generation = UUID(); showLogin = false
    }
    func logout() async throws {
        _ = try await request("logout", body: [:])
        clearSession()
    }
    func clearSession() {
        user = nil; subscription = .null; csrf = nil; generation = UUID()
        if let storage = network.configuration.httpCookieStorage { storage.cookies?.forEach { storage.deleteCookie($0) } }
    }
}

enum Royal {
    static let wine = Color(red: 0.30, green: 0.045, blue: 0.095)
    static let gold = Color(red: 0.80, green: 0.61, blue: 0.25)
    static let paper = Color(red: 0.98, green: 0.96, blue: 0.92)
}
struct Notice: View {
    let text: String
    var body: some View {
        Label(text, systemImage: "info.circle").font(.footnote).foregroundStyle(.secondary)
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(Royal.gold.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
    }
}
struct ErrorNotice: View {
    let message: String?
    var body: some View { if let message { Text(message).font(.callout).foregroundStyle(.red).accessibilityLabel("Error: \(message)") } }
}
struct SignInPrompt: View {
    @EnvironmentObject var session: AppSession
    var body: some View {
        ContentUnavailableView {
            Label("ඔබේ ගිණුමට පිවිසෙන්න", systemImage: "person.crop.circle")
        } description: { Text("Sign in to use your conversations, notes and learning progress. The reference library works without an account.") }
        actions: { Button("Sign in / ගිණුමට පිවිසෙන්න") { session.showLogin = true }.buttonStyle(.borderedProminent) }
    }
}
