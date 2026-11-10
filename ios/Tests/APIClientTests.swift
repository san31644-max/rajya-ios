import XCTest
@testable import Rajya

final class StubProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            guard let handler = Self.handler else { throw URLError(.badServerResponse) }
            let (code, data) = try handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
final class APIClientTests: XCTestCase {
    private func makeNetwork() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        return URLSession(configuration: configuration)
    }
    override func tearDown() { StubProtocol.handler = nil; super.tearDown() }

    @MainActor func testMutationBootstrapsCSRFAndSendsIntegerAnswer() async throws {
        var actions: [String] = []
        StubProtocol.handler = { request in
            let action = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!.first { $0.name == "action" }!.value!
            actions.append(action)
            if action == "status" { return (200, Data(#"{"csrf":"test-token","ready":true,"user":null}"#.utf8)) }
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-CSRF-Token"), "test-token")
            let data: Data
            if let direct = request.httpBody { data = direct }
            else if let stream = request.httpBodyStream {
                stream.open(); defer { stream.close() }
                var bytes = Data(); var buffer = [UInt8](repeating: 0, count: 1024)
                while stream.hasBytesAvailable { let count = stream.read(&buffer, maxLength: buffer.count); if count <= 0 { break }; bytes.append(buffer, count: count) }
                data = bytes
            } else { throw ServiceError(message: "Missing JSON request body") }
            let body = try JSONDecoder().decode(Value.self, from: data)
            XCTAssertEqual(body["choice"], .number(0))
            return (200, Data(#"{"correct":true}"#.utf8))
        }
        let session = AppSession(network: makeNetwork())
        let result = try await session.request("learning_answer", body: ["id": .id(12), "choice": .id(0)])
        XCTAssertTrue(result["correct"].flag)
        XCTAssertEqual(actions, ["status", "learning_answer"])
    }
    @MainActor func testExpiredSessionClearsPrivateProfile() async throws {
        StubProtocol.handler = { _ in (401, Data(#"{"error":"Sign in again"}"#.utf8)) }
        let session = AppSession(network: makeNetwork())
        session.user = .object(["id": .id(12), "name": .string("Learner")])
        let generation = session.generation
        do { _ = try await session.request("workspace"); XCTFail("Expected authentication error") }
        catch { XCTAssertEqual(error.localizedDescription, "Sign in again") }
        XCTAssertNil(session.user)
        XCTAssertNotEqual(generation, session.generation)
    }
    @MainActor func testServerFailureDoesNotExposeHTMLAsUserData() async {
        StubProtocol.handler = { _ in (503, Data("<html>Service unavailable</html>".utf8)) }
        let session = AppSession(network: makeNetwork())
        do { _ = try await session.request("courses"); XCTFail("Expected a service error") }
        catch { XCTAssertEqual(error.localizedDescription, "The service is unavailable. Please try again.") }
    }
}
