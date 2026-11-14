# Mosaic iOS parity — task cards

Companion to [`PARITY_PLAN.md`](PARITY_PLAN.md). Each card is scoped to be
delegated to Codex on its own. At delegation time the brief also carries the
exact web source excerpts named under **Contract** (copied, not paraphrased).

Conventions for every iOS task:

- Paths are relative to `~/Documents/Mosaic-iOS` unless prefixed `web:`
  (`~/Documents/Tracking App`).
- Edit **only** the listed files. New files go in the listed folders
  (synchronized groups: no `project.pbxproj` edits).
- Tests go in a **new** `Mosaic-iOSTests/<Area>Tests.swift`; fixtures in the
  task's own `*Fixtures.swift` (registered by T0.4).
- Follow the existing style: `MosaicColor`/`MosaicSpace`/`MosaicType` tokens,
  `MosaicStateMessage` for load/empty/error, `MosaicNotice` for results,
  `Loadable`, `MosaicErrorCopy`, Dynamic Type, VoiceOver labels.
- Never send `userId`; never title-match; never reconstruct artwork URLs.
- Done = acceptance criteria met **and** `build-for-testing` + `scripts/test.sh` green.

Complexity: S (≤ 1 file of substance), M (2–4 files), L (5+ files or tricky logic).

---

## M0 — Foundations

### T0.1 Complete command model
- **Objective:** `DetailMutation` can express all 20 `POST /api/me/state` commands with exact wire shapes.
- **Files:** `Mosaic-iOS/Core/Models/MosaicMutation.swift`; new `Mosaic-iOSTests/MosaicCommandTests.swift`.
- **Instructions:**
  1. Keep the public type name, `type`, `affectedRoute` and every existing static builder signature (no call-site changes). Internally replace the flat optionals with an enum payload and one exhaustive encoder.
  2. Add builders: `review.save(id?, media, body, containsSpoilers, rating?)`, `review.delete(id)`, `list.create(title, description, visibility)`, `list.add(listId, media, note?)`, `list.update(listId, title, description, visibility)`, `list.item.update(listId, itemId, note)`, `list.item.remove(listId, itemId)`, `list.reorder(listId, itemIds)`, `movie.update(watchId, media, watchedAt, isRewatch, rating?, review?, viewingContext?, streamingService?)`, `movie.delete(watchId)`.
  3. Extend `movieLog` with optional `viewingContext` (`theater|streaming|television|physical|digital|other`) and `streamingService` (sent only when context is `streaming`, matching web).
  4. `seasonState` sends `completedOn` (`yyyy-MM-dd`, today, ISO calendar, POSIX) when `state == "completed"` (web `series-hierarchy-pages.tsx:56`).
- **Contract:** web `src/lib/persistence/validation.ts` (all schemas), `src/lib/persistence/types.ts`.
- **Depends on:** P1. **Parallel with:** T0.2. **Complexity:** M.
- **Acceptance:** every command encodes to JSON that the web Zod schema accepts (field names, date formats, `null` vs omitted — `rating.set` keeps explicit `null`); existing `MosaicAlignmentTests` pass unchanged.
- **Tests:** one golden-JSON test per command (20), plus `completedOn` presence/absence and streaming-service omission.

### T0.2 Networking hardening and transport primitives
- **Objective:** consistent errors and the transports imports, export and Ask need.
- **Files:** `Mosaic-iOS/Core/Networking/MosaicAPIClient.swift`, `Mosaic-iOS/Core/Networking/MosaicAPIError.swift`; new `Mosaic-iOSTests/MosaicNetworkingTests.swift`.
- **Instructions:**
  1. Authenticated GETs: timeout policy matching public requests; map `URLError.timedOut` → `.timedOut`.
  2. Error decoding: after the envelope, accept legacy `{ "error": "<string>" }` and keep that message; keep status-code fallback.
  3. `mutate` gains a variant returning the response `Data` (used by T0.3); existing signature stays.
  4. `upload(path:, headers:, body: Data, token:) -> (Data, HTTPURLResponse)` (raw body POST; 207 is success).
  5. `download(path:, token:) -> URL` to a protected temporary file.
  6. `lines(path:, body:, token:) -> AsyncThrowingStream<Data, Error>` for NDJSON (`URLSession.bytes`), honouring cancellation; non-2xx before streaming decodes the error envelope (incl. `Retry-After` for 429 → `.rateLimited`).
  7. Never log tokens, bodies or file names.
- **Contract:** web `src/lib/api/errors.ts`; `docs/mobile-api.md` (error codes, assistant events).
- **Depends on:** P1. **Parallel with:** T0.1. **Complexity:** M.
- **Acceptance:** all existing tests pass; new behaviour covered with a `URLProtocol` stub.
- **Tests:** timeout mapping, legacy error, 207 upload, download to temp file, NDJSON split across chunk boundaries, cancellation.

### T0.3 PersonalStateStore
- **Objective:** one observable source for the full personal state, updated by every mutation response.
- **Files:** `Mosaic-iOS/Core/Models/PersonalHistory.swift`, `Mosaic-iOS/App/AppState.swift`, `Mosaic-iOS/App/AppShell.swift`, `Mosaic-iOS/Core/Networking/MosaicServices.swift`, `Mosaic-iOS/Core/Models/MosaicStateInvalidation.swift`, `Mosaic-iOS/App/MosaicVisualFixtures.swift`; new `Mosaic-iOSTests/PersonalStateStoreTests.swift`.
- **Instructions:**
  1. Extend `MosaicStateSnapshot` (lossy decoding kept) with: `watchRegion`, `reviews` (`id, media, body, containsSpoilers, rating?, updatedAt`), `lists` (reuse `UserList`), full `movieWatches` (`id, media, watchedAt, isRewatch, rating?, review?, viewingContext?, streamingService?`), full `episodeWatches` (`id, series, seasonNumber, episodeNumber, episodeTitle?, watchedAt, rating?, isRewatch?`), `seasonStates`, `tvHistory`; keep existing fields and helpers.
  2. `PersonalStateStore` (`@MainActor @Observable`) like `LibraryStore`: lazy `load`, `refresh`, keep last good value on failure, `apply(_ snapshot)`.
  3. Live `mutate` decodes the `POST /api/me/state` response into a snapshot and posts it in the `mosaicStateDidChange` notification's `userInfo`; the store applies it without refetching. If decoding fails, the store refreshes. `LibraryStore` behaviour is unchanged.
  4. Inject the store in `AppShell`; fixtures seed it.
- **Contract:** web `src/lib/persistence/types.ts` (`MosaicState`), `src/app/api/me/state/route.ts`.
- **Depends on:** T0.1, T0.2. **Complexity:** M.
- **Acceptance:** one `GET /api/me/state` per session until a forced refresh; after a mutation the store reflects the server response; Discover recommendations unchanged.
- **Tests:** decoding a realistic state fixture (incl. one malformed row skipped), apply-after-mutation, failure keeps last state.

### T0.4 Contract-first scaffolding
- **Objective:** declare every model, service, route and placeholder later tasks need, so feature tasks never touch shared files.
- **Files:** `Mosaic-iOS/Core/Networking/MosaicServices.swift`, `Mosaic-iOS/App/AppState.swift`, `Mosaic-iOS/App/AppShell.swift`, `Mosaic-iOS/App/MosaicVisualFixtures.swift`, `Mosaic-iOS/Features/MediaDetail/MediaDetailContainer.swift` (slots only), `Mosaic-iOS/Features/MediaDetail/SeriesExperienceViews.swift` (slots only), `Mosaic-iOS/Features/Profile/SettingsView.swift` (rows only), `.gitignore` (`.worktrees/`); new model files `Core/Models/{WatchAvailability,EpisodeRatings,MosaicSnapshot,ProfileStats,ImportModels,Franchises,AssistantModels}.swift`; new placeholder files listed below; new `Mosaic-iOSTests/ContractDecodingTests.swift`.
- **Instructions:**
  1. Models decoding the exact web shapes: `WatchAvailability`/`WatchProvider`/kind; `{ seasons: CatalogEpisode[][] }`; `MosaicSnapshot`/`MosaicTile`/`MosaicPeriod`; `ProfileStats` + `years` (for TB2); import types (`ImportPreview`, `ReconciliationRow`, `ImportHistoryItem`, apply result, sources, conflict policies); `Franchises` mirroring `web:src/lib/media/franchises.ts` (identities verbatim); assistant event/ref types.
  2. Service closures (live + `unavailable`): `watchProviders(route, country)`, `episodeRatings(route)`, `mosaic(period)`, `profileStats(period)` (route path from TB2; throws `.notFound` until deployed), `importHistory()`, `importPreview(source, filename, data)`, `importApply(jobId, request)`, `importUndo(jobId)`, `exportArchive()`, `assistant(request)` (stream), `publicList(id)`.
  3. Routes + destinations: `.franchise(slug)`, `.season(CatalogMedia, Int)` (wraps `SeasonExperienceView`), `.reviews`, `.diary`, `.stats`, `.mosaic(period?)`, `.recap(period)`, `.yourData`, `.credits`, `.importFlow`, `.ask(about: String?)`; each destination is a placeholder view type defined in the file its feature task owns.
  4. Placeholder views returning `EmptyView` (or a neutral `MosaicStateMessage` for routes, never linked from UI until implemented): `Features/MediaDetail/{RelatedTitlesSection,WatchProvidersSection,EpisodeRatingsSection,MovieHistorySection,FranchiseLink}.swift`, `Features/Reviews/{ReviewButton,ReviewSection}.swift`, `Features/Lists/AddToListButton.swift`, `Features/Franchise/FranchiseView.swift`, `Features/Profile/{CreditsView,StatsView,ReviewsListView}.swift`, `Features/Mosaic/{MosaicUniverseView,RecapView}.swift`, `Features/Ask/AskView.swift`, `Features/MediaDetail/AskAboutButton.swift`, `Features/Settings/{YourDataView,ExportDataView,ImportFlowView}.swift`.
  5. Insert the slots into movie/game/book detail and the series hub in web order (facts → history → providers → guide/ratings → related), and the two action buttons into `PersonalStoryPanel`.
  6. Settings rows: "Your data" and "About & credits" (hidden until their tasks land via a `static let isAvailable` flag in each placeholder).
  7. Fixture registry: a `MosaicFixtureScreen` hook so feature tasks add screens from their own `*Fixtures.swift` files.
- **Contract:** web `src/lib/media/types.ts`, `src/lib/mosaic/snapshot.ts`, `src/lib/analytics/stats.ts` (types), `src/lib/imports/types.ts`, `src/lib/imports/history.ts`, `src/lib/media/franchises.ts`, `src/lib/assistant/contract.ts`.
- **Depends on:** T0.3. **Complexity:** L.
- **Acceptance:** no visible change; all routes compile; decoding tests pass for every model using JSON copied from web tests/fixtures.

---

## M1 — Catalog-side detail parity (parallel, after T0.4)

### T1.1 Related titles section
- **Files:** `Features/MediaDetail/RelatedTitlesSection.swift`; `Mosaic-iOSTests/RelatedTitlesTests.swift`.
- **Instructions:** load `services.related(route)` once per title; heading = "Similar games" (game), "More by <first author>" or "Related books" (book), "Related stories" otherwise; poster shelf with medium labels; empty → muted line using the first failure message or the web fallback copy; failure never blocks the page; Save for later via existing context menu.
- **Contract:** web `detail-page.tsx` (`relatedHeading`, related block). **Complexity:** S.
- **Acceptance:** shows on movie/game/book/series; matches web headings and copy.

### T1.2 Where to watch
- **Files:** `Features/MediaDetail/WatchProvidersSection.swift`; `Mosaic-iOSTests/WatchProvidersTests.swift`.
- **Instructions:** movie and series only; region = profile `watchRegion`, else a picker (IN, US, GB, CA, AU — web list) that writes `settings.watchRegion` through `services.mutate`; groups in order Stream, Free, Free with ads, Rent, Buy with provider logos; "Availability data by JustWatch" + link to `availability.link` (open in Safari); states: choose region, checking, none for <region>, temporarily unavailable (503 legacy). Series hint copy from web.
- **Contract:** web `watch-providers.tsx`, `watch-providers/route.ts`. **Complexity:** M.
- **Acceptance:** region change refreshes the section and the profile; no crash on 503.

### T1.3 Episode ratings heatmap
- **Files:** `Features/MediaDetail/EpisodeRatingsSection.swift`; `Mosaic-iOSTests/EpisodeRatingsTests.swift`.
- **Instructions:** series hub; `services.episodeRatings`; drop specials (season 0) and empty seasons; grid seasons × episodes in a horizontal `ScrollView`; legend and thresholds exactly as `episodeRatingLegend` (9.7, 9, 8, 7, 6, 5, 0) with "Unrated" "—"; expanded state persisted in `@AppStorage` (default collapsed on iPhone); cell → `.season(series, n)`; VoiceOver label per cell as on the web; hide entirely on error/empty.
- **Contract:** web `episode-ratings-map.tsx`, `tests/episode-rating-category.test.ts`. **Complexity:** M.
- **Acceptance:** category function matches web tests; scrolls smoothly for 20 seasons × 30 episodes fixture.

### T1.4 Franchise screen, franchise link, About & credits
- **Files:** `Features/MediaDetail/FranchiseLink.swift`, `Features/Franchise/FranchiseView.swift`, `Features/Profile/CreditsView.swift`; `Mosaic-iOSTests/FranchiseTests.swift`.
- **Instructions:** link "Part of <title> →" when `Franchises.forMedia` matches; screen loads each identity via `services.detail` concurrently, groups Movies/Series/Games/Books, empty-state copy from web; Credits screen with TMDB (required notice text), JustWatch, IGDB, Google Books cards and links; flip both `isAvailable` flags.
- **Contract:** web `franchises.ts`, `app/franchise/[slug]/page.tsx`, `app/credits/page.tsx`. **Complexity:** M.
- **Acceptance:** Dune and The Witcher render; failed items are skipped; credits reachable from Settings.

### T1.5 Brand marks, platforms and credits on detail
- **Files:** `Features/MediaDetail/MediaDetailContainer.swift`.
- **Instructions:** studio (movie) / network (series identity area) logo with name fallback; game section "Platforms & credits": de-duplicated platform chips, developer/publisher with logos; keep facts free of duplicates; logos never drive layout.
- **Contract:** web `detail-page.tsx` (`BrandMark`, `GameMetadata`). **Complexity:** S.
- **Acceptance:** fixtures for movie with/without logo and a game with both companies.

---

## M2 — Personal history and logging (parallel with M1)

### T2.1 Logging completeness
- **Files:** `Features/QuickLog/MediaLogForm.swift`, `Features/QuickLog/QuickLogView.swift`; `Mosaic-iOSTests/LoggingFormTests.swift`.
- **Instructions:** movie: viewing context picker (labels: Not specified, Theater, Streaming, TV / Broadcast, Blu-ray / DVD, Digital purchase/rental, Other), streaming service field shown only for Streaming, "Mark as favourite" toggle → after `movie.log` succeeds send `library.upsert(status: watched, isFavorite: true)`; Quick Log: before typing, show up to 8 recent choices from `LibraryStore` items (web `choices`).
- **Contract:** web `quick-log-dialog.tsx`, `detail-page.tsx` (`MovieSection`). **Depends on:** T0.1. **Complexity:** M.
- **Acceptance:** encoded mutations match T0.1 goldens; favourite failure after a successful log reports a partial result.

### T2.2 Movie watch history and editor
- **Files:** `Features/MediaDetail/MovieHistorySection.swift`, new `Features/QuickLog/MovieWatchEditor.swift`; `Mosaic-iOSTests/MovieHistoryTests.swift`.
- **Instructions:** list the title's watches from `PersonalStateStore` newest first ("Watched <date>", First watch/Rewatch, context, service, ★); swipe/menu Edit → `MovieWatchEditor` pre-filled with **every** field (`movie.update` replaces the row); Delete with confirmation → `movie.delete`. Editor is reusable by T4.1.
- **Contract:** web `activity-page.tsx` (`DiaryEdit`), `supabase-state.ts` movie update/delete. **Depends on:** T0.1, T0.3. **Complexity:** M.
- **Acceptance:** edit round-trips untouched fields; delete removes one watch and Library watch count updates.

### T2.3 Reviews
- **Files:** `Features/Reviews/ReviewButton.swift`, `Features/Reviews/ReviewSection.swift`, new `Features/Reviews/ReviewEditorView.swift`; `Mosaic-iOSTests/ReviewTests.swift`.
- **Instructions:** button label "Review"/"Edit review"; editor sheet: body (1–10 000 chars, trimmed), "Contains spoilers", sends `review.save(id: existing?.id, …, rating: current rating if set)`; Delete with confirmation → `review.delete(id)`; detail section shows your review with spoiler blur until tapped.
- **Contract:** web `persistent-media-actions.tsx`, `validation.ts` (`review.save`). **Depends on:** T0.1, T0.3. **Complexity:** M.
- **Acceptance:** create/edit/delete reflected immediately from the mutation response; validation inline.

---

## M3 — Lists management

### T3.1 List creation and editor
- **Files:** `Features/Lists/ListsView.swift`, new `Features/Lists/ListEditorView.swift`; `Mosaic-iOSTests/ListEditorTests.swift`.
- **Instructions:** "New List" toolbar → sheet (title 1–120, description ≤ 1000, visibility Private/Public/Unlisted) → `list.create`; `ListDetailView` reads the live list from `PersonalStateStore` by id; owner editing: details sheet (`list.update`, description ≤ 2000), per-item note (`list.item.update`, ≤ 2000), `EditButton` + `onMove` → `list.reorder` with **all** ids, swipe delete → `list.item.remove`, "Add titles" search (≥ 2 chars, `services.search`, first 8, "Added" state) → `list.add`; `ShareLink` to `<API base>/lists/<id>` for public/unlisted. Empty-state copy from web.
- **Contract:** web `app/lists/page.tsx`, `list-detail.tsx`. **Depends on:** T0.1, T0.3. **Complexity:** L.
- **Acceptance:** each list command survives a cold launch; reorder order equals the web.

### T3.2 Add to list from detail
- **Files:** `Features/Lists/AddToListButton.swift`, new `Features/Lists/AddToListSheet.swift`; `Mosaic-iOSTests/AddToListTests.swift`.
- **Instructions:** sheet listing your lists with "Added" for lists already containing the title; tap → `list.add`; "New list…" → create then add (new id = id in the returned state that was not present before).
- **Depends on:** T0.1, T0.3. **Parallel with:** T3.1. **Complexity:** M.
- **Acceptance:** works for all four media; no duplicate add.

---

## M4 — Activity and Profile

### T4.1 Full activity, filters and movie diary
- **Files:** `Features/Profile/ActivityView.swift`, new `Core/Models/ActivityProjection.swift`; `Mosaic-iOSTests/ActivityProjectionTests.swift`.
- **Instructions:** port `projectActivity` over `PersonalStateStore` (ordering rule included) so history is unbounded; medium filter (All, Movies, Series, Games, Books); "Movie diary" mode with reviews shown and edit/delete via `MovieWatchEditor`; keep `services.activity` for Home/Profile previews.
- **Contract:** web `src/lib/activity/projection.ts`, `tests/activity-projection.test.ts`, `activity-page.tsx`. **Depends on:** T0.3, T2.2. **Complexity:** M.
- **Acceptance:** golden tests equal web test expectations; labels unchanged (`ActivityLabel`).

### T4.2 Profile structure
- **Files:** `Features/Profile/ProfileView.swift`, `Features/Profile/ReviewsListView.swift`; `Mosaic-iOSTests/ProfileSectionsTests.swift`.
- **Instructions:** segmented sections Overview / Diary / Reviews / Lists / Stats (native adaptation of web tabs); Overview: collection line (stories logged, media count, earliest activity from the Mosaic snapshot), story metrics with web definitions (`Movies watched` = `deriveProfileMovieCount`, unique episodes, games completed, books read), Your Mosaic + this year's recap entries, favourites by medium; Reviews list newest first with spoiler marker; Stats section links to `.stats`.
- **Depends on:** T0.3, T0.4, T4.4. **Complexity:** L.
- **Acceptance:** numbers equal the web for the same fixture state.

### T4.3 Stats screen
- **Files:** `Features/Profile/StatsView.swift`; `Mosaic-iOSTests/StatsViewTests.swift`.
- **Instructions:** period picker (All time + `years`); sections from `ProfileStats`: per-medium footprint with own units, half-star distribution (Swift Charts), top rated, genres, authors, monthly activity and weekdays (Swift Charts with accessible values); quiet-period copy from web.
- **Contract:** web `profile-stats.tsx`, `stats.ts`. **Depends on:** T0.4, **TB2 deployed** (D4). **Complexity:** L.

### T4.4 Avatar preset assets
- **Files:** `Mosaic-iOS/Assets.xcassets/Avatar*.imageset/` (8 new), new `Core/DesignSystem/MosaicAvatarView.swift`, `Features/Profile/ProfileView.swift` (swap avatar view only), `Features/Profile/EditProfileView.swift`.
- **Instructions:** copy `web:public/brand/mosaic/avatars/*.svg` into vector image sets (Preserve Vector Data); `MosaicAvatarView` renders preset → asset, https → `AsyncImage`, else gradient initial.
- **Complexity:** S. **Acceptance:** all 8 presets render in Profile and the picker.

---

## M5 — Your Mosaic and Recap

### T5.1 Your Mosaic (3D)
- **Files:** `Features/Mosaic/MosaicUniverseView.swift` (+ new files in `Features/Mosaic/`); `Mosaic-iOSTests/MosaicUniverseTests.swift`.
- **Instructions (D1 = 3D):** RealityKit `RealityView` scene mirroring the web vortex: port `web:src/lib/mosaic/universe-layout.ts` (depth = activity order, three spiral arms, lane steps) and `camera.ts` behaviour; poster planes textured from downsampled artwork with level of detail and release of far textures; drag to travel/turn, pinch, tap to focus (camera flies to the poster, others dim) with the story card as a sheet; month markers from recorded dates; period menu (All time + years); "Open story" → media route (map `series` → `tv`); Reduce Motion removes ambient rotation and camera easing; VoiceOver: a hidden chronological list of stories.
- **Contract:** web `snapshot.ts`, `universe-layout.ts`, `mosaic-universe.tsx`, `story-detail.tsx`, `tests/mosaic-universe-layout.test.ts`. **Depends on:** T0.4. **Complexity:** L (split into layout port + scene + interaction if needed).

### T5.2 Recap
- **Files:** `Features/Mosaic/RecapView.swift`, new `Core/Models/MosaicRecap.swift`; `Mosaic-iOSTests/MosaicRecapTests.swift`.
- **Instructions:** port `deriveMosaicRecap` (scenes appear only when facts exist) over `MosaicSnapshot`; paged full-screen story with skip/replay; hand-off to Your Mosaic; monthly caveat copy for games/books if the web shows one.
- **Contract:** web `src/lib/mosaic/recap.ts`, `tests/mosaic-recap.test.ts`, `mosaic-recap.tsx`. **Depends on:** T0.4. **Complexity:** M.

---

## M6 — Account and data

### T6.1 Email sign-in and sign-up
- **Files:** `Features/Auth/AuthView.swift`, `Core/Auth/SessionStore.swift`, `Features/Profile/SettingsView.swift` (sign-in method line); `Mosaic-iOSTests/EmailAuthTests.swift`.
- **Instructions:** segmented Sign in / Create account; email + password (min 8, `textContentType` username/password/newPassword), display name on sign-up sent as `data.display_name`; handle "confirm your email" when sign-up returns no session; Google remains; Settings shows the actual provider from the session.
- **Contract:** web `auth-screen.tsx`, `supabase-gateway.ts`, migration `handle_new_user`. **Depends on:** T0.4. **Complexity:** M.

### TB1 [web repo] Bearer auth for imports and export (B1)
- **Files:** `web:src/app/api/me/imports/route.ts`, `web:…/imports/preview/route.ts`, `web:…/imports/[jobId]/apply/route.ts`, `web:…/imports/[jobId]/undo/route.ts`, `web:src/app/api/me/export/route.ts`, new `web:tests/imports-export-auth.test.ts`, `web:docs/mobile-api.md`; then copy the doc to `docs/mobile-api.md` in iOS.
- **Instructions:** resolve the user with `getAuthenticatedUser(request)` and use its client; export reads `email` from the verified claims of the same principal; preserve mock mode, response bodies, status codes and cookie behaviour; move these routes from "Not ready" to documented contracts.
- **Depends on:** approval P4. **Complexity:** M.
- **Acceptance:** `npm run lint`, `npm run typecheck`, `npm test` pass; Bearer and cookie both authorize; deploy (owner).

### TB2 [web repo] Profile stats endpoint (B2)
- **Files:** new `web:src/app/api/me/profile-stats/route.ts`, new `web:tests/profile-stats-route.test.ts`, `web:docs/mobile-api.md`.
- **Instructions:** `?period=all|YYYY` → `{ stats: deriveProfileStats(state, period), years: statsYears(state) }`; 400 `VALIDATION_ERROR` for bad period; standard envelope; `private, max-age=0`.
- **Depends on:** P4, D4. **Complexity:** S.

### T6.2 Export
- **Files:** `Features/Settings/ExportDataView.swift`; `Mosaic-iOSTests/ExportTests.swift`.
- **Instructions:** "Export your Mosaic" → `services.exportArchive()` → `ShareLink`/document export of the ZIP; progress and error states; delete the temp file afterwards; explain contents (export schema).
- **Depends on:** T0.2, T0.4, TB1 deployed. **Complexity:** S.

### T6.3 Import: source, upload, preview, apply
- **Files:** `Features/Settings/ImportFlowView.swift` (+ new `Features/Settings/Import*.swift`), new `Core/Models/ImportReconciliation.swift`; `Mosaic-iOSTests/ImportFlowTests.swift`.
- **Instructions:** six web sources with details and template links; `.fileImporter` (zip/json/csv); reject > 12 MB locally; upload with `x-import-source`, percent-encoded `x-file-name`, content type; preview summary (counts, warnings, errors, normalized summary); conflict policy (default `review`) and "Import favourites"; "Accept high-confidence" and "Skip remaining"; apply (200/207) result; persist the in-progress preview per user in Application Support; port `previewCounts`, `acceptHighConfidence`, `selectCandidate`, `skipReconciliationRow`.
- **Contract:** web `data-settings.tsx`, `lib/imports/{types,reconciliation,client}.ts`, routes, `docs/imports.md`. **Depends on:** T0.2, T0.4, TB1 deployed. **Complexity:** L.

### T6.4 Import: reconciliation, history, undo
- **Files:** `Features/Settings/Import*.swift` (same feature folder as T6.3); `Mosaic-iOSTests/ImportReconciliationTests.swift`.
- **Instructions:** paginated review list (50 at a time); per row: candidates, manual search filtered to the row's media type, skip, change selection; Serializd normalized row presentation; history list (status, counts, dates, error summary) with Undo (confirmation) → result.
- **Depends on:** T6.3. **Complexity:** L.

---

## M8 — Mosaic AI (approved)

### T8.1 Ask Mosaic
- **Files:** new `Features/Ask/*.swift`, `Features/MediaDetail/AskAboutButton.swift` (slot added by T0.4); `Mosaic-iOSTests/AskTests.swift`.
- **Instructions:** streaming screen over `services.assistant` (NDJSON events `status`, `text`, `refs`, `scope`, `done`, `error`); render `[[rN]]` tokens as tappable titles from refs (unknown tokens dropped); history ≤ 8 turns sent as plain text with tokens rendered to titles; starters from the web; "Ask about this title" passes `about`; 401 → sign-in copy, 403 → hide entry points for this session, 429 → wait `Retry-After`, 503 → unavailable copy.
- **Contract:** web `docs/mobile-api.md` (Mosaic AI), `src/lib/assistant/contract.ts`, `ask-page.tsx`. **Depends on:** T0.2, T0.4. **Complexity:** L.

## Deferred

- **M7 / T7.1** People results in Search + public profile screen (needs B4). Deferred (D3).

## M9 — Integration

### T9.1 Integration, accessibility and docs
- **Files:** `App/MosaicVisualFixtures.swift`, `docs/IOS_ALIGNMENT_AUDIT.md`, `docs/V1_RELEASE_STATUS.md`, `docs/ios-architecture.md`, `docs/mobile-api.md`, `README.md`.
- **Instructions:** fixtures complete; VoiceOver/AX3/Reduce Motion review of all new screens; extend the device QA matrix; docs updated. Verification of the whole parity matrix is done by me, not delegated.
