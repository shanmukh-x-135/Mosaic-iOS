import Foundation

struct AppConfiguration: Sendable {
    let apiBaseURL: URL; let supabaseURL: URL?; let supabasePublishableKey: String
    static let current = AppConfiguration(bundle: .main)
    init(bundle: Bundle) {
        let values: [String: Any]
        if let url = bundle.url(forResource: "MosaicConfiguration", withExtension: "plist"),
           let loaded = NSDictionary(contentsOf: url) as? [String: Any] {
            values = loaded
        } else {
            values = [:]
        }
        let apiURL = values["apiBaseURL"] as? String ?? "https://mosaic-eight-theta.vercel.app"
        apiBaseURL = URL(string: apiURL) ?? URL(string: "https://mosaic-eight-theta.vercel.app")!
        let supabaseURLString = values["supabaseURL"] as? String ?? ""
        supabaseURL = supabaseURLString.isEmpty ? nil : URL(string: supabaseURLString)
        supabasePublishableKey = values["supabasePublishableKey"] as? String ?? ""
    }
    init(apiBaseURL: URL, supabaseURL: URL?, supabasePublishableKey: String) { self.apiBaseURL = apiBaseURL; self.supabaseURL = supabaseURL; self.supabasePublishableKey = supabasePublishableKey }
    var hasSupabaseCredentials: Bool { supabaseURL != nil && !supabasePublishableKey.isEmpty }
}
