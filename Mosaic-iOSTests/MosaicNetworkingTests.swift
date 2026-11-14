import Foundation
import XCTest
@testable import Mosaic_iOS

@MainActor
final class MosaicNetworkingTests: XCTestCase {
    func testAuthenticatedGETMapsTimeout() async throws {
        let stub = makeClient { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.timeoutInterval, 12)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
            throw URLError(.timedOut)
        }
        defer { stub.close() }
        await assertError(.timedOut("Mosaic took too long to respond. Please try again.")) {
            let _: [String: String] = try await stub.client.request("/timeout", token: "test-token")
        }
    }

    func testSendUses30SecondTimeout() async throws {
        let stub = makeClient { request in
            XCTAssertEqual(request.httpMethod, "PATCH")
            XCTAssertEqual(request.timeoutInterval, 30)
            return .init(status: 200, chunks: [Data(#"{"updated":true}"#.utf8)])
        }
        defer { stub.close() }
        let response: [String: Bool] = try await stub.client.send(method: "PATCH", path: "/api/me/profile", body: ["name": "Test"], token: "test-token")
        XCTAssertEqual(response, ["updated": true])
    }

    func testLegacyBadRequestPreservesValidationMessage() async {
        let stub = makeClient { _ in
            .init(status: 400, chunks: [Data(#"{"error":"Choose a supported source and file."}"#.utf8)])
        }
        defer { stub.close() }
        await assertError(.validation("Choose a supported source and file.")) {
            let _: [String: String] = try await stub.client.request("/legacy", token: "test-token")
        }
    }

    func testLegacyErrorsPreserveMessagesAndMapStatus() async {
        for (status, expected) in [(413, MosaicAPIError.validation("Upload too large")), (415, .validation("Upload too large")), (409, .conflict("Upload too large"))] {
            let stub = makeClient { _ in .init(status: status, chunks: [Data(#"{"error":"Upload too large"}"#.utf8)]) }
            defer { stub.close() }
            await assertError(expected) {
                let _: [String: String] = try await stub.client.request("/legacy", token: "test-token")
            }
        }
    }

    func testEnvelopeCodeTakesPriorityOverHTTPStatus() async {
        let stub = makeClient { _ in .init(status: 413, chunks: [Data(#"{"error":{"code":"FORBIDDEN","message":"Envelope wins"}}"#.utf8)]) }
        defer { stub.close() }
        await assertError(.forbidden("Envelope wins")) {
            let _: [String: String] = try await stub.client.publicRequest(path: "/envelope")
        }
    }

    func testAssistantUnavailableEnvelope() async {
        let stub = makeClient { _ in .init(status: 503, chunks: [Data(#"{"error":{"code":"ASSISTANT_UNAVAILABLE","message":"Assistant is resting"}}"#.utf8)]) }
        defer { stub.close() }
        await assertError(.assistantUnavailable("Assistant is resting")) {
            try await stub.client.mutate(path: "/assistant", body: ["prompt": "hello"], token: "test-token")
        }
        XCTAssertEqual(MosaicAPIError.assistantUnavailable("Assistant is resting").errorDescription, "Assistant is resting")
    }

    func testRetryAfterSecondsAndOriginalRateLimitCase() async {
        for (header, expected) in [("42", MosaicAPIError.rateLimitedFor("Slow down", retryAfter: 42)), (nil, .rateLimited("Slow down")), ("invalid", .rateLimited("Slow down")), ("-1", .rateLimited("Slow down"))] {
            let stub = makeClient { _ in
                .init(status: 429, headers: header.map { ["Retry-After": $0] } ?? [:], chunks: [Data(#"{"error":{"code":"RATE_LIMITED","message":"Slow down"}}"#.utf8)])
            }
            defer { stub.close() }
            await assertError(expected) {
                _ = try await stub.client.mutateReturningData(path: "/limited", body: ["value": 1], token: "test-token")
            }
        }
        XCTAssertEqual(MosaicAPIError.rateLimitedFor("Slow down", retryAfter: 42).errorDescription, "Slow down")
    }

    func testMutateReturningDataPreservesRawBody() async throws {
        let response = Data("unmodified response".utf8)
        let stub = makeClient { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            return .init(status: 201, chunks: [response])
        }
        defer { stub.close() }
        let data = try await stub.client.mutateReturningData(path: "/raw", body: ["value": 1], token: "test-token")
        XCTAssertEqual(data, response)
    }

    func testUploadAccepts207AndSendsHeadersAndRawBody() async throws {
        let body = Data([0, 1, 2, 255])
        let stub = makeClient { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.timeoutInterval, 300)
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Import-Mode"), "merge")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/zip")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
            let actual: Data?
            if let stream = request.httpBodyStream {
                stream.open(); defer { stream.close() }
                var collected = Data(); var buffer = [UInt8](repeating: 0, count: 128)
                while stream.hasBytesAvailable {
                    let count = stream.read(&buffer, maxLength: buffer.count)
                    guard count > 0 else { break }
                    collected.append(contentsOf: buffer.prefix(count))
                }
                actual = collected
            } else { actual = request.httpBody }
            XCTAssertEqual(actual, body)
            return .init(status: 207, chunks: [Data("partial success".utf8)])
        }
        defer { stub.close() }
        let (data, response) = try await stub.client.upload(path: "/upload", headers: ["X-Import-Mode": "merge", "Content-Type": "application/zip"], body: body, token: "test-token")
        XCTAssertEqual(response.statusCode, 207)
        XCTAssertEqual(data, Data("partial success".utf8))
    }

    func testDownloadPreservesDispositionFilenameAndBody() async throws {
        let stub = makeClient { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
            return .init(status: 200, headers: ["Content-Disposition": "attachment; filename=\"my-export.zip\""], chunks: [Data([0, 1]), Data([2, 3])])
        }
        defer { stub.close() }
        let url = try await stub.client.download(path: "/export", token: "test-token")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        XCTAssertEqual(url.lastPathComponent, "my-export.zip")
        XCTAssertTrue(url.path.hasPrefix(FileManager.default.temporaryDirectory.path))
        XCTAssertEqual(try Data(contentsOf: url), Data([0, 1, 2, 3]))
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        #if !targetEnvironment(simulator)
        XCTAssertEqual(attributes[.protectionKey] as? FileProtectionType, .complete)
        #endif
    }

    func testDownloadSanitizesFilenameAndUsesFallback() async throws {
        for (disposition, expected) in [("attachment; filename=\"../../nested/export.zip\"", "export.zip"), ("attachment", "mosaic-export.zip"), ("attachment; filename=\"..\"", "mosaic-export.zip"), ("attachment; filename*=UTF-8''my%20export.zip", "my export.zip")] {
            let stub = makeClient { _ in .init(status: 200, headers: ["Content-Disposition": disposition], chunks: [Data("zip".utf8)]) }
            defer { stub.close() }
            let url = try await stub.client.download(path: "/export", token: "test-token")
            defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
            XCTAssertEqual(url.lastPathComponent, expected)
        }
    }

    func testDownloadDecodesErrorBody() async {
        let stub = makeClient { _ in .init(status: 403, chunks: [Data(#"{"error":{"code":"FORBIDDEN","message":"Export denied"}}"#.utf8)]) }
        defer { stub.close() }
        await assertError(.forbidden("Export denied")) { _ = try await stub.client.download(path: "/export", token: "test-token") }
    }

    func testLinesReassemblesChunkBoundariesAndSkipsEmptyLines() async throws {
        let chunks = ["{\"n\":1}", "\n\n{\"n\":", "2}\r", "\n{\"n\":3}", "\n"]
        let stub = makeClient { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.timeoutInterval, 60)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            return .init(status: 200, chunks: chunks.map { Data($0.utf8) })
        }
        defer { stub.close() }
        var lines: [Data] = []
        for try await line in stub.client.lines(path: "/stream", body: ["prompt": "hello"], token: "test-token") { lines.append(line) }
        XCTAssertEqual(lines, [#"{"n":1}"#, #"{"n":2}"#, #"{"n":3}"#].map { Data($0.utf8) })
    }

    func testLinesThrowsFullEnvelopeOn403() async {
        let stub = makeClient { _ in .init(status: 403, chunks: [Data(#"{"error":{"code":"FOR"#.utf8), Data(#"BIDDEN","message":"No stream access"}}"#.utf8)]) }
        defer { stub.close() }
        await assertError(.forbidden("No stream access")) {
            for try await _ in stub.client.lines(path: "/stream", body: ["prompt": "hello"], token: "test-token") { XCTFail("Error responses must not yield lines") }
        }
    }

    private func assertError(_ expected: MosaicAPIError, operation: () async throws -> Void, file: StaticString = #filePath, line: UInt = #line) async {
        do { try await operation(); XCTFail("Expected an API error", file: file, line: line) }
        catch { XCTAssertEqual(error as? MosaicAPIError, expected, file: file, line: line) }
    }

    private func makeClient(handler: @escaping NetworkingURLProtocol.Handler) -> Stub {
        let host = "stub-\(UUID().uuidString.lowercased()).invalid"
        NetworkingURLProtocol.registry.set(handler, for: host)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [NetworkingURLProtocol.self]
        let session = URLSession(configuration: configuration)
        return Stub(client: MosaicAPIClient(baseURL: URL(string: "https://\(host)")!, session: session), session: session, host: host)
    }

    private struct Stub {
        let client: MosaicAPIClient; let session: URLSession; let host: String
        func close() { session.invalidateAndCancel(); NetworkingURLProtocol.registry.set(nil, for: host) }
    }
}

private final class NetworkingURLProtocol: URLProtocol, @unchecked Sendable {
    struct Response: Sendable {
        let status: Int
        var headers: [String: String] = [:]
        let chunks: [Data]
    }
    typealias Handler = @Sendable (URLRequest) throws -> Response
    // Unique hosts isolate concurrent tests; lock every access to the shared registry.
    final class Registry: @unchecked Sendable {
        private let lock = NSLock()
        private var handlers: [String: Handler] = [:]
        func set(_ handler: Handler?, for host: String) { lock.lock(); defer { lock.unlock() }; handlers[host] = handler }
        func get(_ host: String) -> Handler? { lock.lock(); defer { lock.unlock() }; return handlers[host] }
    }
    static let registry = Registry()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            guard let url = request.url, let handler = Self.registry.get(url.host ?? "") else { throw URLError(.unsupportedURL) }
            let response = try handler(request)
            let http = HTTPURLResponse(url: url, statusCode: response.status, httpVersion: "HTTP/1.1", headerFields: response.headers)!
            client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
            for chunk in response.chunks { client?.urlProtocol(self, didLoad: chunk) }
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
