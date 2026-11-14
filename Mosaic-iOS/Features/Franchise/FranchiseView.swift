import SwiftUI

struct FranchiseView: View {
    static let isAvailable = true
    let slug: String
    @Environment(\.mosaicServices) private var services
    @State private var groups: [MediaGroup] = []
    @State private var isLoading = true

    struct MediaGroup: Identifiable {
        let type: CatalogMediaType
        let items: [CatalogMedia]
        var id: CatalogMediaType { type }
        var title: String { type == .tv ? "Series" : "\(type.displayName)s" }
    }

    /// Input follows curated identity order, regardless of request completion order.
    static func groupedItems(_ results: [(identity: ProviderIdentity, media: CatalogMedia?)]) -> [MediaGroup] {
        let types: [CatalogMediaType] = [.movie, .tv, .game, .book]
        return types.compactMap { type in
            let items = results.compactMap { result in
                result.identity.mediaType == type ? result.media : nil
            }
            return items.isEmpty ? nil : MediaGroup(type: type, items: items)
        }
    }

    private var franchise: FranchiseDefinition? { Franchises.bySlug(slug) }

    var body: some View {
        Group {
            if let franchise {
                MosaicScreen {
                    VStack(alignment: .leading, spacing: MosaicSpace.small) {
                        MosaicEyebrow(title: "Cross-media universe")
                        Text(franchise.title)
                            .font(MosaicType.hero)
                            .foregroundStyle(MosaicColor.primaryText)
                            .accessibilityAddTraits(.isHeader)
                        Text(franchise.overview)
                            .font(MosaicType.body)
                            .foregroundStyle(MosaicColor.secondaryText)
                    }
                    .padding(.horizontal, MosaicLayout.pageHorizontal)

                    if isLoading {
                        ProgressView("Loading universe…")
                            .frame(maxWidth: .infinity)
                    } else if groups.isEmpty {
                        MosaicStateMessage(
                            title: "This universe is temporarily unavailable",
                            message: "The mapped provider titles could not be loaded right now.",
                            systemImage: "square.stack"
                        )
                    } else {
                        ForEach(groups) { group in
                            VStack(alignment: .leading, spacing: MosaicSpace.small) {
                                MosaicSectionHeader(group.title)
                                MosaicPosterShelf(items: group.items, showsMedium: true)
                            }
                        }
                    }
                }
            } else {
                MosaicStateMessage(title: "Franchise not found", message: "This cross-media universe could not be found.", systemImage: "square.stack")
            }
        }
        .background(MosaicColor.background)
        .navigationTitle(franchise?.title ?? "Franchise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task(id: slug) { await load() }
    }

    private func load() async {
        groups = []
        isLoading = true
        guard let franchise else { isLoading = false; return }
        let detail = services.detail
        let items = await withTaskGroup(of: (Int, CatalogMedia?).self) { tasks in
            for (index, identity) in franchise.items.enumerated() {
                tasks.addTask { (index, try? await detail(identity.route)) }
            }
            var ordered = [CatalogMedia?](repeating: nil, count: franchise.items.count)
            for await (index, item) in tasks { ordered[index] = item }
            return ordered
        }
        guard !Task.isCancelled else { return }
        groups = Self.groupedItems(Array(zip(franchise.items, items)))
        isLoading = false
    }
}
