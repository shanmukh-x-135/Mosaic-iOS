import SwiftUI

struct FranchiseLink: View {
    static let isAvailable = true
    let media: CatalogMedia

    var franchise: FranchiseDefinition? { Franchises.forMedia(media) }

    var body: some View {
        if let franchise {
            NavigationLink(value: MosaicRoute.franchise(franchise.slug)) {
                Text("Part of \(franchise.title) →")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(media.mediaType.accent)
                    .padding(.horizontal, MosaicSpace.medium)
                    .frame(minHeight: MosaicLayout.minimumTouchTarget)
                    .background(MosaicColor.elevated, in: Capsule())
                    .overlay { Capsule().strokeBorder(MosaicColor.border) }
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isLink)
            .padding(.horizontal, MosaicLayout.pageHorizontal)
        }
    }
}
