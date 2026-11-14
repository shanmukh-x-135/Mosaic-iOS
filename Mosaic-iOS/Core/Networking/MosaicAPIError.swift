import Foundation

nonisolated enum MosaicAPIError: Error, Equatable, LocalizedError, Sendable {
    case unauthorized(String), forbidden(String), notFound(String), validation(String), conflict(String), rateLimited(String), rateLimitedFor(String, retryAfter: TimeInterval), providerUnavailable(String), assistantUnavailable(String), internalError(String), network(String), timedOut(String), decoding(String), invalidResponse
    var errorDescription: String? {
        switch self { case let .unauthorized(m), let .forbidden(m), let .notFound(m), let .validation(m), let .conflict(m), let .rateLimited(m), let .rateLimitedFor(m, _), let .providerUnavailable(m), let .assistantUnavailable(m), let .internalError(m), let .network(m), let .timedOut(m), let .decoding(m): m; case .invalidResponse: "The server returned an invalid response." }
    }
    static func from(code: String?, message: String, statusCode: Int) -> MosaicAPIError {
        switch code ?? "" { case "UNAUTHORIZED": .unauthorized(message); case "FORBIDDEN": .forbidden(message); case "NOT_FOUND": .notFound(message); case "VALIDATION_ERROR": .validation(message); case "CONFLICT": .conflict(message); case "RATE_LIMITED": .rateLimited(message); case "PROVIDER_UNAVAILABLE": .providerUnavailable(message); case "ASSISTANT_UNAVAILABLE": .assistantUnavailable(message); case "INTERNAL_ERROR": .internalError(message); default:
            // Legacy string errors use HTTP status: 400/413/415/422 are validation; 409 is conflict.
            switch statusCode { case 401: .unauthorized(message); case 403: .forbidden(message); case 404: .notFound(message); case 409: .conflict(message); case 400, 413, 415, 422: .validation(message); case 429: .rateLimited(message); case 500...599: .internalError(message); default: .invalidResponse }
        }
    }
}
nonisolated struct MosaicErrorEnvelope: Decodable, Sendable { struct Payload: Decodable, Sendable { let code: String; let message: String }; let error: Payload }
