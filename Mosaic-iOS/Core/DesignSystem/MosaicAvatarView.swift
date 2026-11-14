import SwiftUI

extension AvatarPreset {
    static func assetName(for path: String) -> String? {
        all.first { $0.path == path }.map { "Avatar\($0.id.capitalized)" }
    }
}

/// Bundled vector presets and remote photos share the same initials fallback.
struct MosaicAvatarView: View {
    let value: String?
    let name: String?

    var body: some View {
        Group {
            if let assetName {
                Image(assetName).resizable().scaledToFill()
            } else if let remoteURL {
                AsyncImage(url: remoteURL) { phase in
                    if case let .success(image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .clipShape(Circle())
        .overlay { Circle().strokeBorder(MosaicColor.highlight) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    var assetName: String? {
        value.flatMap { AvatarPreset.assetName(for: $0) }
    }

    var remoteURL: URL? {
        guard let value, let url = URL(string: value),
              url.scheme?.lowercased() == "https",
              let host = url.host, !host.isEmpty,
              url.pathExtension.lowercased() != "svg" else { return nil }
        return url
    }

    var initials: String {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.first.map { String($0).uppercased() } ?? "M"
    }

    var accessibilityLabel: String {
        AvatarPreset.name(for: value).map { "\($0) avatar" } ?? "Profile photo"
    }

    private var placeholder: some View {
        LinearGradient(colors: [MosaicColor.accent, CatalogMediaType.tv.accent], startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay(Text(initials).font(.title2.weight(.bold)).foregroundStyle(.white))
    }
}
