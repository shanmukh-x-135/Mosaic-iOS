import Foundation

struct MosaicAPIClient: Sendable {
    let baseURL: URL; private let session: URLSession
    init(baseURL: URL, session: URLSession = .shared) { self.baseURL = baseURL; self.session = session }
    func request<T: Decodable>(_ path: String, token: String, as type: T.Type = T.self) async throws -> T {
        var request = try makeRequest(path: path, token: token); request.httpMethod = "GET"
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw MosaicAPIError.invalidResponse }
            guard (200..<300).contains(http.statusCode) else { throw decodeError(data: data, statusCode: http.statusCode) }
            do { return try JSONDecoder.mosaic.decode(T.self, from: data) } catch { throw MosaicAPIError.decoding("Mosaic returned data the app could not read.") }
        } catch let error as MosaicAPIError { throw error } catch is CancellationError { throw CancellationError() } catch { throw MosaicAPIError.network("Unable to connect to Mosaic. Please try again.") }
    }
    func makeRequest(path: String, token: String) throws -> URLRequest {
        guard let url = URL(string: path, relativeTo: baseURL) else { throw MosaicAPIError.invalidResponse }
        var request = URLRequest(url: url); request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization"); request.setValue("application/json", forHTTPHeaderField: "Accept"); return request
    }
    private func decodeError(data: Data, statusCode: Int) -> MosaicAPIError {
        if let envelope = try? JSONDecoder.mosaic.decode(MosaicErrorEnvelope.self, from: data) { return .from(code: envelope.error.code, message: envelope.error.message, statusCode: statusCode) }
        return .from(code: nil, message: "Mosaic could not complete that request.", statusCode: statusCode)
    }
}
extension JSONDecoder { static let mosaic: JSONDecoder = { let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase; decoder.dateDecodingStrategy = .iso8601; return decoder }() }
