import SwiftUI

/// One resumable story. Copy sits inside the card's own padding; artwork is a
/// layer that can never move or widen it.
struct ContinueStoryCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let story: ContinueStory
    /// A fixed width, or nil to fill the frame the container proposes.
    let width: CGFloat?

    var body: some View {
        StoryArtwork(story: story)
            .overlay {
                LinearGradient(stops: [.init(color: .clear, location: 0.15), .init(color: MosaicColor.background.opacity(0.55), location: 0.5), .init(color: MosaicColor.background.opacity(0.96), location: 1)], startPoint: .top, endPoint: .bottom)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: MosaicSpace.xSmall) {
                    MosaicMediaLabel(mediaType: story.catalogMediaType)
                    Text(story.title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(MosaicColor.primaryText)
                        .lineLimit(2)
                    ForEach(story.progress.detailLines, id: \.self) { line in
                        Text(line).font(.footnote).foregroundStyle(MosaicColor.secondaryText).lineLimit(1)
                    }
                    if let fraction = story.progress.progressFraction {
                        MosaicProgressBar(fraction: fraction, tint: story.catalogMediaType.accent)
                    }
                    Label(story.actionTitle, systemImage: "play.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MosaicColor.primaryText)
                        .padding(.top, 2)
                }
                .padding(MosaicSpace.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: width, height: ContinueCardLayout.height(for: dynamicTypeSize))
            .frame(maxWidth: width == nil ? .infinity : nil)
            .clipShape(RoundedRectangle(cornerRadius: MosaicRadius.card, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: MosaicRadius.card, style: .continuous).strokeBorder(MosaicColor.border) }
            .contentShape(RoundedRectangle(cornerRadius: MosaicRadius.card, style: .continuous))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel([story.mediaLabel, story.title, story.progress.accessibilitySummary, story.actionTitle].filter { !$0.isEmpty }.joined(separator: ", "))
            .accessibilityHint("Opens story details")
            .accessibilityAddTraits(.isButton)
    }
}

private struct StoryArtwork: View {
    let story: ContinueStory

    var body: some View {
        if story.artworkURL != nil {
            MosaicArtwork(url: story.artworkURL, fallbackURL: story.fallbackArtworkURL, mediaType: story.catalogMediaType)
        } else if let poster = story.fallbackArtworkURL {
            // A poster-only story keeps its poster upright on a tinted field
            // instead of cropping it into a wide banner.
            LinearGradient(colors: story.catalogMediaType.fallbackGradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                .overlay(alignment: .topTrailing) {
                    MosaicArtwork(url: poster, mediaType: story.catalogMediaType)
                        .aspectRatio(MosaicArtworkRatio.poster, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: MosaicRadius.small, style: .continuous))
                        .padding(MosaicSpace.medium)
                        .frame(maxHeight: 150)
                }
        } else {
            MosaicArtworkFallback(mediaType: story.catalogMediaType)
        }
    }
}

enum ContinueCardLayout {
    static let height: CGFloat = 228
    static let widthRatio: CGFloat = 0.84
    static let minimumWidth: CGFloat = 240
    static let maximumWidth: CGFloat = 420

    static func width(for viewportWidth: CGFloat, gutter: CGFloat = MosaicLayout.pageHorizontal) -> CGFloat {
        let available = max(0, viewportWidth - (gutter * 2))
        return min(maximumWidth, max(minimumWidth, available * widthRatio))
    }

    static func height(for dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 400 : dynamicTypeSize >= .xxLarge ? 268 : height
    }
}
