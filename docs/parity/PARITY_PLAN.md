# Mosaic iOS — Web parity analysis and roadmap

Status: **Approved 2026-11-14** (M0, B1, B2, production deploy; decisions in §12). Prepared 2026-11-14. Task cards: [`TASKS.md`](TASKS.md). Progress:
[`TRACKER.md`](TRACKER.md).

| Repository | Path | Branch / HEAD | Working tree |
| --- | --- | --- | --- |
| Tracking App (web + backend, source of truth) | `~/Documents/Tracking App` | `main` @ `d8acc42` | Untracked only: `.claude/`, `.codex/`, `.mcp.json`, `CLAUDE.md`, `docs/PROJECT_STATUS.md`, `docs/architecture-diagram.html` |
| Mosaic iOS (implementation target) | `~/Documents/Mosaic-iOS` | `main` @ `4f54f92` | Untracked only: `CLAUDE.md` |

Both repositories were read directly. Nothing in either working tree was
modified, staged or reset. This plan builds on, and does not replace,
`docs/IOS_ALIGNMENT_AUDIT.md` (Phase 2 + V1 pass) and `docs/V1_RELEASE_STATUS.md`.

Baseline verified today: `xcodebuild build-for-testing` (generic iOS
Simulator, signing off) → **TEST BUILD SUCCEEDED**, 60 unit tests compile.
Unit tests could not run at first (no simulator runtime); the iOS 27 runtime
was installed on 2026-11-14 and an `iPhone 17` simulator created.

---

## 1. Architecture overview

### 1.1 How the two repositories relate

```
 iPhone (SwiftUI)                      Vercel: Next.js 16 (Tracking App)                 Supabase
 ───────────────                       ─────────────────────────────────                 ────────
 SessionStore ── supabase-swift ─────────────────────────────────────────────────────▶  Auth (Google, email)
      │ access token
 MosaicAPIClient ── Bearer ──▶ /api/me/*  getAuthenticatedUser(request) ── PostgREST ─▶  Postgres + RLS
                   (none)  ──▶ /api/catalog/*  ── TMDB / IGDB / Google Books (server-only keys)
 Browser (React) ── cookie ──▶ same routes; most pages read GET /api/me/state and derive views client-side
```

- The iOS app has **no backend of its own**. All personal data goes through
  the web's Next.js route handlers; all catalog data is normalized server-side.
- One write endpoint: `POST /api/me/state` accepts 22 discriminated commands
  (`src/lib/persistence/validation.ts`) and **returns the full updated
  `MosaicState`**. iOS currently discards that response.
- The web browser keeps one full `MosaicState` in memory
  (`mosaic-state-provider.tsx`) and derives Library, Activity, Stats, Mosaic,
  Recap, reviews and history from it with pure TypeScript functions. The
  mobile projections (`/api/me/continue|library|activity|stats|mosaic|series-state`)
  reuse those same functions server-side.

### 1.2 Web application (Tracking App)

| Concern | Implementation |
| --- | --- |
| Stack | Next.js App Router, React 19, TypeScript, Zod, Supabase SSR, framer-motion, three.js / R3F (Your Mosaic) |
| Routes (pages) | `/home`, `/discover`, `/library`, `/lists`, `/lists/[id]`, `/activity`, `/profile`, `/profile/[username]`, `/mosaic` (+`?recap=`), `/ask`, `/settings/data`, `/credits`, `/franchise/[slug]`, `/movie|game|book/[id]`, `/series/[id]` + `/season/[n]` + `/episode/[n]`, `/login`, `/signup` |
| Global UI | Desktop nav + mobile tab bar (Home, Discover, **Log**, Library, Profile); ⌘K search dialog (media + people); Quick Log dialog; Activity bell |
| State | `MosaicStateProvider` loads `GET /api/me/state`, mutates via `POST /api/me/state` |
| Auth | Supabase: email/password sign-in + sign-up (`display_name` metadata → `handle_new_user` trigger creates `profiles`), Google OAuth |
| Catalog | `src/lib/media/providers/{tmdb,igdb,google-books,mock}.ts` behind `src/lib/media/catalog.ts` |
| Persistence | `src/lib/persistence/supabase-state.ts` (13 migrations, RLS on every table) |
| Imports/exports | `src/lib/imports/*` (Letterboxd ZIP, Serializd normalized JSON, generic CSVs, reconciliation, provenance, undo RPCs), `src/lib/exports/mosaic-export.ts` |
| AI | `src/lib/assistant/*` read-only OpenRouter assistant, NDJSON stream, kill switch + allowlist (owner only in production) |
| Tests | 286 unit tests (`tests/`), Playwright e2e (`e2e/`) |

### 1.3 iOS application (Mosaic iOS)

| Concern | Implementation |
| --- | --- |
| Stack | SwiftUI + Observation, Swift 5 mode, iOS 27, iPhone/portrait, only dependency `supabase-swift` |
| Shell | `App/AppShell.swift`: `TabView` (Home, Discover, Library, Profile, search-role tab), per-tab `NavigationStack`, `MosaicRouter`, Quick Log sheet |
| Data seam | `Core/Networking/MosaicServices.swift`: injectable closures over `MosaicAPIClient`; DEBUG fixtures reuse the real screens |
| Shared state | `LibraryStore` (one `GET /api/me/library`, refreshed on `mosaicStateDidChange`), in-memory caches for catalog detail, seasons, series state |
| Writes | `DetailMutation` (`Core/Models/MosaicMutation.swift`) — 12 of 22 commands |
| Product rules | Swift mirrors of web rules: statuses/labels, rating scales, activity labels, recommendations, genres/themes, avatar presets (`MosaicProductRules.swift`, `DiscoverTaxonomy.swift`, `PersonalHistory.swift`) |
| Tests | `MosaicFoundationTests` (36), `MosaicAlignmentTests` (24); no UI tests, no linter |
| Project | File-system-synchronized groups: new files need no `project.pbxproj` edits |

---

## 2. Web feature inventory

Grouped by product area; "→" names the backend call(s) the web makes.

1. **Account** — email sign-in, email sign-up with display name, Google OAuth, sign out (`supabase-gateway.ts`); edit profile with 8 SVG avatar presets or https URL → `PATCH /api/me/profile` / gateway; watch region → `settings.watchRegion`.
2. **Home** — discovery reel, Continue, Recently logged + View activity, Saved for later, Worth a closer look → `/api/catalog/discover`, state; Ask band (AI, gated).
3. **Discover** — medium tabs, per-medium provider genres, spotlight with Save for later, Mosaic themes, chapters per medium, Because you watched, cross-media shelf → `/api/catalog/discover|genres|themes|…/related`.
4. **Search** — ⌘K global search, medium filter, partial-failure notice, **People** results linking to `/profile/[username]` → `/api/catalog/search` (`profiles`).
5. **Library** — media tabs/counts, status filters, search, sort, grid/list, pagination, status change/remove/favourite → state + `library.*`.
6. **Media detail (all)** — hero, community rating with source, facts, status/rating/favourite, **review write/edit/delete with spoiler flag**, **add to list**, **related titles** ("More by <author>", "Similar games"), **franchise link**, **studio/network/developer/publisher logos**, Ask about this title (gated).
7. **Movie** — log watch (date, rewatch, rating, **viewing context, streaming service**, review, favourite), **watch history list**, **where to watch** (JustWatch, inline region picker).
8. **Series** — hub, seasons, inline episode lists, episode tick/untick, season state (with `completedOn`), episode page with personal rating, log next episode, **public episode ratings heatmap**, where to watch, series activity card.
9. **Game / Book** — playthrough / reading forms editing the existing record, platform chips and credits.
10. **Quick Log** — medium → search → form; **recent choices** from the user's records; contextual from the current detail page.
11. **Lists** — index, **create**, list detail, **edit title/description/visibility**, **per-item notes**, **reorder** (drag + buttons), **remove item**, **add via search**, public list view `/api/lists/[id]`.
12. **Activity** — chronological history with **medium filter**; **Movie diary** with **edit/delete watch** (`movie.update`, `movie.delete`).
13. **Profile** — identity + collection line; tabs **Overview** (Your Mosaic feature, story metrics with artwork, recently logged, keep going, favourites), **Library** (favourites by medium), **Diary**, **Reviews**, **Lists**, **Stats** (period-aware: per-medium footprint, half-star distribution, top rated, genres, authors, monthly activity, weekdays); shortcuts.
14. **Public profile** — `/profile/[username]`: identity, rating/review/public-list counts (server component reading `profiles` directly; no API).
15. **Your Mosaic** — 3D chronological vortex of logged stories (2D fallback), period filter (all/year), focus card, open story; **Recap** `?recap=YYYY|YYYY-MM` adaptive scenes.
16. **Your data** — imports (Letterboxd ZIP, Serializd JSON, Serializd/Backloggd/Fable/generic CSV), dry-run preview, reconciliation (candidates, manual search, skip, accept high-confidence), conflict policy, import favourites, apply, history, undo; **export ZIP**; CSV templates.
17. **Mosaic AI (Ask)** — streaming assistant over own records with title refs (owner-only beta).
18. **Credits** — TMDB, JustWatch, IGDB, Google Books attribution.

## 3. iOS feature inventory

Implemented and wired to the real API (from code, not docs):

- Google OAuth, Keychain session restore, sign out; Edit Profile (name,
  username, bio, preset/https avatar — presets render as a gradient); Watch
  region (Settings).
- Home, Discover (genres, themes, spotlight, Because you watched), Search tab
  (media only), Library (filters, counts, search, sort, grid/list, status,
  remove, favourite via detail).
- Detail for movie/game/book: hero, identity, community rating with source,
  facts, About, personal panel (status, half-star rating, favourite, remove,
  log). Series hub, seasons, episode ticks, season states, episode detail with
  date/rating, adjacent navigation.
- Logging (`MediaLogForm`): movie (date, rewatch, rating, review), episode,
  game/book updating the existing record via `progressId`. Quick Log sheet.
- Lists (read-only), Activity (newest 100, no filter), Profile (identity, 4
  stats, recent, favourites, lists), Settings.
- DEBUG fixture gallery rendering the real screens.

## 4. Backend API inventory

| Endpoint | Auth | Web uses | iOS uses | Native-ready? |
| --- | --- | --- | --- | --- |
| `GET /api/me` | Bearer/cookie | — (gateway) | ✓ | Yes |
| `PATCH /api/me/profile` | Bearer/cookie | — | ✓ | Yes |
| `GET /api/me/state` | Bearer/cookie | ✓ (everything) | Discover recs only (partial decode) | Yes (heavy) |
| `POST /api/me/state` (22 commands) | Bearer/cookie | ✓ all 22 | 12 commands | Yes; **returns full state** |
| `GET /api/me/continue` | Bearer/cookie | — | ✓ | Yes |
| `GET /api/me/library` | Bearer/cookie | — | ✓ | Yes |
| `GET /api/me/activity?limit≤100` | Bearer/cookie | — | ✓ | Yes (no pagination) |
| `GET /api/me/lists` | Bearer/cookie | — | ✓ | Yes |
| `GET /api/me/stats` (`MosaicAnalytics`) | Bearer/cookie | — | ✓ | Yes (not the web Stats tab shape) |
| `GET /api/me/series-state` | Bearer/cookie | — | ✓ | Yes |
| `GET /api/me/media-state` | Bearer/cookie | — | — | Yes (unused) |
| `GET /api/me/mosaic?period=` | Bearer/cookie | — (derives client-side) | — | Yes |
| `POST /api/me/assistant` (NDJSON) | Bearer/cookie | ✓ | — | Yes, gated (allowlist, kill switch) |
| `GET /api/me/imports`, `POST …/preview`, `POST …/[jobId]/apply`, `POST …/[jobId]/undo` | **Cookie only** (`createClient()` + `getClaims()`) | ✓ | — | **No** — Bearer gets 401 |
| `GET /api/me/export` | **Cookie only** | ✓ | — | **No** — Bearer gets 401 |
| `GET /api/lists/[id]` | Anonymous (RLS) | ✓ | — | Usable; legacy `{error:string}` |
| `GET /api/catalog/search` | Public | ✓ | ✓ (ignores `profiles`) | Yes |
| `GET /api/catalog/{p}/{t}/{id}` | Public | ✓ | ✓ | Yes |
| `GET /api/catalog/{p}/tv/{id}/season/{n}` | Public | ✓ | ✓ | Yes |
| `GET /api/catalog/discover?region=` | Public | ✓ | ✓ | Yes (legacy errors) |
| `GET /api/catalog/genres`, `/themes`, `…/related` | Public | ✓ | ✓ | Yes (legacy errors) |
| `GET /api/catalog/{p}/{movie|tv}/{id}/watch-providers?country=` | Public | ✓ | — | Yes; `WatchAvailability { country, link?, providers[{id,name,logoUrl?,kind}] }`, 503 legacy |
| `GET /api/catalog/{p}/tv/{id}/episode-ratings` | Public | ✓ | — | Yes; `{ seasons: CatalogEpisode[][] }`, 503 legacy |
| Public profile by username | — | server component | — | **No endpoint** |
| Profile Stats (`deriveProfileStats`) | — | client-side | — | **No endpoint** |

---

## 5. Web → iOS feature parity matrix

Statuses: **Full**, **Partial**, **Not**, **Investigate**. "B#" refers to the
backend changes in §7.2. Task IDs refer to [`TASKS.md`](TASKS.md).

| # | Feature | Web implementation | iOS implementation | Status | Missing work | Backend dependencies |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Google sign-in, session restore, sign out | `auth-screen.tsx`, `supabase-gateway.ts` | `SessionStore`, `AuthView` | Full | — | — |
| 2 | Email/password sign-in | `signInWithPassword` | — | Not | Email form, errors (T6.1) | None (Supabase SDK) |
| 3 | Email sign-up with display name | `signUp({data:{display_name}})` + DB trigger | — | Not | Sign-up form, email-confirmation state (T6.1) | None |
| 4 | Edit profile | `profile-editor.tsx` | `EditProfileView` | Full | — | — |
| 5 | Avatar presets render | SVGs in `public/brand/mosaic/avatars` | Gradient fallback | Partial | Bundle 8 SVGs as vector assets (T4.4) | — |
| 6 | Watch region | Settings + inline in Where to watch | Settings only | Partial | Inline picker on detail (T1.2) | — |
| 7 | Home sections | `home-page.tsx` | `HomeView` | Full | — | — |
| 8 | Discover | `discover-page.tsx` | `DiscoverView` | Full | — | — |
| 9 | Search: media | `search-dialog.tsx` | `SearchView` | Full | — | — |
| 10 | Search: people → public profile | `profiles` in search response | ignored | Not | Decision D3 (M7) | B4 (public profile API) |
| 11 | Library browse/filter/sort/layout | `library-page.tsx` | `LibraryView` | Full | — | — |
| 12 | Status / rating / favourite on detail | `persistent-media-actions.tsx` | `PersonalStoryPanel` | Full | — | — |
| 13 | Reviews: write/edit/delete, spoilers | `review.save`, `review.delete` | — | Not | Editor + section (T2.3) | None |
| 14 | Add to list from detail | `list.add` | — | Not | Sheet incl. create-and-add (T3.2) | None |
| 15 | Related titles on detail | `…/related`, `relatedHeading()` | Only used for Discover recs | Not | Section with web headings (T1.1) | None |
| 16 | Franchise link + franchise page | static `franchises.ts` + detail fetch | — | Not | Swift mirror + screen (T0.4, T1.4) | None |
| 17 | Studio/network/developer/publisher logos, platform chips | `BrandMark`, `GameMetadata` | Names only in facts | Partial | Logo marks + platforms/credits section (T1.5) | None |
| 18 | Movie log: date, rewatch, rating, review | `movie.log` | `MediaLogForm` | Full | — | — |
| 19 | Movie log: viewing context, streaming service | `movie.log` fields | — | Not | Fields + encoding (T0.1, T2.1) | None |
| 20 | Log with favourite (movie) | follow-up `library.upsert` | — | Not | Toggle (T2.1) | None |
| 21 | Movie watch history on detail | `MovieSection` | — | Not | Section from personal state (T2.2) | None |
| 22 | Edit / delete a movie watch | `movie.update`, `movie.delete` | — | Not | Editor sheet (T2.2), diary (T4.1) | None |
| 23 | Where to watch (movie, series) | `watch-providers.tsx` | — | Not | Section + JustWatch attribution (T1.2) | None |
| 24 | Series hub, seasons, episodes, ticks, season state, episode rating | `series-hierarchy-pages.tsx` | `SeriesExperienceViews` | Full | — | — |
| 25 | Season state `completedOn` | sent when `completed` | omitted | Partial | Send today's date on completed (T0.1) | None |
| 26 | Public episode ratings heatmap | `episode-ratings-map.tsx` | — | Not | Native grid + legend (T1.3) | None |
| 27 | Log next episode from detail | `persistent-media-actions.tsx` | `SeriesEpisodeProgress` | Full | — | — |
| 28 | Game / book progress forms | `GameSection`, `BookSection` | `MediaLogForm` (`progressId`) | Full | — | — |
| 29 | Quick Log | `quick-log-dialog.tsx` | `QuickLogView` | Partial | Recent choices from your records (T2.1) | None |
| 30 | Lists: browse + detail | `lists/page.tsx`, `list-detail.tsx` | `ListsView`, `ListDetailView` | Full | — | — |
| 31 | Lists: create | `list.create` | — | Not | Create sheet (T3.1) | None |
| 32 | Lists: edit details/visibility | `list.update` | — | Not | Editor (T3.1) | None |
| 33 | Lists: notes, reorder, remove, add via search | `list.item.*`, `list.reorder`, `list.add` | — | Not | Editor (T3.1) | None |
| 34 | Public list via link | `/api/lists/[id]` | — | Not | Share link (T3.1); opening others' lists is optional | None (legacy errors) |
| 35 | Activity: chronological history | state projection (unbounded) | `ActivityView` (newest 100) | Partial | Full history from personal state (T4.1) | None |
| 36 | Activity: medium filter | `activity-page.tsx` | — | Not | Filter (T4.1) | None |
| 37 | Movie diary | `?view=diary` | — | Not | Diary mode with edit/delete (T4.1) | None |
| 38 | Profile overview (Your Mosaic feature, story metrics, keep going) | `profile-overview.tsx` | 4 stat tiles | Partial | Restructure (T4.2) | None |
| 39 | Profile: favourites by medium | Library tab | Mixed shelf | Partial | Per-medium shelves (T4.2) | None |
| 40 | Profile: reviews tab | `profile-page.tsx` | — | Not | Reviews list (T4.2) | None |
| 41 | Profile: rich Stats (period-aware) | `profile-stats.tsx` + `stats.ts` | 4 numbers from `MosaicAnalytics` | Partial | Stats screen with Swift Charts (T4.3) | **B2** (recommended) |
| 42 | Public profile page | server component | — | Not | Decision D3 (M7) | **B4** |
| 43 | Your Mosaic (universe) | `mosaic-universe.tsx`, `mosaic-page.tsx` | — | Not | Native view (T5.1), decision D1 | None (`/api/me/mosaic`) |
| 44 | Recap (year / month) | `recap.ts` | — | Not | Swift port over snapshot + story UI (T5.2) | None |
| 45 | Import (all sources, reconciliation, history, undo) | `data-settings.tsx`, `/api/me/imports/*` | Notice "use the web" | Not | T6.3, T6.4 | **B1** (Bearer auth) |
| 46 | Export ZIP | `/api/me/export` | — | Not | Download + share (T6.2) | **B1** |
| 47 | CSV templates | `public/templates/*.csv` | — | Not | Links in import flow (T6.3) | None |
| 48 | Mosaic AI (Ask) + "Ask about this title" | `ask-page.tsx`, `/api/me/assistant` | — | Not | Decision D2 (M8) | Production enablement for mobile |
| 49 | Credits / provider attribution | `/credits` | — | Not | About & credits screen (T1.4) | None |
| 50 | Load / empty / error states, retry | per page | Shared components | Full | Extend to new screens (all tasks) | — |
| 51 | Notifications / background work | none (Bell = Activity link) | none | N/A | — | — |
| 52 | Landing / marketing page `/` | `app/page.tsx` | `AuthView` | N/A | — | — |

**Summary:** 13 Full, 9 Partial, 28 Not, 2 N/A (52 rows). Every "Not" item
except #10/#42 (public profiles), #45/#46 (imports/export) and #48 (AI) can be
built against existing contracts with no backend change; #41 (rich Stats) is
recommended to use the new B2 endpoint.

---

## 6. Technical assessment

| # | Finding | Why it matters | Recommendation | Benefit | Risk / migration |
| --- | --- | --- | --- | --- | --- |
| A1 | **Most remaining features need the full personal state** (reviews, movie watches with ids/viewing context, lists, season states). iOS only decodes a lossy subset of `GET /api/me/state`, used once by Discover. | Without a shared store, every new screen would re-fetch the heavy snapshot and drift. | Add a `PersonalStateStore` (like `LibraryStore`) that loads `GET /api/me/state` once and **applies the `MosaicState` returned by `POST /api/me/state`** — no extra round trip after writes. Keep `LibraryStore` and the focused projections for Home/Library. (T0.3) | One consistent source for history features; writes refresh for free. | Large accounts make a big payload; decode lossily and lazily (first screen that needs it). Two stores must refresh together: both listen to the same notification. |
| A2 | `DetailMutation` is a flat struct of 26 optionals with a special-case encoder; it covers 12 of 22 commands. | Adding the 10 missing commands (+6 fields) as more optionals lets invalid combinations compile and encode. | Keep the public type and existing builders (no call-site churn) but make the payload an internal enum with one exhaustive encoder; add builders for every command; golden JSON tests per command mirroring `validation.ts`. (T0.1) | Type-safe, complete command surface; a single place to audit wire shapes. | Contained to one file + tests. Existing alignment tests must keep passing unchanged. |
| A3 | Authenticated GETs have no explicit timeout and don't map `URLError.timedOut`; legacy `{ "error": "string" }` bodies (imports, export, lists, ancillary catalog) collapse to a generic message. | Import errors carry user-actionable text ("Import files must be 12 MB or smaller."). | Harden `MosaicAPIClient`: shared timeout policy, timedOut mapping, legacy string decoding; add raw upload, file download and NDJSON line streaming primitives. (T0.2) | Needed by imports, export and Ask; consistent errors. | Low; covered by unit tests with `URLProtocol` stubs. |
| A4 | `MosaicServices` and `MosaicRoute`/destinations are shared by every feature. | Parallel tasks editing them would conflict. | **Contract-first scaffolding** (T0.4): declare all new service closures, models, routes, Settings rows and **placeholder views/detail slots** (rendering nothing) up front. Feature tasks then only fill in files they own. | Safe parallel delegation; no shared-file merge conflicts. | Placeholders must render `EmptyView` so nothing half-built ships. |
| A5 | Business-logic mirrors in Swift (statuses, labels, activity labels, recommendations, genres, themes, avatars; next: franchises, recap, activity projection, import reconciliation). | Drift from the web is the main correctness risk. | Port only small, pure functions (recap 44 lines, projectActivity ~70, reconciliation helpers) with **golden tests copied from web test fixtures**; use a **server projection for Profile Stats** (215 dense lines) — B2 (task TB2). | Bounded duplication; complex analytics stay single-sourced. | B2 is a backend change needing approval + deploy; fallback is a Swift port with golden tests. |
| A6 | Imports/export routes authenticate with cookies only. | iOS cannot use them at all today. | B1: switch the 5 handlers to `getAuthenticatedUser(request)`; cookie path unchanged. | Unblocks M6 (task TB1). | Backend change + production deploy; export also needs the email claim (bearer `getClaims(token)` provides it). |
| A7 | Unit tests cannot run (no simulator runtime). | The verification loop in `CLAUDE.md` requires running tests. | **Install an iOS 27 simulator runtime before delegation** (Xcode → Settings → Components). | Real test results per task. | Without it, tasks can only be verified by `build-for-testing` + fixtures, which is not acceptable for mutations. |
| A8 | Parallel Codex agents in one working tree would compile each other's half-written files. | False build failures; corrupted verification. | Each parallel task runs in its own git worktree `.worktrees/<task-id>` on branch `parity/<task-id>` with its own DerivedData; merged into an integration branch `parity/integration` after verification. | Isolation and clean review diffs. | Needs commits on local branches (approval requested in §10). `.worktrees/` added to `.gitignore`. |
| A9 | Fixture gallery only covers existing screens. | Visual QA without live writes depends on fixtures. | Every UI task adds fixture data + a `-mosaic-visual-screen` key for its screen. | Screenshots for review at 393 pt and Accessibility sizes. | Small `MosaicVisualFixtures.swift` edits → that file is owned by T0.4 and later by M9 only; feature tasks add fixtures in their own `*Fixtures.swift` file registered by T0.4. |
| A10 | Known web data issues inherited by iOS: imported Serializd facts override Library series status; most stored series snapshots lack episode totals; monthly recap places games/books by last update (web PROJECT_STATUS P1/P2). | Users may see the same oddities on iOS. | Do not "fix" on iOS; reproduce web behaviour and document. Raise separately. | Parity and honesty. | — |
| A11 | App Store (not internal TestFlight) rules: account creation requires in-app account deletion (5.1.1(v)); Google sign-in may require Sign in with Apple (4.8); TMDB and JustWatch require attribution. | Matters if the target moves beyond internal TestFlight. | Attribution is in scope (T1.4). Account deletion and Sign in with Apple are **out of scope** and need backend/product decisions (D5). | No surprise at review. | — |
| A12 | Security: tokens never logged (good); new upload/export paths handle personal data. | Exports contain the whole account. | Write export ZIP to a temporary directory with file protection, delete after the share sheet closes; never log file names/bodies; uploads ≤ 12 MB checked client-side. | — | — |

Not recommended: rewriting the shell, replacing `LibraryStore`, adding
third-party packages (Swift Charts and SwiftUI cover charts and the Mosaic
view), or porting the three.js scene literally.

---

## 7. Architectural recommendations

### 7.1 iOS

1. **Command model completion** (A2) — T0.1.
2. **Client hardening and transport primitives** (A3) — T0.2.
3. **`PersonalStateStore`** fed by `GET /api/me/state` and every mutation response (A1) — T0.3.
4. **Contract-first scaffolding**: services, models, routes, Settings rows, placeholder views and detail slots (A4) — T0.4.
5. **Isolated worktrees per parallel task** (A8).
6. **Native adaptations**, not web layouts: sheets for editors, `List` +
   `onMove` for reordering, `Menu`/`Picker` for choices, `ShareLink` for
   lists and exports, `.fileImporter` for imports, Swift Charts for Stats,
   paged `TabView` for Recap, swipe actions in diary rows, Reduce Motion
   respected everywhere.

### 7.2 Backend (Tracking App) — each needs separate approval

| ID | Change | Justification | Size | Required for |
| --- | --- | --- | --- | --- |
| **B1** | Use `getAuthenticatedUser(request)` in `src/app/api/me/imports/route.ts`, `…/imports/preview/route.ts`, `…/imports/[jobId]/apply/route.ts`, `…/imports/[jobId]/undo/route.ts`, `…/export/route.ts`; keep cookie behaviour and response shapes; add route tests; document in `docs/mobile-api.md` (both repos). | Bearer tokens are rejected today; no workaround exists without a service key on device (unacceptable). | S–M | Imports, export (M6) |
| **B2** | New `GET /api/me/profile-stats?period=all\|YYYY` → `{ stats: ProfileStats, years: number[] }` reusing `deriveProfileStats` + `statsYears`; standard error envelope; tests. | Avoids duplicating 215 lines of analytics in Swift; existing `/api/me/stats` stays unchanged for current iOS. | S | Rich Stats (T4.3) |
| B4 (optional) | `GET /api/profiles/[username]` returning the public profile + counts the web page shows. | Only if D3 = build people search. | S | M7 |
| — | Deploy to production after B1/B2. | iOS uses the deployed API. | — | M6, T4.3 |

No other backend change is needed for parity.

---

## 8. Milestone roadmap

Order: shared infrastructure → features with no backend dependency → features
waiting on backend/decisions → integration. Each milestone's acceptance
criteria are in addition to the per-task criteria in `TASKS.md`.

### M0 — Foundations (T0.1–T0.4)
- **Objective:** a complete, typed command surface; hardened client; one
  personal-state source; scaffolding that lets later tasks run in parallel.
- **Outcome:** no user-visible change; all existing tests pass; new golden tests pass.
- **Files:** `Core/Models/MosaicMutation.swift`, `Core/Networking/*`,
  `Core/Models/PersonalHistory.swift`, `App/AppState.swift`, `App/AppShell.swift`,
  `Core/Models/MosaicStateInvalidation.swift`, `App/MosaicVisualFixtures.swift`, new model and placeholder files.
- **Endpoints:** `GET/POST /api/me/state`; declarations for every endpoint in §4 that later milestones use.
- **Dependencies:** P1 (simulator runtime). T0.1 ∥ T0.2 → T0.3 → T0.4.
- **Risks:** regressions in existing mutations (mitigated by unchanged builder signatures and existing alignment tests).
- **Acceptance:** 60 existing tests + new tests pass; `build` has 0 new warnings; fixture gallery renders every existing screen unchanged.

### M1 — Catalog-side detail parity (T1.1–T1.5)
- **Objective:** everything on the web detail page that needs no personal history.
- **Features:** related titles, where to watch (+ inline region), episode ratings heatmap, franchise link/page, brand logos and game platforms/credits, credits & attribution screen.
- **Endpoints:** `…/related`, `…/watch-providers?country=`, `…/episode-ratings`, catalog detail, `settings.watchRegion`.
- **Dependencies:** M0. All five tasks run in parallel (disjoint files).
- **Risks:** watch providers/episode ratings return legacy 503 bodies — sections must hide or show a quiet notice, never break the page (web behaviour).
- **Acceptance:** each section matches web copy and omission rules; fixtures for loaded/empty/failure.

### M2 — Personal history on detail and logging (T2.1–T2.3)
- **Objective:** complete movie logging and reviews.
- **Features:** viewing context, streaming service, log-as-favourite, Quick Log recent choices, movie watch history with edit/delete, reviews write/edit/delete.
- **Endpoints:** `movie.log|update|delete`, `review.save|delete`, `library.upsert`.
- **Dependencies:** T0.1, T0.3, T0.4. Parallel with M1.
- **Risks:** `review.save` rating is optional and **only valid 0.5–5**; sending the current rating must omit when nil. `movie.update` replaces the row: unspecified optional fields are cleared, so the editor must round-trip every field.
- **Acceptance:** device QA rows "edit watch", "delete watch", "review save/edit/delete" pass; no duplicate watches.

### M3 — Lists management (T3.1–T3.2)
- **Objective:** full list CRUD on iOS.
- **Endpoints:** `GET /api/me/lists`, `list.create|update|add|item.update|item.remove|reorder`.
- **Dependencies:** M0; parallel with M1/M2.
- **Risks:** `list.create` does not return the new id directly — derive it by diffing list ids in the returned state. Reorder must send **every** item id.
- **Acceptance:** create → add → note → reorder → remove → edit visibility, each surviving cold launch and matching the web.

### M4 — Activity and Profile (T4.1–T4.4)
- **Objective:** full history, diary and the web profile structure.
- **Dependencies:** T4.1 needs T2.2; T4.2 needs T4.4; T4.3 needs **TB2 (B2) deployed** (or D4 = Swift port).
- **Risks:** ported `projectActivity` must match the web ordering rule (date desc, repeat first, eventId desc) — golden tests.
- **Acceptance:** Activity shows the full history with filters; diary edit/delete; profile sections; stats numbers equal the web for the same account.

### M5 — Your Mosaic and Recap (T5.1–T5.2)
- **Objective:** a native "Your Mosaic" and the recap story.
- **Endpoints:** `GET /api/me/mosaic?period=all|YYYY|YYYY-MM`.
- **Dependencies:** M0; decision D1 (fidelity). T5.1 ∥ T5.2.
- **Risks:** performance with 500+ tiles (lazy artwork, downsampled images); monthly game/book attribution caveat (A10).
- **Acceptance:** 60 fps scroll on device with 500 tiles in fixtures; recap scenes equal web output for golden fixtures; Reduce Motion path.

### M6 — Account and data (T6.1–T6.4, TB1)
- **Objective:** email auth, import and export on iOS.
- **Dependencies:** T6.1 after M0 only. TB1 (= B1, web repo) → deploy → T6.2 ∥ T6.3 → T6.4.
- **Risks:** large previews (up to 20 000 rows) — paginate the reconciliation list; preview resumability (persist per user in Application Support); 207 partial results.
- **Acceptance:** Letterboxd ZIP and generic CSV imports from Files reach "completed"; undo restores; export ZIP opens and matches the web export for the same account.

### M7 — People search and public profiles (deferred, D3)
Needs B4. The web page itself is a stub ("Public activity is coming next"). Deferred by decision D3.

### M8 — Mosaic AI on iOS (in scope, D2)
NDJSON streaming client, Ask screen, ref rendering, "Ask about this title".
Approved for iOS on 2026-11-14; `docs/mobile-api.md` updated in both repos.
Access stays governed by the server kill switch and allowlist (403 hides the entry point).

### M9 — Integration and release QA (T9.1)
Fixtures, accessibility (VoiceOver, Dynamic Type AX3, Reduce Motion), docs
updates, extended device QA matrix, full test run, regression pass of the
V1 mutation matrix.

---

## 9. Dependencies and execution order

```
P1 simulator runtime ─┐
                      ▼
Wave A:  T0.1 ║ T0.2
Wave B:  T0.3
Wave C:  T0.4
Wave D:  T1.1 ║ T1.2 ║ T1.3 ║ T1.4 ║ T1.5 ║ T2.1 ║ T2.2 ║ T2.3 ║ T3.1 ║ T3.2 ║ T4.4 ║ T5.2 ║ T6.1
         (run at most 4 at a time; order inside the wave = table order in TASKS.md)
         Web repo, in parallel with Wave D after approval: TB1 (B1) → TB2 (B2) → deploy
Wave E:  T4.1 (after T2.2) ║ T4.2 (after T4.4) ║ T5.1 ║ T4.3 (after TB2 deploy) ║ T6.2, T6.3 (after TB1 deploy)
Wave F:  T6.4 (after T6.3)
Wave G:  optional M7 / M8 (after decisions) → T9.1
```

**Shared files and owners** (only the owner edits them in a wave):

| File | Owner(s) in order |
| --- | --- |
| `Core/Models/MosaicMutation.swift` | T0.1 |
| `Core/Networking/MosaicAPIClient.swift`, `MosaicAPIError.swift` | T0.2 |
| `Core/Networking/MosaicServices.swift`, `App/AppState.swift`, `App/AppShell.swift`, `App/MosaicVisualFixtures.swift` | T0.3 → T0.4 → T9.1 |
| `Features/MediaDetail/MediaDetailContainer.swift` | T0.4 (slots) → T1.5 |
| `Features/MediaDetail/SeriesExperienceViews.swift` | T0.4 (slots) only |
| `Features/Profile/SettingsView.swift` | T0.4 (rows) → T6.1 (sign-in method line) |
| `Features/Settings/YourDataView.swift` (new hub) | T0.4 only |
| `Features/Settings/ExportDataView.swift` | T6.2 |
| `Features/Settings/Import*.swift`, `Core/Models/ImportModels.swift` | T6.3 → T6.4 |
| `Features/Profile/ProfileView.swift` | T4.4 → T4.2 |
| `Features/Profile/ActivityView.swift` | T4.1 |
| `Features/QuickLog/*` | T2.1 (T2.2 adds a new file in that folder only) |
| `Features/Lists/ListsView.swift` | T3.1 (T3.2 adds new files only) |

---

## 10. Codex delegation strategy

- **Mechanism:** the `codex:codex-rescue` subagent, one task per invocation,
  using the brief format in `CLAUDE.md` (Goal, Allowed Files, Context &
  Constraints, Acceptance Criteria) plus the exact contract excerpts from the
  web repo (schemas, response shapes, copy). Codex CLI is installed
  (`~/.nvm/.../bin/codex`); readiness will be confirmed with `/codex:setup`
  before the first delegation. If the plugin cannot run a task, I report it —
  I will not substitute another mechanism or write the code myself.
- **Isolation:** each parallel task runs in `.worktrees/<task-id>` on
  `parity/<task-id>`, branched from `parity/integration`; separate
  `-derivedDataPath` per worktree.
- **Brief rules:** list allowed files exhaustively; forbid edits elsewhere;
  name the placeholder the task replaces; require tests in a new
  `Mosaic-iOSTests/<Area>Tests.swift`; require fixtures in the task's own
  `*Fixtures.swift`; require matching web copy where the web has copy.
- **Review loop (per task):** `git status` / `git diff` against the allowed
  file list → architecture and contract review → `build-for-testing` →
  `scripts/test.sh` → fixture screenshots (393 pt + AX3) for UI tasks → send
  failures back to Codex with exact logs → mark Completed only after all pass.
- **Merging:** verified branches merge into `parity/integration` one at a
  time, re-running the full suite after each merge. Nothing is pushed and
  `main` is not touched without your explicit go-ahead.

## 11. Testing and quality assurance

| Layer | What | When |
| --- | --- | --- |
| Unit — wire shapes | Golden JSON for all 22 commands vs `validation.ts`; decoding of every new response shape (incl. legacy errors) | T0.1, T0.2, T0.4 |
| Unit — ported logic | Recap, `projectActivity`, reconciliation helpers, franchise mirror, episode rating categories — fixtures copied from `Tracking App/tests/*` | Each porting task |
| Unit — stores | `PersonalStateStore` applies mutation responses; failure keeps last good state | T0.3 |
| Visual | Fixture screens for every new screen: loaded, empty, error, AX3 Dynamic Type | Each UI task |
| Integration (manual, live) | Extended device QA matrix (V1 rows + reviews, lists CRUD, watch edit/delete, import/export, email auth) on a dedicated test account | M9 |
| Backend | `npm run lint`, `npm run typecheck`, `npm test` in Tracking App | TB1, TB2 |
| Regression | Full iOS suite after every merge; V1 mutation matrix at M9 | Continuous |

Not available today: UI test target, linter. Adding XCUITest is optional
(D6); the plan does not depend on it.

## 12. Risks and open questions

**Prerequisites (your action):**
- **P1** iOS 27 simulator runtime — installed.
- **P2** Codex plugin — ready.
- **P3** Commits and pushes — approved; commits carry no AI co-author lines.
- **P4** Backend changes B1, B2 and production deploy — approved.

**Decisions:**
Decided 2026-11-14:

- **D1 Your Mosaic:** true 3D (RealityKit) chronological vortex, as on the web.
- **D2 Mosaic AI on iOS:** build it (M8).
- **D3 People search / public profiles:** deferred.
- **D4 Profile Stats source:** server endpoint B2 (approved).
- **D5 Release target:** internal TestFlight only.
- **D6 UI tests:** not added (open).

**Risks:** live data in the simulator session (use fixtures and a dedicated
test account for writes); heavy `/api/me/state` for large accounts; parity
drift if the web keeps changing during implementation (re-check `git log` in
Tracking App before each wave).

## 13. Progress tracker

See [`TRACKER.md`](TRACKER.md). It is updated after every delegation,
review and merge.
