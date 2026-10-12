import SwiftUI

/// A swipeable editorial spotlight (Home's discovery reel and Discover's
/// spotlight). It never auto-advances on iOS: paging is the user's gesture,
/// which also keeps it calm under Reduce Motion.
struct SpotlightPager: View {
    let items: [CatalogMedia]
    let eyebrow: String
    /// The honest scope of the picks, e.g. "TMDB · Trending movies".
    var source: String?
    @State private var selection = 0
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var height: CGFloat { dynamicTypeSize.isAccessibilitySize ? 600 : dynamicTypeSize >= .xLarge ? 380 : 340 }

    var body: some View {
        VStack(alignment: .leading, spacing: MosaicSpace.small) {
            TabView(selection: $selection) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, media in
                    SpotlightCard(media: media, eyebrow: eyebrow)
                        .padding(.horizontal, MosaicLayout.pageHorizontal)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: height)
            .onChange(of: items.map(\.id)) { _, _ in selection = 0 }

            HStack(spacing: MosaicSpace.small) {
                if let source { Text(source).font(.caption).foregroundStyle(MosaicColor.mutedText).lineLimit(1) }
                Spacer(minLength: 0)
                if items.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(items.indices, id: \.self) { index in
                            Capsule().fill(index == selection ? MosaicColor.primaryText : MosaicColor.highlight)
                                .frame(width: index == selection ? 18 : 6, height: 6)
                        }
                    }
                    .accessibilityElement()
                    .accessibilityLabel("Spotlight \(selection + 1) of \(items.count)")
                    .accessibilityAdjustableAction { direction in
                        switch direction {
                        case .increment: selection = min(selection + 1, items.count - 1)
                        case .decrement: selection = max(selection - 1, 0)
                        @unknown default: break
                        }
                    }
                }
            }
            .padding(.horizontal, MosaicLayout.pageHorizontal)
        }
    }
}

private struct SpotlightCard: View {
    let media: CatalogMedia
    let eyebrow: String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        MosaicArtwork(url: media.backdropURL, fallbackURL: media.posterURL, mediaType: media.mediaType, title: media.backdropURL == nil && media.posterURL == nil ? media.title : nil)
            .overlay {
                LinearGradient(stops: [.init(color: .clear, location: 0.1), .init(color: MosaicColor.background.opacity(0.7), location: 0.55), .init(color: MosaicColor.background.opacity(0.97), location: 1)], startPoint: .top, endPoint: .bottom)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: MosaicSpace.small) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: MosaicSpace.small) { MosaicEyebrow(title: eyebrow); MosaicMediaLabel(mediaType: media.mediaType) }
                        MosaicMediaLabel(mediaType: media.mediaType)
                    }
                    Text(media.title)
                        .font(MosaicType.hero)
                        .foregroundStyle(MosaicColor.primaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: MosaicSpace.small) {
                            if let metadata = metadata { Text(metadata).lineLimit(1) }
                            if let rating = media.community { MosaicCommunityRatingLabel(rating: rating) }
                        }
                        VStack(alignment: .leading, spacing: MosaicSpace.xxSmall) {
                            if let metadata = metadata { Text(metadata).lineLimit(1) }
                            if let rating = media.community { MosaicCommunityRatingLabel(rating: rating) }
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(MosaicColor.secondaryText)
                    // At accessibility sizes the synopsis yields to title and actions.
                    if !dynamicTypeSize.isAccessibilitySize, let description = media.description, !description.isEmpty {
                        Text(description).font(.subheadline).foregroundStyle(MosaicColor.secondaryText).lineLimit(2)
                    }
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: MosaicSpace.small) { detailsLink; SaveForLaterButton(media: media, style: .bordered) }
                        VStack(alignment: .leading, spacing: MosaicSpace.small) { detailsLink; SaveForLaterButton(media: media, style: .bordered) }
                    }
                }
                .padding(MosaicSpace.large)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .clipShape(RoundedRectangle(cornerRadius: MosaicRadius.card, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: MosaicRadius.card, style: .continuous).strokeBorder(MosaicColor.border) }
            .accessibilityElement(children: .contain)
    }

    private var detailsLink: some View {
        NavigationLink(value: MosaicRoute.media(media)) {
            Text("View details").font(.subheadline.weight(.semibold))
        }
        .buttonStyle(.borderedProminent)
        .tint(MosaicColor.primaryText)
        .foregroundStyle(MosaicColor.onLight)
    }

    private var metadata: String? {
        let values = [media.releaseYear.map(String.init), media.genres.first].compactMap { $0 }
        return values.isEmpty ? nil : values.joined(separator: " · ")
    }
}
