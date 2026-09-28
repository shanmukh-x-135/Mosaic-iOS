import SwiftUI

/// The reusable entry point for catalog detail. Catalog response shapes are not
/// yet documented, so this first foundation intentionally renders only the
/// real Continue projection supplied by Home and never guesses a detail DTO.
struct MediaDetailContainer: View {
    let route: MediaDetailRoute
    let preview: MediaDetailPreview

    var body: some View {
        Group {
            switch route.mediaType {
            case .movie: MovieDetailView(preview: preview)
            case .series: SeriesDetailView(preview: preview)
            case .game: GameDetailView(preview: preview)
            case .book: BookDetailView(preview: preview)
            }
        }
        .navigationTitle(preview.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct MediaDetailPreview: Equatable, Sendable {
    let title: String
    let artworkURL: URL?
    let fallbackArtworkURL: URL?
    let statusText: String?
    let progressLines: [String]
    let mediaType: CatalogMediaType

    init(story: ContinueStory) {
        title = story.title
        artworkURL = story.artworkURL
        fallbackArtworkURL = story.fallbackArtworkURL
        statusText = story.status.rawValue.capitalized
        progressLines = story.progress.detailLines
        mediaType = story.detailRoute.mediaType
    }
}

private struct MovieDetailView: View { let preview: MediaDetailPreview; var body: some View { MediaDetailPreviewView(preview: preview) } }
private struct SeriesDetailView: View { let preview: MediaDetailPreview; var body: some View { MediaDetailPreviewView(preview: preview) } }
private struct GameDetailView: View { let preview: MediaDetailPreview; var body: some View { MediaDetailPreviewView(preview: preview) } }
private struct BookDetailView: View { let preview: MediaDetailPreview; var body: some View { MediaDetailPreviewView(preview: preview) } }

private struct MediaDetailPreviewView: View {
    let preview: MediaDetailPreview

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MosaicSpace.large) {
                detailArtwork
                    .frame(height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: MosaicRadius.card, style: .continuous))

                VStack(alignment: .leading, spacing: MosaicSpace.small) {
                    Label(preview.mediaType.displayName, systemImage: preview.mediaType.symbolName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MosaicColor.secondaryText)
                    Text(preview.title)
                        .font(.system(.largeTitle, design: .serif, weight: .semibold))
                        .foregroundStyle(MosaicColor.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    if let statusText = preview.statusText {
                        Text(statusText)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(MosaicColor.accent)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(preview.mediaType.displayName), \(preview.title)\(preview.statusText.map { ", \($0)" } ?? "")")

                if !preview.progressLines.isEmpty {
                    VStack(alignment: .leading, spacing: MosaicSpace.small) {
                        Text("Your progress").font(MosaicType.title).foregroundStyle(MosaicColor.primaryText)
                        ForEach(preview.progressLines, id: \.self) { line in
                            Text(line).foregroundStyle(MosaicColor.secondaryText)
                        }
                    }
                }
            }
            .padding(MosaicSpace.large)
        }
        .background(MosaicColor.background)
    }

    @ViewBuilder private var detailArtwork: some View {
        if let url = preview.artworkURL ?? preview.fallbackArtworkURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case let .success(image): image.resizable().scaledToFill()
                case .empty, .failure: detailArtworkFallback
                @unknown default: detailArtworkFallback
                }
            }
        } else {
            detailArtworkFallback
        }
    }

    private var detailArtworkFallback: some View {
        LinearGradient(colors: [MosaicColor.surface, MosaicColor.background], startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay(Image(systemName: preview.mediaType.symbolName).font(.system(size: 50, weight: .light)).foregroundStyle(MosaicColor.secondaryText))
            .accessibilityHidden(true)
    }
}
