import Foundation

enum MosaicAPIError: Error, Equatable, LocalizedError, Sendable {
    case unauthorized(String), forbidden(String), notFound(String), validation(String), conflict(String), rateLimited(String), providerUnavailable(String), internalError(String), network(String), decoding(String), invalidResponse
    var errorDescription: String? {
        switch self { case let .unauthorized(m), let .forbidden(m), let .notFound(m), let .validation(m), let .conflict(m), let .rateLimited(m), let .providerUnavailable(m), let .internalError(m), let .network(m), let .decoding(m): m; case .invalidResponse: "The server returned an invalid response." }
    }
    static func from(code: String?, message: String, statusCode: Int) -> MosaicAPIError {
        switch code ?? "" { case "UNAUTHORIZED": .unauthorized(message); case "FORBIDDEN": .forbidden(message); case "NOT_FOUND": .notFound(message); case "VALIDATION_ERROR": .validation(message); case "CONFLICT": .conflict(message); case "RATE_LIMITED": .rateLimited(message); case "PROVIDER_UNAVAILABLE": .providerUnavailable(message); case "INTERNAL_ERROR": .internalError(message); default:
            switch statusCode { case 401: .unauthorized(message); case 403: .forbidden(message); case 404: .notFound(message); case 409: .conflict(message); case 422: .validation(message); case 429: .rateLimited(message); case 500...599: .internalError(message); default: .invalidResponse }
        }
    }
}
struct MosaicErrorEnvelope: Decodable, Sendable { struct Payload: Decodable, Sendable { let code: String; let message: String }; let error: Payload }
