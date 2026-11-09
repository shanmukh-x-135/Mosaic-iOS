# Mosaic iOS — Phase 2 alignment audit

Status: **Phase 2 and the V1 completion pass implemented; awaiting device QA and
TestFlight upload.** Phase 2 is committed on `main` (`cdf2023`). The V1
completion pass (§9, 2026-11-10) is uncommitted at the time of writing; see
`docs/V1_RELEASE_STATUS.md` for the current release state.

Web reference: `~/Documents/Tracking App` at `f4cc9cb` (`main`) plus the V1
profile/library changes described in §9. The web repository is only modified by
the coordinated backend change (§9); the UI is unchanged.

## 1. Current architecture

| Concern | Implementation | Entry point |
| --- | --- | --- |
| Language / UI | Swift 5 mode (Swift 6.4 toolchain), SwiftUI + Observation | `Mosaic-iOS/MyApp.swift` |
| Deployment target | iOS 27.0, iPhone + iPad + visionOS families | `project.pbxproj` |
| Dependencies | Swift Package Manager, only `supabase-swift` ≥ 2.0.0 | `project.pbxproj` |
| Auth | Supabase Swift Google OAuth, Keychain session restoration owned by the SDK | `Core/Auth/SessionStore.swift` |
| Networking | `MosaicAPIClient` (URLSession, Bearer injection, normalized errors, 12 s public timeout) | `Core/Networking/` |
| Persistence | None on device besides the Supabase session and in-memory caches (`CatalogDetailCache`, `SeriesSeasonCache`, `SeriesPersonalStateCache`) | — |
| Mutations | `POST /api/me/state` with `DetailMutation`; success posts `mosaicStateDidChange` | `Features/MediaDetail/` |
| Root flow | `RootView` → `LaunchView` / `AuthView` / `AppShell` | `App/` |
| Visual fixtures | DEBUG `-mosaic-visual-fixtures` gallery | `App/MosaicVisualFixtures.swift` |

Build/test commands (verified 2026-10-12, Xcode 27.0 27A266a):

```sh
xcodebuild test -project Mosaic-iOS.xcodeproj -scheme Mosaic-iOS \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

Baseline before any change: **36/36 unit tests passed**. There are no UI tests,
no SwiftLint/SwiftFormat configuration and no SwiftUI previews. Available
simulators: iPhone 16, iPhone 17e (smaller), iPhone Air, iPhone 18 Pro Max (larger).

Environmental notes: the simulator already holds a real signed-in Supabase
session, so a plain launch reads **live production data**. Visual testing in
this phase therefore uses the fixture mode (no network writes) and only
read-only live screens. The local, uncommitted `MosaicConfiguration.plist`
(public Supabase URL and publishable key) and `Mosaic-Info.plist` reformatting
are the user’s own changes and are deliberately left unstaged.

## 2. Screen-by-screen comparison

| Screen | Web (`bc49972`) | iOS before Phase 2 | Gap |
| --- | --- | --- | --- |
| Navigation | Home, Discover, Library, Profile; global search; Quick Log dialog | 5 tabs incl. a fake “Log” tab intercepted by `onChange`; search duplicated as `.searchable` on Home **and** Discover **and** in the Log sheet; `SearchView` exists but is unreachable | Duplicate competing search systems; fragile tab interception |
| Home | Discovery reel → Continue → Recently logged (+ “View activity”) → Saved for later (“Watchlist, backlog & reading list”) → Worth a closer look; load-error notice with retry | Same sections, but featured hero overflows the right edge (scaled-to-fill artwork drives layout), Continue cards clip text on the left (stray `.offset`), Recently logged hides activity errors silently | Layout bugs; no section links; silent failures |
| Discover | Medium nav (All/Movies/Series/Games/Books); provider genres per medium (All = TMDB movie genres, labelled; books: explained as unavailable) fetched from `/api/catalog/genres`; 4-item spotlight with source label and save-for-later; Mosaic themes; one chapter per medium (`discoveryRails`) with honest empty rails; Because you watched; cross-media shelf | Genres derived from item strings and **mixed across media** (a “Drama” chip filters movies and series together); spotlight is the first item only; raw provider ratings; no save-for-later; no themes; header copy duplicated (“Discover” + “Find your next obsession”) | Genre semantics wrong; rating scale wrong; missing actions |
| Library | Media tabs with counts; per-medium status filters with counts; search; sort; grid/list; In progress from Continue; status change/remove per card (remove keeps history) | Media chips without counts; no status filter, no search, no list view; “Library Pulse” always shows movies/series/games/books counts even when filtered; status labels computed by capitalising wire values (“Dnf”, “Want To Read”) | Missing filters and labels |
| Media detail | Medium-specific actions; playthrough/reading forms bound to the **existing** record (`playthroughId`/`readingId`), pre-filled | Community rating shown raw (IGDB/Google Books are stored 0–5, TMDB 0–10) and unlabelled; game/book “Update progress” never sends `playthroughId`/`readingId`; heart on an untracked series adds it as **watching** | Two data-integrity bugs (below) |
| Lists | `/lists` index and list detail ordered by `position` with notes | Not present | Read-only browsing is a parity gap; creation/editing is out of scope (V1 deferred list management) |
| Profile | Identity, stats, Recently logged, favourites, activity, lists, settings, edit profile | Identity, 4 stats, recent activity, favourites, sign out. Activity labels fall back to “Updated reading” for every unknown event; “Movies watched” label over a count that includes rewatches | Labels wrong; no activity/lists/settings entry points |
| Activity | Full diary with web `activityLabel` rules | Only embedded rows | Missing screen |
| Settings | Watch region, imports/exports, account | Only Sign Out | Watch region editing is not a mobile contract yet — documented, not built |
| Search | Global, debounced, medium filters, partial failure notice | Good model (`SearchViewModel`, tested); presentation duplicated in three places | Consolidate into one native Search tab |

## 3. Confirmed functional bugs

1. **Duplicate game playthroughs / book readings.** `game.upsert` and
   `book.upsert` insert a new row when `playthroughId`/`readingId` is absent
   (`Tracking App/src/lib/persistence/supabase-state.ts:417-431`). iOS never
   sends them, so every “Update progress” creates another playthrough/reading,
   inflating stats and history. It also resets rating and playtime to whatever
   the blank form contained. The web takes the id from the full state
   snapshot (`quick-log-dialog.tsx:39-40`).
2. **Community ratings on the wrong scale.** The web normalizes all provider
   ratings to /10 with a source (`src/lib/media/ratings.ts`). iOS showed IGDB
   and Google Books 0–5 values as if they were /10 and never named the source.
3. **Favourite on an untracked series started it.** Detail’s heart used
   `defaultLibraryStatus` (series → `watching`) instead of the medium’s
   planned state (`saveForLaterStatus`: series → `watchlist`).
4. **Layout:** Home featured card overflowed the viewport; Continue card copy
   was offset and clipped (live screenshot, iPhone 16).
5. **Activity labels:** unknown event types defaulted to “Updated reading”;
   finished/completed and rewatch events were never distinguished.
6. **Visual fixtures did not render the real screens.** The DEBUG gallery
   re-implemented look-alike views, so it could not catch regressions in the
   shipped components.

## 4. Shared product rules (must match the web)

- Identity is `provider:mediaType:providerId`; `providerId` is opaque.
- Statuses per medium (`mediaStatuses`): movie `watchlist, watched`; series
  `watchlist, watching, completed, paused, dropped`; game `backlog, playing,
  paused, completed, dropped`; book `want_to_read, reading, paused, finished,
  dnf`. Labels: Watchlist, Watched, Watching, Completed, Paused, Dropped,
  Backlog, Playing, Want to read, Reading, Finished, **Did not finish**.
- Save for later = the medium’s first status, sent with `onlyIfUntracked: true`
  so an existing entry is never reset. Status changes omit `isFavorite`.
- User ratings: 0.5–5.0 in half steps. Community ratings: provider scale →
  /10, one decimal, labelled with the source (TMDB / IGDB / Google Books /
  Sample); 0 without votes is no rating.
- Series progress `totalEpisodes`/`percent` `null` means unknown, never 0 %.
  Book `percent` `0` is real. Game `playtimeMinutes` `0` is valid.
- Recommendations (“Because you watched”) are seeded only from logged movie and
  episode watches; never from statuses or progress timestamps.
- Removing from the Library keeps logs, ratings and history.

## 5. Recommended tokens and components

Colors from `globals.css`: background `#07090c`, elevated `#0c1016`, surface
`#11161d`, surface hover `#171e27`, foreground `#f5f7fa`, secondary `#b8c0cc`,
muted `#77808d`, accent `#78aefc`, rating `#f7c653`, success `#67d6a2`,
warning `#f2a65a`, danger `#ef6b73`, hairline `rgba(255,255,255,.075)`.
Medium accents: movie `#78aefc`, series `#a38cff`, game `#67d6a2`, book
`#f2a65a`, with the web’s per-medium dark fallback gradients.

Components: artwork that never drives layout, poster card, medium label,
community rating label, status label, chip with count, section header with
link, state message (loading/empty/error + retry), progress bar that hides
unknown progress.

## 6. Implementation order

1. Tokens, product rules, shared components; data-source abstraction so the
   real screens can render fixture data without network writes.
2. Navigation: native `Tab` API with a search-role tab, toolbar Quick Log.
3. Home and Discover.
4. Library and media details (incl. the playthrough/reading fix).
5. Lists (read-only), Profile, Activity, Settings.
6. Search consolidation, accessibility pass, fixtures and screenshots.

## 7. Backend gaps (resolved in the V1 pass)

- **Resolved:** `LibraryEntry` now carries `progressId` for games and books, so
  logging targets the persisted playthrough/reading without reading
  `GET /api/me/state`. It also carries `watchCount` for movies and
  `progress.platform` for games.
- **Resolved:** `PATCH /api/me/profile` replaces display name, username, bio and
  avatar, so profile editing exists on iOS instead of only on the web.
- **Resolved:** watch region is read from `GET /api/me` and written with
  `POST /api/me/state` (`settings.watchRegion`); Discover sends it as
  `?region=XX`.
- **Open (unchanged):** Discover genres, themes and related titles still use
  the public ancillary routes whose errors keep the legacy string shape.
- **Deferred to V1.1:** list/review CRUD, movie edit/delete, richer stats,
  iPad/visionOS/Mac, external TestFlight and CI.

## 8. Outcome (2026-10-12)

### What changed

| Area | Result |
| --- | --- |
| Design system | `Core/DesignSystem/MosaicDesignSystem.swift`: web palette tokens, medium accents and fallback gradients, spacing/radius/artwork-ratio tokens, Dynamic Type text styles (SF Pro, matching the web’s single sans family). `MosaicArtwork` now draws as an overlay so artwork can never widen its container. Components: page/section headers, rail, chip row with counts, medium label, community-rating label (with source), user-rating label, progress bar, state message, notice, typographic artwork fallback. `MosaicMediaComponents.swift`: poster card, media row, poster shelf, Save for later button/context menu, Quick Log toolbar item. Liquid Glass is no longer applied to detail buttons; only the system tab bar uses it. |
| Product rules | `Core/Models/MosaicProductRules.swift`: `LibraryStatus` (per-medium lists, web labels, planned/active), community-rating normalization to /10 with source and count, user-rating options, `ActivityLabel`. `DiscoverTaxonomy.swift`: web provider genre lists and Mosaic themes. `PersonalHistory.swift`: activity, stats, lists, state-snapshot subset (lossy decoding), recommendation seeds/build. `MosaicMutation.swift`: documented command builders. |
| Data access | `Core/Networking/MosaicServices.swift` wraps the unchanged `MosaicAPIClient` and `SessionStore`; screens depend on it, so fixtures render the real screens. `App/AppState.swift`: `MosaicRouter` (tabs, per-tab paths, Quick Log) and one shared `LibraryStore` (replaces three separate full-Library fetches). |
| Navigation | Native `Tab` API: Home, Discover, Library, Profile and a system search-role tab. Fake “Log” tab removed; Quick Log is a toolbar action on every root screen. Reselecting a tab pops to root; the selected tab and search query/filter are restored with `@SceneStorage`. Pushed screens hide the tab bar. |
| Home | Discovery reel (one pick per medium, swipe, no auto-advance), Continue, Recently logged + View activity, Watchlist/backlog/reading list + Open Library, Worth a closer look + Browse. Load failures show a retry notice. |
| Discover | Medium tabs, compact provider genre row per medium (`/api/catalog/genres`; books explained), spotlight with source label and Save for later, Mosaic themes (`/api/catalog/themes`), one chapter per medium with honest empty rails, Because you watched (seeded from logged watches via `/related`), cross-media shelf. |
| Library | Media tabs with counts, per-medium status filters with counts, local search, sort, grid/list (persisted), In progress from Continue, context menu to change status (never sends `isFavorite`) or remove with confirmation. |
| Detail | Shared hero/identity, source-labelled ratings, facts shown only when supplied, personal panel (status picker, half-star rating, favourite, medium log action). Series: episode progress + “Log SxxEyy”, season states, per-episode ticks, episode detail with watched date/rating. |
| Logging | `Features/QuickLog/`: Quick Log (medium → search → form) and the shared `MediaLogForm` with validation. Games/books edit the existing record and pre-fill it. |
| Profile | Identity, unit-honest stats, Recently logged, favourites, lists, links to Activity, Lists, Settings. New read-only `ActivityView`, `ListsView`/`ListDetailView`, `SettingsView` (account, sign out with confirmation). |

### Functional fixes (all covered by tests)

1. Game/book updates send `playthroughId`/`readingId` of the most recently
   updated record and pre-fill it; saving is disabled if the existing record
   couldn’t be read, so no duplicate is created.
2. Untouched playtime round-trips exactly (two-decimal hours).
3. Community ratings use the web’s scales and name their source.
4. **Clearing a rating** now sends `"value": null`; previously the key was
   omitted and the server rejected it (`rating.nullable()`), so “Clear rating”
   always failed.
5. Favouriting an untracked series adds it as Watchlist, not Watching.
6. Save for later uses `onlyIfUntracked` and skips tracked titles locally.
7. Library status changes and removals send a schema-valid identity
   (`genres`, `platforms`, `authors` arrays); the server never overwrites a stored
   snapshot (`upsertMedia` returns the existing row).
8. Home hero overflow and Continue copy clipping fixed.
9. Activity labels follow the web’s `activityLabel`.

### Verification (Xcode 27.0, iOS 27.0 simulators)

- Unit tests: **54/54 passed** on iPhone 16 (36 baseline, updated where copy
  or tokens changed intentionally, plus 18 new in `MosaicAlignmentTests`).
- Build: `xcodebuild build` succeeded with **0 compiler warnings** in project
  sources (only Xcode’s AppIntents metadata notice).
- No linter is configured in the repository, so none was run.
- Visual inspection (fixture mode, real screens): iPhone 16 (393 pt) for every
  screen; iPhone 18 Pro Max for Home, Discover, Library, Series, Book detail;
  Accessibility 3 Dynamic Type for Home, Discover, Library, Game detail,
  Profile; empty and error states for Home, Library, Profile; Library list
  layout. Screenshots: `docs/screenshots/phase2/` (`before/` holds the live
  baseline showing the overflow bug).
- Live, read-only: one launch of the signed-in simulator session rendered Home
  with real data; no taps, so no writes. Mutations were exercised only through
  unit tests and the fixture recorder.
- Not verified: VoiceOver with the screen reader running (labels/traits were
  reviewed in code only), Reduce Motion at runtime, a physical device, the
  iPhone 17e, interactive flows needing taps (Quick Log save, context menus,
  sheets) beyond rendering, and Discover/Library/Profile against live data.

### Known limitations and items needing approval

- Lists are read-only; creating, editing, reordering and sharing stay on the web.
- Avatar presets that are SVGs fall back to the gradient avatar (no SVG
  rendering on iOS).
- `mutedText` is `#8a93a0` instead of the web’s `#77808d`, to keep 4.5:1
  contrast on iOS surfaces.
- §9 resolves the playthrough-id, watch-count and watch-region gaps; the
  remaining backend item is the legacy error shape on auxiliary catalog routes.

## 9. V1 completion pass (2026-11-10)

Definition of done: **internal TestFlight V1**, iPhone only, portrait only.

### iOS changes

| Area | Result |
| --- | --- |
| Library contract | `LibraryItemDTO` decodes `progressId`, `watchCount`, and `progress.platform`; movie cards show “N watches logged”. |
| Logging | `MediaLogForm` reads `GET /api/me/library` instead of the full state snapshot, prefills games/books from the entry’s `progressId`/`progress`, and still refuses to save if the library read failed. |
| Profile | New `EditProfileView` (display name, username, bio, Mosaic avatar presets or an https image) sends `PATCH /api/me/profile`; `ProfileView` and `SettingsView` open it. `Profile` decodes `bio` and `watchRegion` and keeps the raw avatar value. |
| Watch region | `SettingsView` → Watch region list writes `settings.watchRegion`, refreshes `/api/me` and posts `mosaicProfileDidChange`; Home and Discover reload with `?region=XX`. |
| Networking | `MosaicAPIClient` gained a generic `send(method:path:body:token:as:)`; `DetailMutation` now encodes the non-media `settings.watchRegion` command. |
| Release | `TARGETED_DEVICE_FAMILY = 1`, portrait-only `Info.plist` keys (launch screen, scene manifest, category, `ITSAppUsesNonExemptEncryption=false`), `PrivacyInfo.xcprivacy`, `.gitignore`, `README.md`, `scripts/test.sh`, `scripts/archive.sh`. `xcuserdata` is no longer tracked. |

### Web changes (coordinated)

- New `src/lib/profile/{types,validation,service}.ts` and
  `src/lib/api/profile-contract.ts`; `PATCH /api/me/profile` at
  `src/app/api/me/profile/route.ts`.
- `src/lib/library/projection.ts` adds `progressId`, `watchCount` and game
  `platform`; `docs/mobile-api.md` documents all of it.
- Verified on the web side: `npm run typecheck` clean, `npm test` 286/286.

### Verification

- iOS app build: **BUILD SUCCEEDED** (`generic/platform=iOS`, code signing
  disabled for the check).
- iOS test target: **TEST BUILD SUCCEEDED** (`build-for-testing`).
- Unit tests did **not** run in this environment: no simulator runtime is
  installed. Run `scripts/test.sh` after installing one.
- Device QA is outstanding; see `docs/V1_RELEASE_STATUS.md`.
