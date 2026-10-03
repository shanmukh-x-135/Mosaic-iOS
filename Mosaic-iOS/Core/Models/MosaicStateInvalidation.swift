import Foundation

extension Notification.Name {
    /// Posted only after a successful authenticated state mutation. Root
    /// projections subscribe once and refresh their own bounded endpoints.
    static let mosaicStateDidChange = Notification.Name("mosaicStateDidChange")
}

enum MosaicStateInvalidation {
    static func post() { NotificationCenter.default.post(name: .mosaicStateDidChange, object: nil) }
}
