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
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw MosaicAPIError.invalidResponse }
            guard (200..<300).contains(http.statusCode) else { throw decodeError(data: data, statusCode: http.statusCode) }
            do { return try JSONDecoder.mosaic.decode(T.self, from: data) } catch { throw MosaicAPIError.decoding("Mosaic returned data the app could not read.") }
        } catch let error as MosaicAPIError { throw error } catch is CancellationError { throw CancellationError() } catch { throw MosaicAPIError.network("Unable to connect to Mosaic. Please try again.") }
    }
    func publicRequest<T: Decodable>(path: String, queryItems: [URLQueryItem] = [], as type: T.Type = T.self) async throws -> T {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.path = path
        components?.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components?.url else { throw MosaicAPIError.invalidResponse }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return try await perform(request, as: type)
    }
    func makeRequest(path: String, token: String) throws -> URLRequest {
        guard let url = URL(string: path, relativeTo: baseURL) else { throw MosaicAPIError.invalidResponse }
        var request = URLRequest(url: url); request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization"); request.setValue("application/json", forHTTPHeaderField: "Accept"); return request
    }
    private func perform<T: Decodable>(_ request: URLRequest, as type: T.Type) async throws -> T {
        let clock = ContinuousClock(); let start = clock.now
        defer {
        #if DEBUG
            networkLogger.debug("Public catalog request completed in \(String(describing: start.duration(to: clock.now)), privacy: .public)")
        #endif
        }
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw MosaicAPIError.invalidResponse }
            guard (200..<300).contains(http.statusCode) else { throw decodeError(data: data, statusCode: http.statusCode) }
            do { return try JSONDecoder.mosaic.decode(T.self, from: data) } catch { throw MosaicAPIError.decoding("Mosaic returned data the app could not read.") }
        } catch let error as MosaicAPIError { throw error } catch is CancellationError { throw CancellationError() } catch { throw MosaicAPIError.network("Unable to connect to Mosaic. Please try again.") }
    }
    private func decodeError(data: Data, statusCode: Int) -> MosaicAPIError {
        if let envelope = try? JSONDecoder.mosaic.decode(MosaicErrorEnvelope.self, from: data) { return .from(code: envelope.error.code, message: envelope.error.message, statusCode: statusCode) }
        return .from(code: nil, message: "Mosaic could not complete that request.", statusCode: statusCode)
    }
}
extension JSONDecoder {
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
