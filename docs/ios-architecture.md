# Mosaic iOS foundation

## Structure

`Mosaic-iOS/App` owns the root session flow, the tab shell (`AppShell`), navigation state (`MosaicRouter`), the shared `LibraryStore`, and the DEBUG visual fixtures. `Core` contains configuration, Supabase authentication, networking (`MosaicAPIClient` plus the injectable `MosaicServices`), API models, cross-platform product rules (`MosaicProductRules.swift`), and the design system. `Features` holds Home, Discover, Library, MediaDetail, QuickLog, Search, Lists, and Profile (with Activity, Settings and the shared `EditProfileView`). `Mosaic-iOS/PrivacyInfo.xcprivacy` is the privacy manifest bundled with the app. See `docs/IOS_ALIGNMENT_AUDIT.md` for the alignment with the web app.

Visual fixtures: launch a DEBUG build with `-mosaic-visual-fixtures -mosaic-visual-screen <home|discover|library|profile|search|detail-movie|detail-game|detail-book|series|season|lists|list|activity|settings|quicklog>`, optionally `-mosaic-visual-state empty|error` and `-mosaic-visual-accessibility`. These render the shipped screens with canned data; personal data never touches the network and mutations are only recorded in memory.

## Configuration

`Mosaic-iOS/Resources/MosaicConfiguration.plist` is the client configuration source. It is committed with the public values:

| Key | Value |
| --- | --- |
| `MOSAIC_API_BASE_URL` | `https://mosaic-eight-theta.vercel.app` |
| `SUPABASE_URL` | `https://wyvhemuzxrqvgflqwfjd.supabase.co` |
| `SUPABASE_PUBLISHABLE_KEY` | `sb_publishable_…` (public publishable key) |

These are public client configuration values. Never put a service-role key, database password, or provider secret in this file. The app calls `GET /api/me`, `PATCH /api/me/profile`, and the library contract documented in `docs/mobile-api.md`; the deployed web app must include them.

The app target is iPhone only (`TARGETED_DEVICE_FAMILY = 1`), portrait only, and targets iOS 27. `Mosaic-Info.plist` is authoritative: the target sets `GENERATE_INFOPLIST_FILE = NO`, so `INFOPLIST_KEY_*` build settings do not reach the bundle. Orientation, launch screen, scene manifest, category and `ITSAppUsesNonExemptEncryption` live in the plist.

## Authentication and session flow

`SessionStore` is the only SwiftUI-facing authentication boundary. On launch it asks Supabase Swift to restore its securely persisted session. A restored access token is immediately sent to `GET /api/me` through `MosaicAPIClient`; a valid Supabase session enters the signed-in shell even if that profile request is temporarily unavailable. It exposes `launching`, `signedOut`, `signedIn`, and recoverable `error` states. Tokens are never logged or passed to views.

The signed-out screen starts Google OAuth through Supabase Swift with the native callback `mosaic://auth/callback`. Supabase Swift owns `ASWebAuthenticationSession`, exchanges the callback internally, and returns the established session directly to `SessionStore`; SwiftUI does not exchange the callback a second time. The restored access token then calls `/api/me` before profile data is shown. A temporary `/api/me` failure leaves the valid Supabase session signed in and displays a recoverable account-loading message in the shell.

Complete the following before using it on a device:

1. In Supabase Dashboard → Authentication → URL Configuration, add `mosaic://auth/callback` to Redirect URLs.
2. Enable/configure Google in Supabase Auth, including its provider credentials, in the Supabase dashboard.

Physical-device smoke test: delete/reinstall the app if needed, confirm the Mosaic icon is visible on the Home Screen, launch it, tap **Continue with Google**, complete the Google and Supabase browser flow, and confirm the app returns directly to the tab shell. Force quit and reopen to confirm session restoration. If `/api/me` is temporarily unavailable, the app remains signed in and shows a recoverable account-loading message.

## API client

`MosaicAPIClient` owns URL construction, request headers, async URLSession work, cancellation propagation, response decoding, and normalized errors. Authenticated calls take a Supabase access token from the auth boundary and inject `Authorization: Bearer <token>`. Views never create `URLRequest`s or attach tokens. The first proof is the documented `GET /api/me` response decoded as `CurrentUser`.

`MosaicServices` is the injectable seam every screen uses. It exposes the read projections (`continueItems`, `library`, `activity`, `stats`, `lists`, `stateSnapshot`, `seriesState`), the public catalog (`discover`, `genre`, `theme`, `related`, `search`, `detail`, `season`), and two writes: `mutate` for `POST /api/me/state` and `updateProfile` for `PATCH /api/me/profile`.

## Profile editing and watch region

`EditProfileView` edits the four fields the server owns: display name, username, bio and avatar. Client validation mirrors `src/lib/profile/validation.ts` so failures appear inline; the server remains authoritative. `ProfileUpdateRequest` always encodes `bio` and `avatarUrl`, including explicit `null`, because the route is a replace and omitting a key would leave the old value. On success `SessionStore.apply(profile:)` updates the signed-in user and `MosaicStateInvalidation.postProfileChange()` tells Home and Discover to reload.

Avatar presets are site-relative paths (`/brand/mosaic/avatars/<name>.svg`), so `Profile.avatar` keeps the raw stored value for editing while `avatarURL` is the parsed form. Bundled Web SVGs cannot render in `AsyncImage`; presets fall back to the same gradient placeholder as a missing photo.

Watch region is a profile field, not media state. Discover passes it to `GET /api/catalog/discover?region=XX`, and changing it sends the non-media mutation `{"type":"settings.watchRegion","value":"IN"}` (or `null` to clear), refreshes `/api/me`, and posts the profile notification.

## Home / Continue

Home uses the documented `GET /api/me/continue?limit=8` contract through `MosaicAPIClient`. The server is the source of truth for active/resumable series, books, and games, as well as ordering and media-specific progress. The client maps the typed `ContinueItem` DTO into a Home presentation model without re-filtering items or recreating tracking rules. Artwork uses the normalized optional backdrop or poster URL; cards gracefully fall back to a native placeholder when neither is available. The Home rail intentionally caps its presentation to eight server-ordered items.

## Dependencies

The only external Swift Package dependency is [supabase-swift](https://github.com/supabase/supabase-swift). UI uses SwiftUI and Observation; networking uses Foundation URLSession.

## Running

Open `Mosaic-iOS.xcodeproj`, resolve packages, and run the `Mosaic-iOS` scheme on a physical iPhone or simulator. Automatic signing and the existing bundle identifier are preserved.

Build verification:

```sh
xcodebuild -project Mosaic-iOS.xcodeproj -scheme Mosaic-iOS \
  -destination 'generic/platform=iOS' build
```

Unit tests (requires an installed simulator runtime):

```sh
scripts/test.sh
# DESTINATION="platform=iOS Simulator,name=iPhone 16" scripts/test.sh
```

`MosaicFoundationTests` covers the foundation (configuration, requests, errors, decoding, search, Home); `MosaicAlignmentTests` covers the product rules shared with the web and the alignment regression fixes.

Release: `scripts/archive.sh` writes `build/Mosaic.xcarchive`; upload it from Xcode Organizer to internal TestFlight. `Mosaic-iOS/PrivacyInfo.xcprivacy` declares no tracking and only app-functionality data collection.
