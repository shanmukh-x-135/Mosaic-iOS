import SwiftUI
import UIKit

// Tokens mirror the web app's `globals.css` (Tracking App `bc49972`) so both
// clients share one palette. Values are semantic: views never use literals.

private extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, opacity: opacity)
    }
}

enum MosaicColor {
    static let background = Color(hex: 0x07090C)
    static let elevated = Color(hex: 0x0C1016)
    static let surface = Color(hex: 0x11161D)
    static let surfaceHover = Color(hex: 0x171E27)
    static let primaryText = Color(hex: 0xF5F7FA)
    static let secondaryText = Color(hex: 0xB8C0CC)
    static let mutedText = Color(hex: 0x8A93A0)
    static let accent = Color(hex: 0x78AEFC)
    static let rating = Color(hex: 0xF7C653)
    static let success = Color(hex: 0x67D6A2)
    static let warning = Color(hex: 0xF2A65A)
    static let danger = Color(hex: 0xEF6B73)
    static let border = Color.white.opacity(0.075)
    static let highlight = Color.white.opacity(0.11)
    /// Text drawn on top of `primaryText` fills (selected chips, primary pills).
    static let onLight = background
}

extension CatalogMediaType {
    /// Medium accents shared with the web (movies blue, series violet, games green, books orange).
    var accent: Color {
        switch self {
        case .movie: MosaicColor.accent
        case .tv: Color(hex: 0xA38CFF)
        case .game: MosaicColor.success
        case .book: MosaicColor.warning
        }
    }

    /// The web's per-medium dark fallback gradient for titles without artwork.
    var fallbackGradient: [Color] {
        switch self {
        case .movie: [Color(hex: 0x1D2B44), Color(hex: 0x0A0F18)]
        case .tv: [Color(hex: 0x3B2D5C), Color(hex: 0x110D1D)]
        case .game: [Color(hex: 0x24473A), Color(hex: 0x0A1712)]
        case .book: [Color(hex: 0x5C3B24), Color(hex: 0x1B1009)]
        }
    }
}

enum MosaicSpace {
    static let xxSmall: CGFloat = 4
    static let xSmall: CGFloat = 6
    static let small: CGFloat = 10
    static let medium: CGFloat = 16
    static let large: CGFloat = 20
    static let xLarge: CGFloat = 32
}

enum MosaicRadius {
    static let small: CGFloat = 8
    static let control: CGFloat = 12
    static let media: CGFloat = 14
    static let card: CGFloat = 18
}

enum MosaicLayout {
    static let pageHorizontal: CGFloat = 16
    static let screenMargin = pageHorizontal
    static let sectionSpacing: CGFloat = 28
    static let posterWidth: CGFloat = 116
    static let posterHeight: CGFloat = posterWidth / MosaicArtworkRatio.poster
    static let backdropHeight: CGFloat = 300
    /// The smallest comfortable touch target (Human Interface Guidelines).
    static let minimumTouchTarget: CGFloat = 44
}

enum MosaicArtworkRatio {
    static let poster: CGFloat = 2 / 3
    static let backdrop: CGFloat = 16 / 9
    static let still: CGFloat = 16 / 9
}

/// Typography uses SF Pro text styles so every size follows Dynamic Type. The
/// web uses one sans family (Inter); iOS matches that with the system face.
enum MosaicType {
    static let display = Font.largeTitle.weight(.bold)
    static let hero = Font.title.weight(.bold)
    static let title = Font.title2.weight(.bold)
    static let section = Font.title3.weight(.bold)
    static let cardTitle = Font.headline
    static let body = Font.body
    static let metadata = Font.footnote
    static let caption = Font.caption
    static let eyebrow = Font.caption2.weight(.heavy)
}

enum MosaicMotion {
    static let standard = Animation.smooth(duration: 0.22)
    static func standard(reduceMotion: Bool) -> Animation? { reduceMotion ? nil : standard }
}

// MARK: - Layout primitives

struct MosaicScreen<Content: View>: View {
    @ViewBuilder var content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: MosaicLayout.sectionSpacing) { content }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, MosaicSpace.small)
                .padding(.bottom, MosaicSpace.xLarge)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(MosaicColor.background)
    }
}

struct MosaicEyebrow: View {
    let title: String
    var color: Color = MosaicColor.accent
    var body: some View {
        Text(title.uppercased())
            .font(MosaicType.eyebrow)
            .tracking(1.4)
            .foregroundStyle(color)
            .accessibilityAddTraits(.isHeader)
    }
}

struct MosaicPageHeader: View {
    let eyebrow: String?
    let title: String
    let subtitle: String?
    init(_ title: String, eyebrow: String? = nil, subtitle: String? = nil) { self.title = title; self.eyebrow = eyebrow; self.subtitle = subtitle }
    var body: some View {
        VStack(alignment: .leading, spacing: MosaicSpace.xxSmall) {
            if let eyebrow { MosaicEyebrow(title: eyebrow) }
            Text(title).font(MosaicType.display).foregroundStyle(MosaicColor.primaryText).accessibilityAddTraits(.isHeader)
            if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(MosaicColor.secondaryText).fixedSize(horizontal: false, vertical: true) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, MosaicLayout.pageHorizontal)
    }
}

struct MosaicSectionHeader<Trailing: View>: View {
    let eyebrow: String?
    let title: String
    let trailing: Trailing
    init(_ title: String, eyebrow: String? = nil, @ViewBuilder trailing: () -> Trailing) { self.title = title; self.eyebrow = eyebrow; self.trailing = trailing() }
    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: MosaicSpace.medium) {
            VStack(alignment: .leading, spacing: MosaicSpace.xxSmall) {
                if let eyebrow { MosaicEyebrow(title: eyebrow) }
                Text(title).font(MosaicType.section).foregroundStyle(MosaicColor.primaryText).accessibilityAddTraits(.isHeader)
            }
            Spacer(minLength: MosaicSpace.small)
            trailing.font(.subheadline.weight(.semibold)).foregroundStyle(MosaicColor.accent)
        }
        .padding(.horizontal, MosaicLayout.pageHorizontal)
    }
}

extension MosaicSectionHeader where Trailing == EmptyView {
    init(_ title: String, eyebrow: String? = nil) { self.init(title, eyebrow: eyebrow) { EmptyView() } }
}

/// A horizontally scrolling rail whose content starts at the page margin and
/// never makes the page itself scroll sideways.
struct MosaicRail<Content: View>: View {
    var spacing: CGFloat = MosaicSpace.small + 2
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: spacing) { content }
                .scrollTargetLayout()
        }
        .contentMargins(.horizontal, MosaicLayout.pageHorizontal, for: .scrollContent)
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
    }
}

// MARK: - Controls

struct MosaicFilterChip: View {
    let title: String
    let selected: Bool
    var count: Int?
    var tint: Color?
    var body: some View {
        HStack(spacing: MosaicSpace.xSmall) {
            if let tint, !selected { Circle().fill(tint).frame(width: 7, height: 7) }
            Text(title)
            if let count { Text(count.formatted()).foregroundStyle(selected ? MosaicColor.onLight.opacity(0.65) : MosaicColor.mutedText).monospacedDigit() }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(selected ? MosaicColor.onLight : MosaicColor.primaryText)
        .padding(.horizontal, 14)
        .frame(minHeight: 36)
        .background(selected ? MosaicColor.primaryText : MosaicColor.surface, in: Capsule())
        .overlay { if !selected { Capsule().strokeBorder(MosaicColor.border) } }
        .contentShape(Capsule())
    }
}

/// A chip row for one exclusive choice; selection is exposed to VoiceOver.
struct MosaicChipRow<Item: Hashable>: View {
    let items: [Item]
    @Binding var selection: Item
    let title: (Item) -> String
    var count: ((Item) -> Int?)?
    var tint: ((Item) -> Color?)?
    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: MosaicSpace.small - 2) {
                ForEach(items, id: \.self) { item in
                    Button { selection = item } label: {
                        MosaicFilterChip(title: title(item), selected: selection == item, count: count?(item), tint: tint?(item))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selection == item ? .isSelected : [])
                }
            }
        }
        .contentMargins(.horizontal, MosaicLayout.pageHorizontal, for: .scrollContent)
        .scrollIndicators(.hidden)
    }
}

/// The medium a title belongs to, coloured with its accent.
struct MosaicMediaLabel: View {
    let mediaType: CatalogMediaType
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(mediaType.accent).frame(width: 6, height: 6)
            Text(mediaType.displayName)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(MosaicColor.secondaryText)
        .accessibilityElement(children: .combine)
    }
}

/// A provider rating on Mosaic's /10 display scale, always naming its source.
struct MosaicCommunityRatingLabel: View {
    let rating: CommunityRating
    var showsSource = true
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill").foregroundStyle(MosaicColor.rating).imageScale(.small)
            Text(rating.formattedValue).foregroundStyle(MosaicColor.primaryText).monospacedDigit()
            if showsSource { Text(rating.source.shortLabel).foregroundStyle(MosaicColor.mutedText) }
        }
        .fixedSize()
        .font(.footnote.weight(.semibold))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rating.accessibilityDescription)
    }
}

/// The user's own Mosaic rating (0.5–5 stars), visually distinct from community ratings.
struct MosaicUserRatingLabel: View {
    let value: Double
    var body: some View {
        Label(UserRating.format(value), systemImage: "star.circle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(MosaicColor.rating)
            .accessibilityLabel("Your rating \(UserRating.format(value)) out of 5")
    }
}

struct MosaicProgressBar: View {
    let fraction: Double
    var tint: Color = MosaicColor.accent
    var body: some View {
        Capsule().fill(Color.white.opacity(0.12))
            .overlay(alignment: .leading) {
                GeometryReader { proxy in Capsule().fill(tint).frame(width: proxy.size.width * min(max(fraction, 0), 1)) }
            }
            .frame(height: 4)
            .accessibilityElement()
            .accessibilityLabel("Progress")
            .accessibilityValue("\(Int((fraction * 100).rounded())) percent")
    }
}

/// Loading, empty and error presentation used by every network screen.
struct MosaicStateMessage: View {
    let title: String
    let message: String
    var systemImage = "sparkles"
    var actionTitle: String?
    var action: (() -> Void)?
    var body: some View {
        // The action lives in the view's own actions slot so it stays with the
        // message instead of drifting to the bottom of a tall container.
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action).buttonStyle(.borderedProminent).tint(MosaicColor.accent).foregroundStyle(MosaicColor.onLight)
            }
        }
        .foregroundStyle(MosaicColor.secondaryText)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, MosaicLayout.pageHorizontal)
    }
}

/// A compact inline notice (partial failures, save results).
struct MosaicNotice: View {
    let text: String
    var tone: Tone = .info
    enum Tone { case info, success, failure }
    var body: some View {
        Label(text, systemImage: tone == .failure ? "exclamationmark.triangle.fill" : tone == .success ? "checkmark.circle.fill" : "info.circle")
            .font(.footnote)
            .foregroundStyle(tone == .failure ? MosaicColor.danger : tone == .success ? MosaicColor.success : MosaicColor.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct MosaicSkeleton: View {
    var aspectRatio: CGFloat = 16 / 9
    var body: some View {
        RoundedRectangle(cornerRadius: MosaicRadius.media, style: .continuous)
            .fill(MosaicColor.surface)
            .aspectRatio(aspectRatio, contentMode: .fit)
            .accessibilityHidden(true)
    }
}

// MARK: - Artwork

/// Remote artwork that fills whatever frame it is given. The image is drawn as
/// an overlay of a flexible clear base, so a wide or tall source image can
/// never widen its container (the cause of the Home hero overflow).
struct MosaicArtwork: View {
    let url: URL?
    let fallbackURL: URL?
    let mediaType: CatalogMediaType
    var title: String?
    @State private var image: UIImage?
    @State private var finished = false

    init(url: URL?, fallbackURL: URL? = nil, mediaType: CatalogMediaType, title: String? = nil) {
        self.url = url
        self.fallbackURL = fallbackURL
        self.mediaType = mediaType
        self.title = title
    }

    var body: some View {
        Color.clear
            .overlay {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    MosaicArtworkFallback(mediaType: mediaType, title: finished || url == nil ? title : nil)
                }
            }
            .clipped()
            .accessibilityHidden(true)
            .task(id: ArtworkRequestKey(primary: url, fallback: fallbackURL)) {
                image = await MosaicArtworkLoader.shared.image(primary: url, fallback: fallbackURL)
                finished = true
            }
    }
}

/// The web's typographic missing-art treatment: a medium-tinted gradient with
/// the title, so a missing poster still reads as that story.
struct MosaicArtworkFallback: View {
    let mediaType: CatalogMediaType
    var title: String?
    var body: some View {
        LinearGradient(colors: mediaType.fallbackGradient, startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay(alignment: .bottomLeading) {
                if let title {
                    Text(title)
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(MosaicColor.primaryText.opacity(0.9))
                        .lineLimit(4)
                        .minimumScaleFactor(0.8)
                        .padding(MosaicSpace.small)
                }
            }
            .overlay(alignment: .topLeading) {
                Image(systemName: mediaType.symbolName)
                    .font(.footnote)
                    .foregroundStyle(mediaType.accent.opacity(0.85))
                    .padding(MosaicSpace.small)
            }
    }
}

private struct ArtworkRequestKey: Hashable {
    let primary: URL?
    let fallback: URL?
}

actor MosaicArtworkLoader {
    static let shared = MosaicArtworkLoader()
    private let cache = NSCache<NSURL, UIImage>()

    func image(primary: URL?, fallback: URL?) async -> UIImage? {
        if let primary, let image = await image(for: primary) { return image }
        guard let fallback, fallback != primary else { return nil }
        return await image(for: fallback)
    }

    private func image(for url: URL) async -> UIImage? {
        if let cached = cache.object(forKey: url as NSURL) { return cached }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            guard (200..<300).contains(status), let image = UIImage(data: data) else { return nil }
            let prepared = await image.byPreparingForDisplay() ?? image
            cache.setObject(prepared, forKey: url as NSURL)
            return prepared
        } catch {
            return nil
        }
    }
}
