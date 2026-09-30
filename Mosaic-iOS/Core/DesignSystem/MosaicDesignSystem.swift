import SwiftUI
import UIKit

enum MosaicColor {
    static let background = Color(red: 0.027, green: 0.035, blue: 0.047)
    static let elevated = Color(red: 0.055, green: 0.067, blue: 0.09)
    static let surface = Color(red: 0.09, green: 0.105, blue: 0.135)
    static let primaryText = Color(red: 0.96, green: 0.97, blue: 0.99)
    static let secondaryText = Color(red: 0.67, green: 0.70, blue: 0.77)
    static let mutedText = Color(red: 0.45, green: 0.48, blue: 0.55)
    static let accent = Color(red: 0.47, green: 0.67, blue: 0.98)
    static let rating = Color(red: 0.98, green: 0.75, blue: 0.32)
    static let border = Color.white.opacity(0.10)
}

enum MosaicSpace { static let xSmall: CGFloat = 6; static let small: CGFloat = 10; static let medium: CGFloat = 16; static let large: CGFloat = 20; static let xLarge: CGFloat = 32 }
enum MosaicRadius { static let media: CGFloat = 16; static let card: CGFloat = 20; static let control: CGFloat = 14 }
enum MosaicLayout {
    static let screenMargin = MosaicSpace.large
    static let bottomClearance = MosaicSpace.large
    static let posterWidth: CGFloat = 128
    static let posterHeight: CGFloat = 188
    static let backdropHeight: CGFloat = 300
}
enum MosaicType {
    static let wordmark = Font.system(size: 25, weight: .bold, design: .rounded)
    static let display = Font.system(size: 30, weight: .bold, design: .rounded)
    static let hero = Font.system(size: 30, weight: .bold, design: .rounded)
    static let title = Font.system(.title2, design: .rounded, weight: .semibold)
    static let section = Font.system(.title3, design: .rounded, weight: .bold)
    static let body = Font.body
    static let metadata = Font.footnote
}

struct MosaicScreen<Content: View>: View {
    @ViewBuilder var content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MosaicSpace.xLarge) { content }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, MosaicSpace.large)
                .safeAreaPadding(.bottom, MosaicLayout.bottomClearance)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(MosaicColor.background)
    }
}

struct MosaicEyebrow: View {
    let title: String
    var body: some View { Text(title.uppercased()).font(.caption2.weight(.bold)).tracking(1.2).foregroundStyle(MosaicColor.accent) }
}

struct MosaicSectionHeader: View {
    let eyebrow: String?
    let title: String
    let action: String?
    let actionHandler: (() -> Void)?
    init(_ title: String, eyebrow: String? = nil, action: String? = nil, actionHandler: (() -> Void)? = nil) { self.title = title; self.eyebrow = eyebrow; self.action = action; self.actionHandler = actionHandler }
    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: MosaicSpace.medium) {
            VStack(alignment: .leading, spacing: 4) { if let eyebrow { MosaicEyebrow(title: eyebrow) }; Text(title).font(MosaicType.section).foregroundStyle(MosaicColor.primaryText) }
            Spacer(minLength: 8)
            if let action, let actionHandler { Button(action, action: actionHandler).font(.footnote.weight(.semibold)).foregroundStyle(MosaicColor.accent) }
        }.padding(.horizontal, MosaicSpace.large)
    }
}

struct MosaicFilterChip: View {
    let title: String
    let selected: Bool
    var body: some View { Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(selected ? MosaicColor.background : MosaicColor.primaryText).padding(.horizontal, 14).padding(.vertical, 8).background(selected ? MosaicColor.primaryText : MosaicColor.surface, in: Capsule()) }
}

struct MosaicRating: View {
    let value: Double
    var body: some View { Label(value.formatted(.number.precision(.fractionLength(1))), systemImage: "star.fill").font(.footnote.weight(.semibold)).foregroundStyle(MosaicColor.rating) }
}

struct MosaicGlassControl<Content: View>: View {
    @ViewBuilder var content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View { content.padding(.horizontal, 12).padding(.vertical, 9).glassEffect(.regular, in: RoundedRectangle(cornerRadius: MosaicRadius.control, style: .continuous)) }
}

struct MosaicSkeleton: View {
    var aspectRatio: CGFloat = 16 / 9
    var body: some View { RoundedRectangle(cornerRadius: MosaicRadius.media, style: .continuous).fill(MosaicColor.surface).aspectRatio(aspectRatio, contentMode: .fit).redacted(reason: .placeholder) }
}

struct MosaicArtwork: View {
    let url: URL?
    let fallbackURL: URL?
    let symbol: String
    @State private var image: UIImage?

    init(url: URL?, fallbackURL: URL? = nil, symbol: String) {
        self.url = url
        self.fallbackURL = fallbackURL
        self.symbol = symbol
    }

    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable().scaledToFill() }
            else { fallback }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .accessibilityHidden(true)
        .task(id: ArtworkRequestKey(primary: url, fallback: fallbackURL)) {
            image = await MosaicArtworkLoader.shared.image(primary: url, fallback: fallbackURL)
        }
    }
    private var fallback: some View { LinearGradient(colors: [MosaicColor.surface, MosaicColor.elevated], startPoint: .topLeading, endPoint: .bottomTrailing).overlay(Image(systemName: symbol).foregroundStyle(MosaicColor.secondaryText)) }
}

private struct ArtworkRequestKey: Hashable {
    let primary: URL?
    let fallback: URL?
}

actor MosaicArtworkLoader {
    static let shared = MosaicArtworkLoader()
    private let cache = NSCache<NSURL, UIImage>()

    func image(primary: URL?, fallback: URL?) async -> UIImage? {
        if let primary, let image = await image(for: primary, role: "primary") { return image }
        guard let fallback, fallback != primary else { return nil }
        return await image(for: fallback, role: "fallback")
    }

    private func image(for url: URL, role: String) async -> UIImage? {
        if let cached = cache.object(forKey: url as NSURL) { return cached }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            guard (200..<300).contains(status), let image = UIImage(data: data) else {
                #if DEBUG
                print("[Mosaic Artwork] \(role) failed status=\(status) url=\(url.absoluteString)")
                #endif
                return nil
            }
            cache.setObject(image, forKey: url as NSURL)
            return image
        } catch is CancellationError {
            return nil
        } catch {
            #if DEBUG
            print("[Mosaic Artwork] \(role) request failed url=\(url.absoluteString) error=\(error.localizedDescription)")
            #endif
            return nil
        }
    }
}
