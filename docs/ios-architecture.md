# Mosaic iOS foundation

## Structure

`Mosaic-iOS/App` owns the root session flow and tab shell. `Core` contains the small shared boundaries: configuration, Supabase authentication, Mosaic networking, API models, and semantic visual tokens. `Features/Auth` contains the only feature UI in Milestone 0. The remaining tabs are deliberately non-data placeholders.

## Configuration

`Mosaic-iOS/Resources/MosaicConfiguration.plist` is the client configuration source. It includes the production Mosaic API base URL and intentionally blank `supabaseURL` and `supabasePublishableKey` values. Add the project's Supabase URL and public publishable/anon key locally before enabling sign-in. Those values are public client configuration; never put a service-role key, database password, or provider secret in this file.

## Authentication and session flow

`SessionStore` is the only SwiftUI-facing authentication boundary. On launch it asks Supabase Swift to restore its securely persisted session. A restored access token is immediately sent to `GET /api/me` through `MosaicAPIClient`; only a successful response enters the signed-in shell. It exposes `launching`, `signedOut`, `signedIn`, and recoverable `error` states. Tokens are never logged or passed to views.

The signed-out screen starts Google OAuth through Supabase Swift. Complete the following before using it on a device:

1. Register `mosaic://login-callback` in Supabase Auth URL configuration.
2. Add the same custom URL scheme to the iOS target URL Types.
3. Enable/configure Google in Supabase Auth, including its provider credentials, in the Supabase dashboard.

The app already forwards incoming URLs to `SessionStore`; the explicit URL Type is intentionally deferred until the actual Supabase project configuration is supplied.

## API client

`MosaicAPIClient` owns URL construction, request headers, async URLSession work, cancellation propagation, response decoding, and normalized errors. Authenticated calls take a Supabase access token from the auth boundary and inject `Authorization: Bearer <token>`. Views never create `URLRequest`s or attach tokens. The first proof is the documented `GET /api/me` response decoded as `CurrentUser`.

## Dependencies

The only external Swift Package dependency is [supabase-swift](https://github.com/supabase/supabase-swift). UI uses SwiftUI and Observation; networking uses Foundation URLSession.

## Running

Open `Mosaic-iOS.xcodeproj`, populate the two public Supabase values in `MosaicConfiguration.plist`, resolve packages, and run the `Mosaic-iOS` scheme on a physical iPhone or simulator. Automatic signing and the existing bundle identifier are preserved.

Build verification:

```sh
xcodebuild -project Mosaic-iOS.xcodeproj -scheme Mosaic-iOS \
  -destination 'generic/platform=iOS Simulator' build
```

Focused unit tests in `Mosaic-iOSTests` cover configuration, URL construction, Bearer injection, normalized error decoding, session-state values, and `/api/me` decoding.
