import SwiftUI

struct ContinueStoryCard: View {
    let story: ContinueStory
    let width: CGFloat

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            StoryArtwork(story: story)
            LinearGradient(colors: [.clear, MosaicColor.background.opacity(0.42), MosaicColor.background.opacity(0.98)], startPoint: .top, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 7) {
                Text(story.mediaLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(MosaicColor.secondaryText)
                Text(story.title)
                    .font(.system(.title3, design: .serif, weight: .semibold))
                    .lineLimit(2)
                    .foregroundStyle(MosaicColor.primaryText)
                ForEach(story.progress.detailLines, id: \.self) { line in
                    Text(line).font(.footnote).foregroundStyle(MosaicColor.secondaryText).lineLimit(1)
                }
                if let fraction = story.progress.progressFraction {
                    ProgressView(value: fraction)
                        .tint(MosaicColor.accent)
                        .accessibilityLabel("Progress")
                        .accessibilityValue("\(Int(fraction * 100)) percent")
                }
                Text(story.actionTitle)
                    .font(.subheadline.weight(.semibold))
                    .padding(.top, 3)
            }
            .padding(MosaicSpace.medium)
        }
        .frame(width: width, height: ContinueCardLayout.height)
        .clipShape(RoundedRectangle(cornerRadius: MosaicRadius.card, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(story.mediaLabel), \(story.title), \(story.progress.accessibilitySummary), \(story.actionTitle)")
        .accessibilityHint("Opens story details")
    }
}

private struct StoryArtwork: View {
    let story: ContinueStory

    var body: some View {
        if let backdrop = story.artworkURL {
            MosaicArtwork(url: backdrop, fallbackURL: story.fallbackArtworkURL, symbol: storySymbol)
        } else if let poster = story.fallbackArtworkURL {
            ZStack {
                LinearGradient(colors: [MosaicColor.surface, MosaicColor.elevated], startPoint: .topLeading, endPoint: .bottomTrailing)
                MosaicArtwork(url: poster, symbol: storySymbol)
                    .frame(width: 104)
                    .clipShape(RoundedRectangle(cornerRadius: MosaicRadius.control, style: .continuous))
                    .padding(.vertical, MosaicSpace.medium)
            }
        } else {
            MosaicArtwork(url: nil, symbol: storySymbol)
        }
    }

    private var storySymbol: String {
        switch story.mediaType { case .series: "tv"; case .book: "book.closed"; case .game: "gamecontroller" }
    }

}

enum ContinueCardLayout {
    static let height: CGFloat = 228
    static let widthRatio: CGFloat = 0.84
    static let minimumWidth: CGFloat = 240

    static func width(for viewportWidth: CGFloat, gutter: CGFloat = MosaicLayout.pageHorizontal) -> CGFloat {
        let available = max(0, viewportWidth - (gutter * 2))
        return max(minimumWidth, available * widthRatio)
    }
}
