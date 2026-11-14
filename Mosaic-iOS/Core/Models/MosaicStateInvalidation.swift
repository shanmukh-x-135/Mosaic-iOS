import Foundation

nonisolated extension Notification.Name {
    /// Posted only after a successful authenticated state mutation. Root
    /// projections apply the included snapshot or refresh their bounded endpoints.
    static let mosaicStateDidChange = Notification.Name("mosaicStateDidChange")
    /// Posted after the signed-in user's profile (name, avatar, region) changes.
    static let mosaicProfileDidChange = Notification.Name("mosaicProfileDidChange")
}

nonisolated enum MosaicStateInvalidation {
    /// `mosaicStateDidChange` userInfo value: the full `MosaicStateSnapshot`
    /// returned by a successful mutation, omitted if its body could not decode.
    static let snapshotKey = "mosaicStateSnapshot"

    static func post(snapshot: MosaicStateSnapshot? = nil) {
        NotificationCenter.default.post(name: .mosaicStateDidChange, object: nil, userInfo: snapshot.map { [snapshotKey: $0] })
    }
    static func postProfileChange() { NotificationCenter.default.post(name: .mosaicProfileDidChange, object: nil) }
}

nonisolated extension Notification {
    var mosaicStateSnapshot: MosaicStateSnapshot? { userInfo?[MosaicStateInvalidation.snapshotKey] as? MosaicStateSnapshot }
}
