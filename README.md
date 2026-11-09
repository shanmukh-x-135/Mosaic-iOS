# Mosaic for iOS

The native iPhone client for Mosaic: track the movies, series, games and books
you are watching, playing and reading. It is a SwiftUI app backed by the
existing Mosaic web API and Supabase authentication, so an account made on the
web works here without a separate sign-up.

V1 is scoped to an **internal TestFlight** audience on iPhone, portrait only.

## Requirements

- Xcode 27 or newer (the app targets iOS 27).
- A simulator runtime installed in Xcode → Settings → Components, or a physical
  iPhone.
- For TestFlight: a paid Apple Developer team able to register
  `com.shanmukhpgsspersonalteam.MosaiciOS` in App Store Connect.

## Configuration

`Mosaic-iOS/Resources/MosaicConfiguration.plist` holds the client
configuration:

| Key | Value |
| --- | --- |
| `MOSAIC_API_BASE_URL` | Production Mosaic API (`https://mosaic-eight-theta.vercel.app`) |
| `SUPABASE_URL` | Public Supabase project URL |
| `SUPABASE_PUBLISHABLE_KEY` | Public Supabase publishable key |

These are public client values and safe to commit. Never put a service-role
key, database password or provider secret in this file. The app requires the
`GET /api/me` and `PATCH /api/me/profile` contracts documented in
`docs/mobile-api.md`; the deployed server must include the profile route.

Google sign-in needs `mosaic://auth/callback` listed under Supabase
Authentication → URL Configuration → Redirect URLs.

## Build and run

Open `Mosaic-iOS.xcodeproj`, select the `Mosaic-iOS` scheme and run on an
iPhone. Or from the terminal:

```sh
xcodebuild -project Mosaic-iOS.xcodeproj -scheme Mosaic-iOS \
  -destination 'generic/platform=iOS' build
```

## Tests

```sh
scripts/test.sh
# or: xcodebuild test -project Mosaic-iOS.xcodeproj -scheme Mosaic-iOS \
#       -destination 'platform=iOS Simulator,name=iPhone 17'
```

Unit tests live in `Mosaic-iOSTests/`: `MosaicFoundationTests` covers
configuration, requests, errors, decoding and search; `MosaicAlignmentTests`
covers the product rules shared with the web app.

## Release

```sh
scripts/archive.sh
```

Then upload the archive from Xcode Organizer (Window → Organizer → Archives →
Distribute App → App Store Connect → Upload) and add it to the internal
TestFlight group. The release build declares:

- iPhone only (`TARGETED_DEVICE_FAMILY = 1`), portrait only.
- `ITSAppUsesNonExemptEncryption = false` (only system TLS is used).
- `Mosaic-iOS/PrivacyInfo.xcprivacy` — no tracking, `UserDefaults` reason
  `CA92.1`, and Email Address, Name, User ID and Other User Content collected
  for app functionality only.

## Repository layout

- `Mosaic-iOS/App` — session root, tab shell, router, DEBUG visual fixtures.
- `Mosaic-iOS/Core` — configuration, Supabase auth, networking, API models,
  shared product rules, design system.
- `Mosaic-iOS/Features` — Auth, Home, Discover, Library, MediaDetail, QuickLog,
  Search, Lists, Profile (Activity, Settings, Edit Profile).
- `Mosaic-iOSTests` — unit tests.
- `docs/` — API contract, architecture, alignment audit, release status and QA
  checklists.

- `docs/ios-architecture.md` — code map and session/networking flow.
- `docs/IOS_ALIGNMENT_AUDIT.md` — how the iOS experience maps onto the web product.
- `docs/mobile-api.md` — the HTTP contract the app depends on.
- `docs/V1_RELEASE_STATUS.md` — what remains before TestFlight.
