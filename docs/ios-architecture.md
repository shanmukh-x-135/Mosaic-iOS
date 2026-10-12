# Mosaic iOS foundation

## Structure

`Mosaic-iOS/App` owns the root session flow, the tab shell (`AppShell`), navigation state (`MosaicRouter`), the shared `LibraryStore`, and the DEBUG visual fixtures. `Core` contains configuration, Supabase authentication, networking (`MosaicAPIClient` plus the injectable `MosaicServices`), API models, cross-platform product rules (`MosaicProductRules.swift`), and the design system. `Features` holds Home, Discover, Library, MediaDetail, QuickLog, Search, Lists, and Profile (with Activity and Settings). See `docs/IOS_ALIGNMENT_AUDIT.md` for the Phase 2 alignment with the web app.

Visual fixtures: launch a DEBUG build with `-mosaic-visual-fixtures -mosaic-visual-screen <home|discover|library|profile|search|detail-movie|detail-game|detail-book|series|season|lists|list|activity|settings|quicklog>`, optionally `-mosaic-visual-state empty|error` and `-mosaic-visual-accessibility`. These render the shipped screens with canned data; personal data never touches the network and mutations are only recorded in memory.

## Configuration

`Mosaic-iOS/Resources/MosaicConfiguration.plist` is the client configuration source. Enter the public values in `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`; `MOSAIC_API_BASE_URL` remains `https://mosaic-eight-theta.vercel.app`. The Supabase values are intentionally blank in source control. They are public client configuration; never put a service-role key, database password, or provider secret in this file.

## Authentication and session flow

`SessionStore` is the only SwiftUI-facing authentication boundary. On launch it asks Supabase Swift to restore its securely persisted session. A restored access token is immediately sent to `GET /api/me` through `MosaicAPIClient`; a valid Supabase session enters the signed-in shell even if that profile request is temporarily unavailable. It exposes `launching`, `signedOut`, `signedIn`, and recoverable `error` states. Tokens are never logged or passed to views.

The signed-out screen starts Google OAuth through Supabase Swift with the native callback `mosaic://auth/callback`. Supabase Swift owns `ASWebAuthenticationSession`, exchanges the callback internally, and returns the established session directly to `SessionStore`; SwiftUI does not exchange the callback a second time. The restored access token then calls `/api/me` before profile data is shown. A temporary `/api/me` failure leaves the valid Supabase session signed in and displays a recoverable account-loading message in the shell.

Complete the following before using it on a device:

1. In Supabase Dashboard → Authentication → URL Configuration, add `mosaic://auth/callback` to Redirect URLs.
2. Enter `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` in `MosaicConfiguration.plist`.
3. Enable/configure Google in Supabase Auth, including its provider credentials, in the Supabase dashboard.

Physical-device smoke test: delete/reinstall the app if needed, confirm the Mosaic icon is visible on the Home Screen, launch it, tap **Continue with Google**, complete the Google and Supabase browser flow, and confirm the app returns directly to the tab shell. Force quit and reopen to confirm session restoration. If `/api/me` is temporarily unavailable, the app remains signed in and shows a recoverable account-loading message.

## API client

`MosaicAPIClient` owns URL construction, request headers, async URLSession work, cancellation propagation, response decoding, and normalized errors. Authenticated calls take a Supabase access token from the auth boundary and inject `Authorization: Bearer <token>`. Views never create `URLRequest`s or attach tokens. The first proof is the documented `GET /api/me` response decoded as `CurrentUser`.

## Home / Continue

Home uses the documented `GET /api/me/continue?limit=8` contract through `MosaicAPIClient`. The server is the source of truth for active/resumable series, books, and games, as well as ordering and media-specific progress. The client maps the typed `ContinueItem` DTO into a Home presentation model without re-filtering items or recreating tracking rules. Artwork uses the normalized optional backdrop or poster URL; cards gracefully fall back to a native placeholder when neither is available. The Home rail intentionally caps its presentation to eight server-ordered items.

## Dependencies

The only external Swift Package dependency is [supabase-swift](https://github.com/supabase/supabase-swift). UI uses SwiftUI and Observation; networking uses Foundation URLSession.

## Running

Open `Mosaic-iOS.xcodeproj`, populate the two public Supabase values in `MosaicConfiguration.plist`, resolve packages, and run the `Mosaic-iOS` scheme on a physical iPhone or simulator. Automatic signing and the existing bundle identifier are preserved.

Build verification:

```sh
xcodebuild -project Mosaic-iOS.xcodeproj -scheme Mosaic-iOS \
  -destination 'generic/platform=iOS Simulator' build
```

Unit tests: `xcodebuild test -project Mosaic-iOS.xcodeproj -scheme Mosaic-iOS -destination 'platform=iOS Simulator,name=iPhone 16'`. `MosaicFoundationTests` covers the foundation (configuration, requests, errors, decoding, search, Home); `MosaicAlignmentTests` covers the product rules shared with the web and the Phase 2 regression fixes.
