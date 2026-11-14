import SwiftUI

struct ReviewsListView: View {
    static let isAvailable = true
    @Environment(PersonalStateStore.self) private var personal
    @Environment(\.mosaicServices) private var services

    var body: some View {
        MosaicScreen {
            ProfileReviewsContent(state: personal.state)
        }
        .navigationTitle("Reviews")
        .task { personal.load(services) }
        .refreshable { personal.refresh(services) }
        .onReceive(NotificationCenter.default.publisher(for: .mosaicStateDidChange)) { notification in
            personal.handleStateChange(notification, services: services)
        }
    }
}

/// Shared presentation keeps spoiler handling identical in both entry points.
struct ProfileReviewsContent: View {
    let state: Loadable<MosaicStateSnapshot>
    @Environment(PersonalStateStore.self) private var personal
    @Environment(\.mosaicServices) private var services

    var body: some View {
        switch state {
        case .idle, .loading:
            ProgressView("Loading your reviews")
        case let .failed(error):
            MosaicStateMessage(title: MosaicErrorCopy.title(for: error, subject: "your reviews"), message: MosaicErrorCopy.message(for: error), systemImage: "exclamationmark.triangle", actionTitle: "Try again") { personal.refresh(services) }
        case let .loaded(snapshot) where snapshot.reviews.isEmpty:
            MosaicStateMessage(title: "No reviews yet", message: "Write a review from any story detail page and it will appear here.", systemImage: "text.bubble")
        case let .loaded(snapshot):
            LazyVStack(spacing: MosaicSpace.medium) {
                ForEach(ProfileSections.sortedReviews(snapshot.reviews)) { review in
                    NavigationLink(value: MosaicRoute.media(review.media)) { ProfileReviewRow(review: review) }.buttonStyle(.plain)
                }
            }.padding(.horizontal, MosaicLayout.pageHorizontal)
        }
    }
}

struct ProfileReviewRow: View {
    let review: MosaicStateSnapshot.Review

    var body: some View {
        HStack(alignment: .top, spacing: MosaicSpace.medium) {
            MosaicArtwork(url: review.media.posterURL, fallbackURL: review.media.backdropURL, mediaType: review.media.mediaType, title: review.media.title)
                .frame(width: 44, height: 66)
                .clipShape(RoundedRectangle(cornerRadius: MosaicRadius.small))
            VStack(alignment: .leading, spacing: MosaicSpace.xxSmall) {
                Text(review.media.mediaType.displayName + (review.containsSpoilers ? " · Spoilers" : ""))
                    .font(.caption).foregroundStyle(MosaicColor.secondaryText)
                Text(review.media.title).font(MosaicType.cardTitle).foregroundStyle(MosaicColor.primaryText)
                if let rating = review.rating {
                    Label("\(UserRating.format(rating))", systemImage: "star.fill")
                        .font(.caption).foregroundStyle(MosaicColor.secondaryText)
                        .accessibilityLabel("\(UserRating.format(rating)) stars")
                }
                Text(ProfileSections.reviewExcerpt(review)).font(.subheadline).foregroundStyle(MosaicColor.secondaryText)
                if let date = ProfileSections.date(review.updatedAt) {
                    Text(date.formatted(date: .abbreviated, time: .omitted)).font(.caption2).foregroundStyle(MosaicColor.mutedText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens details")
    }
}
