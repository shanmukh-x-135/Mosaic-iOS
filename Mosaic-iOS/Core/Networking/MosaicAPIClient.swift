import Foundation
import os

private let networkLogger = Logger(subsystem: "com.shanmukhpgsspersonalteam.MosaiciOS", category: "Networking")

struct MosaicAPIClient: Sendable {
    let baseURL: URL; private let session: URLSession
    init(baseURL: URL, session: URLSession = .shared) { self.baseURL = baseURL; self.session = session }
    func request<T: Decodable>(_ path: String, token: String, as type: T.Type = T.self) async throws -> T {
        let clock = ContinuousClock(); let start = clock.now
        defer {
        #if DEBUG
            networkLogger.debug("Authenticated request completed in \(String(describing: start.duration(to: clock.now)), privacy: .public)")
        #endif
        }
        var request = try makeRequest(path: path, token: token); request.httpMethod = "GET"
        request.timeoutInterval = 12
        return try decode(try await responseData(for: request).0, as: type)
    }
    func publicRequest<T: Decodable>(path: String, queryItems: [URLQueryItem] = [], as type: T.Type = T.self) async throws -> T {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.path = path
        components?.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components?.url else { throw MosaicAPIError.invalidResponse }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return try await perform(request, as: type)
    }
    func makeRequest(path: String, token: String) throws -> URLRequest {
        guard let url = URL(string: path, relativeTo: baseURL) else { throw MosaicAPIError.invalidResponse }
        var request = URLRequest(url: url); request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization"); request.setValue("application/json", forHTTPHeaderField: "Accept"); return request
    }
    func mutate<Body: Encodable>(path: String, body: Body, token: String) async throws {
        _ = try await send(method: "POST", path: path, body: body, token: token)
    }
    /// Sends an authenticated body and decodes the response, used by endpoints
    /// such as `PATCH /api/me/profile` that return the updated resource.
    func send<Body: Encodable, Response: Decodable>(method: String, path: String, body: Body, token: String, as type: Response.Type = Response.self) async throws -> Response {
        let data = try await send(method: method, path: path, body: body, token: token)
        do { return try JSONDecoder.mosaic.decode(Response.self, from: data) }
        catch { throw MosaicAPIError.decoding("Mosaic returned data the app could not read.") }
    }
    @discardableResult
    private func send<Body: Encodable>(method: String, path: String, body: Body, token: String) async throws -> Data {
        var request = try makeRequest(path: path, token: token)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return try await responseData(for: request).0
    }
    /// Returns the unmodified successful POST response (including an empty body).
    func mutateReturningData<Body: Encodable>(path: String, body: Body, token: String) async throws -> Data {
        try await send(method: "POST", path: path, body: body, token: token)
    }
    func upload(path: String, headers: [String: String], body: Data, token: String) async throws -> (Data, HTTPURLResponse) {
        var request = try makeRequest(path: path, token: token)
        request.httpMethod = "POST"; request.timeoutInterval = 300; request.httpBody = body
        for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
        return try await responseData(for: request)
    }
    func download(path: String, token: String) async throws -> URL {
        var request = try makeRequest(path: path, token: token)
        request.timeoutInterval = 120
        do {
            let (bytes, response) = try await session.bytes(for: request)
            let manager = FileManager.default
            guard let http = response as? HTTPURLResponse else { throw MosaicAPIError.invalidResponse }
            guard (200..<300).contains(http.statusCode) else {
                var data = Data()
                for try await byte in bytes { data.append(byte) }
                throw decodeError(data: data, response: http)
            }
            let filename = downloadFilename(for: http)
            // An isolated directory preserves the server name without overwriting another export.
            let directory = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try manager.createDirectory(at: directory, withIntermediateDirectories: false, attributes: [.protectionKey: FileProtectionType.complete])
            do {
                let destination = directory.appendingPathComponent(filename)
                try Data().write(to: destination, options: .completeFileProtection)
                let file = try FileHandle(forWritingTo: destination)
                defer { try? file.close() }
                var chunk = Data(); chunk.reserveCapacity(65_536)
                for try await byte in bytes {
                    chunk.append(byte)
                    if chunk.count == 65_536 {
                        try Task.checkCancellation()
                        try file.write(contentsOf: chunk); chunk.removeAll(keepingCapacity: true)
                    }
                }
                try Task.checkCancellation()
                if !chunk.isEmpty { try file.write(contentsOf: chunk) }
                try file.close()
                return destination
            } catch { try? manager.removeItem(at: directory); throw error }
        } catch { throw transportError(error) }
    }
    private func downloadFilename(for response: HTTPURLResponse) -> String {
        let disposition = response.value(forHTTPHeaderField: "Content-Disposition") ?? ""
        let pattern = #"(?:^|;)\s*(filename\*?)\s*=\s*(?:"([^"]*)"|([^;]*))"#
        let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        var filename: String?
        for match in regex?.matches(in: disposition, range: NSRange(disposition.startIndex..., in: disposition)) ?? [] {
            guard let keyRange = Range(match.range(at: 1), in: disposition),
                  let valueRange = Range(match.range(at: match.range(at: 2).location == NSNotFound ? 3 : 2), in: disposition) else { continue }
            let value = String(disposition[valueRange]).trimmingCharacters(in: .whitespaces)
            if disposition[keyRange].hasSuffix("*") {
                // RFC 5987: prefer the encoded filename when both parameters are present.
                let parts = value.split(separator: "'", maxSplits: 2, omittingEmptySubsequences: false)
                if parts.count == 3, let decoded = String(parts[2]).removingPercentEncoding { filename = decoded; break }
            } else { filename = value }
        }
        let name = filename?.replacingOccurrences(of: "\\", with: "/").components(separatedBy: "/").last ?? ""
        return name.isEmpty || name == "." || name == ".." || name.contains("\0") ? "mosaic-export.zip" : name
    }
    func lines<Body: Encodable>(path: String, body: Body, token: String) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var request = try makeRequest(path: path, token: token)
                    request.httpMethod = "POST"; request.timeoutInterval = 60
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = try JSONEncoder().encode(body)
                    let (bytes, response) = try await session.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else { throw MosaicAPIError.invalidResponse }
                    guard (200..<300).contains(http.statusCode) else {
                        var data = Data()
                        for try await byte in bytes { data.append(byte) }
                        throw decodeError(data: data, response: http)
                    }
                    for try await line in bytes.lines where !line.isEmpty {
                        try Task.checkCancellation()
                        if case .terminated = continuation.yield(Data(line.utf8)) { break }
                    }
                    continuation.finish()
                } catch { continuation.finish(throwing: transportError(error)) }
            }
            continuation.onTermination = { @Sendable _ in task.cancel() }
        }
    }
    private func responseData(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw MosaicAPIError.invalidResponse }
            guard (200..<300).contains(http.statusCode) else { throw decodeError(data: data, response: http) }
            return (data, http)
        } catch { throw transportError(error) }
    }
    private func transportError(_ error: Error) -> Error {
        if error is MosaicAPIError { return error }
        if error is CancellationError || (error as? URLError)?.code == .cancelled { return CancellationError() }
        if (error as? URLError)?.code == .timedOut { return MosaicAPIError.timedOut("Mosaic took too long to respond. Please try again.") }
        return MosaicAPIError.network("Unable to connect to Mosaic. Please try again.")
    }
    private func decode<T: Decodable>(_ data: Data, as type: T.Type) throws -> T {
        do { return try JSONDecoder.mosaic.decode(type, from: data) }
        catch { throw MosaicAPIError.decoding("Mosaic returned data the app could not read.") }
    }
    private func perform<T: Decodable>(_ request: URLRequest, as type: T.Type) async throws -> T {
        let clock = ContinuousClock(); let start = clock.now
        #if DEBUG
        networkLogger.debug("Public request starting: \(request.url?.path(percentEncoded: false) ?? "unknown", privacy: .public)")
        #endif
        defer {
        #if DEBUG
            networkLogger.debug("Public catalog request completed in \(String(describing: start.duration(to: clock.now)), privacy: .public)")
        #endif
        }
        let (data, http) = try await responseData(for: request)
        #if DEBUG
        networkLogger.debug("Public response received: status \(http.statusCode, privacy: .public), \(data.count, privacy: .public) bytes")
        #endif
        return try decode(data, as: type)
    }
    private func decodeError(data: Data, response: HTTPURLResponse) -> MosaicAPIError {
        let error: MosaicAPIError
        if let envelope = try? JSONDecoder.mosaic.decode(MosaicErrorEnvelope.self, from: data) {
            error = .from(code: envelope.error.code, message: envelope.error.message, statusCode: response.statusCode)
        } else {
            struct LegacyError: Decodable { let error: String }
            let message = (try? JSONDecoder().decode(LegacyError.self, from: data))?.error ?? "Mosaic could not complete that request."
            error = .from(code: nil, message: message, statusCode: response.statusCode)
        }
        // Preserve the original rateLimited case unless the server supplies valid delay seconds.
        // HTTP-date Retry-After values are not interpreted as seconds.
        if response.statusCode == 429, let header = response.value(forHTTPHeaderField: "Retry-After"),
           let seconds = TimeInterval(header.trimmingCharacters(in: .whitespacesAndNewlines)), seconds.isFinite, seconds >= 0 {
            return .rateLimitedFor(error.errorDescription ?? "Mosaic could not complete that request.", retryAfter: seconds)
        }
        return error
    }
}
nonisolated extension JSONDecoder {
    static let mosaic: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: value) { return date }
            let standard = ISO8601DateFormatter()
            if let date = standard.date(from: value) { return date }
            throw DecodingError.dataCorruptedError(in: try decoder.singleValueContainer(), debugDescription: "Expected an ISO-8601 date.")
        }
        return decoder
    }()
}
