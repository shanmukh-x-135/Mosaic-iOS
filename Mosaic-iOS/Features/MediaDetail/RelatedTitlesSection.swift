import SwiftUI

struct RelatedTitlesSection: View {
    static let isAvailable = true
    let media: CatalogMedia
    @Environment(\.mosaicServices) private var services
    @State private var result: (route: MediaDetailRoute, items: [CatalogMedia], message: String)?

    var body: some View {
        Group {
            if let result, result.route == media.route {
                VStack(alignment: .leading, spacing: MosaicSpace.medium) {
                    MosaicSectionHeader(Self.heading(for: media))
                    if result.items.isEmpty {
                        Text(result.message)
                            .font(.subheadline).foregroundStyle(MosaicColor.mutedText)
                            .padding(.horizontal, MosaicLayout.pageHorizontal)
                    } else {
                        MosaicPosterShelf(items: result.items, showsMedium: true)
                    }
                }
            }
        }
        .task(id: media.route) {
            let route = media.route
            guard result?.route != route else { return }
            result = nil
            do {
                let response = try await services.related(route)
                guard !Task.isCancelled else { return }
                result = (route, Self.filteredItems(response.items, excluding: media), Self.emptyMessage(for: media, failures: response.failures))
            } catch {
                guard !Task.isCancelled else { return }
                result = (route, [], "Related stories are unavailable.")
            }
        }
    }

    static func heading(for media: CatalogMedia) -> String {
        switch media.mediaType {
        case .game: "Similar games"
        case .book: media.authors?.first.map { "More by \($0)" } ?? "Related books"
        default: "Related stories"
        }
    }

    static func emptyMessage(for media: CatalogMedia, failures: [CatalogFailure]) -> String {
        failures.first?.message ?? (media.mediaType == .book
            ? "No related books are available from this provider right now."
            : "No related titles are available from this provider right now.")
    }

    static func filteredItems(_ items: [CatalogMedia], excluding media: CatalogMedia) -> [CatalogMedia] {
        items.filter { $0.route != media.route }
    }
}
