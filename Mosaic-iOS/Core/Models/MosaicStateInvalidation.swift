import Foundation

nonisolated extension Notification.Name {
    /// Posted only after a successful authenticated state mutation. Root
    /// projections subscribe once and refresh their own bounded endpoints.
    static let mosaicStateDidChange = Notification.Name("mosaicStateDidChange")
    /// Posted after the signed-in user's profile (name, avatar, region) changes.
    static let mosaicProfileDidChange = Notification.Name("mosaicProfileDidChange")
}

nonisolated enum MosaicStateInvalidation {
    static func post() { NotificationCenter.default.post(name: .mosaicStateDidChange, object: nil) }
    static func postProfileChange() { NotificationCenter.default.post(name: .mosaicProfileDidChange, object: nil) }
}
