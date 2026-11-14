import SwiftUI

struct ReviewSection: View {
    static let isAvailable = true
    let media: CatalogMedia
    @Environment(PersonalStateStore.self) private var store
    @Environment(\.mosaicServices) private var services
    @State private var revealsSpoilers = false

    private var review: MosaicStateSnapshot.Review? { store.snapshot?.reviews(for: media) }

    var body: some View {
        Group {
            if let review {
                VStack(alignment: .leading, spacing: MosaicSpace.medium) {
                    MosaicSectionHeader("Your review", eyebrow: "Written by you")
                    HStack(spacing: MosaicSpace.small) {
                        if let date = Self.date(from: review.updatedAt) {
                            Text(date, formatter: Self.dateFormatter)
                                .font(MosaicType.metadata)
                                .foregroundStyle(MosaicColor.secondaryText)
                        }
                        if let rating = review.rating { MosaicUserRatingLabel(value: rating) }
                    }
                    if review.containsSpoilers && !revealsSpoilers {
                        Button("Contains spoilers — tap to reveal") { revealsSpoilers = true }
                            .buttonStyle(.bordered)
                            .frame(minHeight: MosaicLayout.minimumTouchTarget)
                            .accessibilityLabel("Reveal spoilers")
                    } else {
                        Text(review.body)
                            .font(MosaicType.body)
                            .foregroundStyle(MosaicColor.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, MosaicLayout.pageHorizontal)
            }
        }
        .onAppear { store.load(services) }
        .onChange(of: media.mediaKey) { _, _ in revealsSpoilers = false }
        .onChange(of: review?.id) { _, _ in revealsSpoilers = false }
        .onChange(of: review?.updatedAt) { _, _ in revealsSpoilers = false }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static func date(from value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}
