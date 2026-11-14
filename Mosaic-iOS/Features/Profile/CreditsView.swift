import SwiftUI

struct CreditsView: View {
    static let isAvailable = true
    static let intro = "Mosaic combines provider metadata with the ratings, reviews, lists, and progress you create. Provider data remains attributed to its source."
    static let footer = "Provider names and marks belong to their respective owners. Their appearance identifies data sources and does not imply sponsorship or endorsement of Mosaic."

    struct Credit: Identifiable {
        let title: String
        let copy: String
        let provider: String
        let url: URL
        var id: String { title }
    }

    static let credits: [Credit] = [
        Credit(title: "Movies and series", copy: "This product uses the TMDB API but is not endorsed or certified by TMDB.", provider: "TMDB", url: URL(string: "https://www.themoviedb.org")!),
        Credit(title: "Watch availability", copy: "Movie and series availability is supplied through TMDB watch-provider data, powered by JustWatch. Availability varies by selected region.", provider: "JustWatch", url: URL(string: "https://www.justwatch.com")!),
        Credit(title: "Video games", copy: "Game metadata, platforms, covers, and artwork are provided by IGDB.com.", provider: "IGDB", url: URL(string: "https://www.igdb.com")!),
        Credit(title: "Books", copy: "Book metadata and cover images are supplied through the Google Books API Family.", provider: "Google Books", url: URL(string: "https://books.google.com")!),
    ]

    var body: some View {
        Form {
            Section {
                Text(Self.intro)
                    .foregroundStyle(MosaicColor.secondaryText)
            } header: {
                Text("The stories behind the stories.").accessibilityAddTraits(.isHeader)
            }
            .listRowBackground(MosaicColor.elevated)

            ForEach(Self.credits) { credit in
                Section {
                    Text(credit.copy).foregroundStyle(MosaicColor.secondaryText)
                    Link("Visit \(credit.provider) ↗", destination: credit.url)
                        .foregroundStyle(MosaicColor.accent)
                        .accessibilityAddTraits(.isLink)
                } header: {
                    Text(credit.title).accessibilityAddTraits(.isHeader)
                }
                .listRowBackground(MosaicColor.elevated)
            }

            Section {
                Text(Self.footer).foregroundStyle(MosaicColor.secondaryText)
            } footer: {
                Text(versionText)
            }
            .listRowBackground(MosaicColor.elevated)
        }
        .scrollContentBackground(.hidden)
        .background(MosaicColor.background)
        .navigationTitle("About & credits")
        .toolbar(.hidden, for: .tabBar)
    }

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "Mosaic \(version) (\(build))"
    }
}
