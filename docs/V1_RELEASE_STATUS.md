# Mosaic iOS — V1 release status

**Definition of done:** a TestFlight build for the **internal** group, iPhone
only, portrait only, using the existing bundle ID
`com.shanmukhpgsspersonalteam.MosaiciOS`. External TestFlight, iPad, visionOS,
Mac and CI are V1.1.

Last updated: 2026-11-10.

## Status

| Item | State | Notes |
| --- | --- | --- |
| iOS feature scope | Done | Home, Discover, Library, Detail, Series/Seasons, Quick Log, Search, Lists (read-only), Profile, Activity, Settings, Edit Profile, Watch region. |
| Web API contract | Code done, **not deployed** | `PATCH /api/me/profile`, `progressId`, `watchCount`, `progress.platform`. Local web typecheck clean and 286/286 tests pass. The deployed server must include these before the iOS build is useful. |
| iOS build | Passing | `xcodebuild … -destination 'generic/platform=iOS' build` → BUILD SUCCEEDED. |
| iOS tests compile | Passing | `build-for-testing` → TEST BUILD SUCCEEDED. |
| iOS tests run | **Not run** | No simulator runtime is installed on this machine. Install one (Xcode → Settings → Components) and run `scripts/test.sh`. |
| Device QA | **Not run** | See the mutation matrix below. |
| Privacy manifest | Done | `Mosaic-iOS/PrivacyInfo.xcprivacy`: no tracking, UserDefaults `CA92.1`, Email/Name/User ID/Other User Content for app functionality. |
| Export compliance | Done | `ITSAppUsesNonExemptEncryption = false` (only system TLS). |
| Device family / orientation | Done | `TARGETED_DEVICE_FAMILY = 1`; `UISupportedInterfaceOrientations` = portrait only. |
| App Store Connect record | **Missing** | Required for TestFlight upload. |
| Archive / upload | **Not done** | `scripts/archive.sh`, then Xcode Organizer → Distribute App. |

## Blocking steps, in order

1. **Deploy the web changes** (`~/Documents/Tracking App`, branch `main`) so
   `PATCH /api/me/profile` and the new library fields are live.
2. **Install a simulator runtime** and run `scripts/test.sh`; fix any failure.
3. **Run the device QA matrix** below on a real iPhone against the deployed
   API, using a dedicated test account.
4. **Create the App Store Connect record** for
   `com.shanmukhpgsspersonalteam.MosaiciOS` with a paid Apple Developer team.
5. **Archive and upload:** `scripts/archive.sh`, then Organizer → Distribute App
   → App Store Connect → Upload; add the build to the internal TestFlight group.
6. **Fill App Privacy** in App Store Connect to match the privacy manifest
   (data linked to the user, not used for tracking).

## Device QA: mutation matrix

Run signed in on the TestFlight candidate. Every row must both succeed in the UI
and survive a cold launch.

| Flow | Expected |
| --- | --- |
| Log a movie / log a rewatch | One library entry; watch count increments once per save. |
| Log an episode / unwatch | Episode tick and watched count change exactly once. |
| Change a season state | Season state persists; Continue updates. |
| Update a game twice | Same playthrough updated; no duplicate record. |
| Update a book twice | Same reading updated; no duplicate record. |
| Change status | New status persists; Library filter counts update. |
| Set / clear rating | `null` clears; values round-trip in 0.5 steps. |
| Toggle favourite | Persists; does not change status. |
| Remove from Library | Entry disappears; history remains on the web. |
| Save for later | Adds watchlist/backlog/want-to-read without overwriting tracked titles. |
| Change watch region | Discover reloads for the region; cold launch keeps it. |
| Edit profile | Name, username, bio and avatar persist and appear on Profile. |
| Duplicate username | Inline conflict message; nothing else changes. |
| Sign out / sign in | Session clears, Google sign-in returns to the shell. |
| Cold launch signed in | Session restores; `/api/me` loads. |
| Offline launch | Recoverable error, no crash, retry works. |

Also run `docs/ios-emergency-layout-search-qa.md` end to end.

## Deferred to V1.1

- List/review create, edit, delete, reorder and sharing.
- Movie edit/delete beyond logging.
- Richer stats.
- iPad, visionOS and Mac (device family is locked to iPhone for V1).
- External TestFlight and public App Store release.
- CI.
- SVG rendering for avatar presets (gradient fallback is shipped).
