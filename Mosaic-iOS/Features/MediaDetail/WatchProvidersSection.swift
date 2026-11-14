import SwiftUI

struct WatchProvidersSection: View {
    static let isAvailable = true
    let media: CatalogMedia

    @Environment(SessionStore.self) private var session
    @Environment(\.mosaicServices) private var services
    @State private var result: Result?
    @State private var saving = false
    @State private var saveFailure: String?

    private struct Result {
        let key: String
        let availability: WatchAvailability?
        let failed: Bool
    }

    struct ProviderGroup: Identifiable {
        let kind: WatchProviderKind
        let providers: [WatchProvider]
        var id: String { kind.rawValue }
        var label: String { WatchProvidersSection.label(for: kind) }
    }

    enum AvailabilityState { case noRegion, loading, failure, empty, available }

    static let regions: [(code: String, label: String)] = [
        ("IN", "India"), ("US", "United States"), ("GB", "United Kingdom"),
        ("CA", "Canada"), ("AU", "Australia")
    ]

    static func regionLabel(_ code: String?) -> String {
        guard let code, !code.isEmpty else { return "Choose a region" }
        return regions.first { $0.code == code }?.label ?? code
    }

    static func title(for type: CatalogMediaType) -> String {
        type == .tv ? "Where to watch this series" : "Where to watch"
    }

    static func hint(for type: CatalogMediaType) -> String {
        type == .tv
            ? "Availability is reported for the series; individual season availability can vary by provider."
            : "Choose your region to see local streaming, rental, and purchase availability."
    }

    static func copy(for state: AvailabilityState, type: CatalogMediaType, region: String?) -> String? {
        switch state {
        case .noRegion: hint(for: type)
        case .loading: "Checking availability…"
        case .failure: "Watch-provider data is temporarily unavailable."
        case .empty: "No streaming options found for \(regionLabel(region))."
        case .available: nil
        }
    }

    static func label(for kind: WatchProviderKind) -> String {
        switch kind {
        case .flatrate: "Stream"
        case .free: "Free"
        case .ads: "Free with ads"
        case .rent: "Rent"
        case .buy: "Buy"
        }
    }

    static func groups(_ providers: [WatchProvider]) -> [ProviderGroup] {
        let order: [WatchProviderKind] = [.flatrate, .free, .ads, .rent, .buy]
        return order.compactMap { kind in
            let matches = providers.filter { $0.kind == kind }
            return matches.isEmpty ? nil : ProviderGroup(kind: kind, providers: matches)
        }
    }

    static func regionMutation(_ code: String?) -> DetailMutation { .watchRegion(code) }

    private var region: String? { session.currentUser?.profile?.watchRegion }
    private var requestKey: String { "\(media.mediaKey)-\(region ?? "")" }
    private var currentResult: Result? { result?.key == requestKey ? result : nil }
    private var state: AvailabilityState {
        guard let region, !region.isEmpty else { return .noRegion }
        guard let currentResult else { return .loading }
        if currentResult.failed { return .failure }
        return currentResult.availability?.providers.isEmpty == false ? .available : .empty
    }

    var body: some View {
        if media.mediaType == .movie || media.mediaType == .tv {
            VStack(alignment: .leading, spacing: MosaicSpace.medium) {
                MosaicSectionHeader(Self.title(for: media.mediaType), eyebrow: "Availability") {
                    regionMenu
                }
                VStack(alignment: .leading, spacing: MosaicSpace.medium) {
                    if let saveFailure { MosaicNotice(text: saveFailure, tone: .failure) }
                    if let copy = Self.copy(for: state, type: media.mediaType, region: region) {
                        Text(copy)
                            .font(.subheadline)
                            .foregroundStyle(MosaicColor.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let availability = currentResult?.availability, state == .available {
                        ForEach(Self.groups(availability.providers)) { group in
                            VStack(alignment: .leading, spacing: MosaicSpace.small) {
                                Text(group.label).font(.headline).foregroundStyle(MosaicColor.primaryText)
                                ScrollView(.horizontal) {
                                    HStack(alignment: .top, spacing: MosaicSpace.medium) {
                                        ForEach(group.providers) { provider in
                                            providerView(provider, kind: group.label)
                                        }
                                    }
                                }
                                .scrollIndicators(.hidden)
                            }
                        }
                        VStack(alignment: .leading, spacing: MosaicSpace.small) {
                            Text("Availability data by JustWatch")
                                .foregroundStyle(MosaicColor.secondaryText)
                            if let link = availability.link {
                                Link(destination: link) {
                                    Label("View region-specific watch options", systemImage: "arrow.up.right")
                                }
                                .tint(MosaicColor.accent)
                            }
                        }
                        .font(.footnote)
                    }
                }
                .padding(.horizontal, MosaicLayout.pageHorizontal)
            }
            .task(id: requestKey) { await load() }
        }
    }

    private var regionMenu: some View {
        Menu {
            Picker("Watch region", selection: Binding<String?>(get: { region }, set: { selectRegion($0) })) {
                Text("Choose a region").tag(String?.none)
                // Preserve a profile region chosen in Settings outside the web's five options.
                if let region, !region.isEmpty, !Self.regions.contains(where: { $0.code == region }) {
                    Text(Self.regionLabel(region)).tag(Optional(region))
                }
                ForEach(Self.regions, id: \.code) { option in
                    Text(option.label).tag(Optional(option.code))
                }
            }
        } label: {
            VStack(alignment: .trailing, spacing: MosaicSpace.xxSmall) {
                Text("Watch region").font(.caption)
                if saving {
                    ProgressView("Saving…").font(.caption)
                } else {
                    Label(region ?? "Choose a region", systemImage: "globe")
                }
            }
            .frame(minHeight: MosaicLayout.minimumTouchTarget)
        }
        .disabled(saving)
        .accessibilityLabel("Watch region, \(Self.regionLabel(region))")
    }

    private func providerView(_ provider: WatchProvider, kind: String) -> some View {
        VStack(spacing: MosaicSpace.xSmall) {
            AsyncImage(url: provider.logoURL) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit()
                } else {
                    Text(provider.name).font(.caption2).multilineTextAlignment(.center)
                        .foregroundStyle(MosaicColor.secondaryText)
                }
            }
            .frame(width: 44, height: 44)
            .background(MosaicColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: MosaicRadius.small))
            Text(provider.name)
                .font(.caption).foregroundStyle(MosaicColor.primaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 100)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(provider.name), \(kind)")
    }

    private func selectRegion(_ code: String?) {
        guard !saving, code != region else { return }
        saving = true
        saveFailure = nil
        Task { @MainActor in
            defer { saving = false }
            do {
                // Live services refresh the profile; its region drives the availability task.
                try await services.mutate(Self.regionMutation(code))
            } catch {
                saveFailure = "Mosaic couldn’t save that region. Check your connection and try again."
            }
        }
    }

    private func load() async {
        guard let region, !region.isEmpty else { return }
        let key = requestKey
        do {
            let availability = try await services.watchProviders(media.route, region)
            guard !Task.isCancelled, key == requestKey else { return }
            // A mismatched server country must never appear under the selected region.
            guard availability == nil || availability?.country == region else {
                result = Result(key: key, availability: nil, failed: true)
                return
            }
            result = Result(key: key, availability: availability, failed: false)
        } catch {
            guard !Task.isCancelled, key == requestKey else { return }
            result = Result(key: key, availability: nil, failed: true)
        }
    }
}
