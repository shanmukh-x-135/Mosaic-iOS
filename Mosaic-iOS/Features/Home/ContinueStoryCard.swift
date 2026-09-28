import SwiftUI

struct ContinueStoryCard: View {
    let story: ContinueStory

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
        .frame(width: 310, height: 390)
        .clipShape(RoundedRectangle(cornerRadius: MosaicRadius.card, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(story.mediaLabel), \(story.title), \(story.progress.accessibilitySummary), \(story.actionTitle)")
        .accessibilityHint("Opens story details")
    }
}

private struct StoryArtwork: View {
    let story: ContinueStory

    var body: some View {
        Group {
            if let url = story.artworkURL ?? story.fallbackArtworkURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image): image.resizable().scaledToFill()
                    case .empty: ArtworkPlaceholder(symbol: storySymbol)
                    case .failure: ArtworkPlaceholder(symbol: storySymbol)
                    @unknown default: ArtworkPlaceholder(symbol: storySymbol)
                    }
                }
            } else {
                ArtworkPlaceholder(symbol: storySymbol)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .accessibilityHidden(true)
    }

    private var storySymbol: String {
        switch story.mediaType { case .series: "tv"; case .book: "book.closed"; case .game: "gamecontroller" }
    }
}

private struct ArtworkPlaceholder: View {
    let symbol: String
    var body: some View {
        LinearGradient(colors: [MosaicColor.surface, MosaicColor.background], startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay(Image(systemName: symbol).font(.system(size: 44, weight: .light)).foregroundStyle(MosaicColor.secondaryText))
    }
}
