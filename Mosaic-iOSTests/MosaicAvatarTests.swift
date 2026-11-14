import UIKit
import XCTest
@testable import Mosaic_iOS

@MainActor
final class MosaicAvatarTests: XCTestCase {
    func testEveryPresetMapsToABundledImage() throws {
        let expected = ["AvatarOrbit", "AvatarPrism", "AvatarEclipse", "AvatarNebula", "AvatarPortal", "AvatarAurora", "AvatarMonolith", "AvatarMosaic"]
        XCTAssertEqual(AvatarPreset.all.count, expected.count)
        for (preset, expectedName) in zip(AvatarPreset.all, expected) {
            let assetName = try XCTUnwrap(AvatarPreset.assetName(for: preset.path))
            XCTAssertEqual(assetName, expectedName)
            // These tests are hosted in the app; Bundle.main contains Assets.car.
            XCTAssertNotNil(UIImage(named: assetName, in: .main, compatibleWith: nil), preset.path)
            let avatar = MosaicAvatarView(value: preset.path, name: nil)
            XCTAssertEqual(avatar.assetName, expectedName)
            XCTAssertNil(avatar.remoteURL)
            XCTAssertEqual(avatar.accessibilityLabel, "\(preset.name) avatar")
        }
    }

    func testHTTPSPhotoUsesRemoteImageWithInitialsFallback() {
        let value = "https://example.com/photo.jpg?size=128"
        let avatar = MosaicAvatarView(value: value, name: "  Alex Smith  ")
        XCTAssertNil(AvatarPreset.assetName(for: value))
        XCTAssertNil(avatar.assetName)
        XCTAssertEqual(avatar.remoteURL?.absoluteString, value)
        XCTAssertEqual(avatar.initials, "A")
        XCTAssertEqual(avatar.accessibilityLabel, "Profile photo")
    }

    func testMissingAndUnsupportedValuesUseInitialsFallback() {
        let values: [String?] = [nil, "", "/brand/mosaic/avatars/unknown.svg", "https://example.com/photo.SVG?size=128", "http://example.com/photo.png", "unknown", "https:///photo.png"]
        for value in values {
            let avatar = MosaicAvatarView(value: value, name: "  Alex Smith  ")
            XCTAssertNil(avatar.assetName, "\(String(describing: value))")
            XCTAssertNil(avatar.remoteURL, "\(String(describing: value))")
            XCTAssertEqual(avatar.initials, "A")
            XCTAssertEqual(avatar.accessibilityLabel, "Profile photo")
        }
        XCTAssertNil(AvatarPreset.assetName(for: "/brand/mosaic/avatars/unknown.svg"))
        XCTAssertEqual(MosaicAvatarView(value: nil, name: nil).initials, "M")
        XCTAssertEqual(MosaicAvatarView(value: nil, name: " \n ").initials, "M")
    }
}
