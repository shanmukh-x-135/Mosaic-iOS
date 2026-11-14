# Mosaic iOS parity — implementation tracker

Statuses: Planned · Ready for delegation · Delegated · In progress ·
Implemented · Testing · Review required · Completed · Blocked.
Agent: `codex:codex-rescue` unless noted. Updated after every delegation,
review and merge.

Last updated: 2026-11-15 — M2 complete and merged to main; M3 awaiting approval.

## Prerequisites and decisions

| ID | Item | Owner | Status |
| --- | --- | --- | --- |
| P1 | iOS 27 simulator runtime (`iPhone 17` created) | You | Completed |
| P2 | Codex plugin ready | You | Completed |
| P3 | Commits and pushes (no AI co-author lines) | You | Completed (approved) |
| P4 | Backend changes B1, B2 and production deploy | You | Completed (approved) |
| D1 | Your Mosaic: true 3D (RealityKit) | You | Completed |
| D2 | Mosaic AI on iOS: build (M8) | You | Completed |
| D3 | People search / public profiles: deferred | You | Completed |
| D4 | Stats via server endpoint B2 | You | Completed |
| D5 | Release target: internal TestFlight only | You | Completed |
| D6 | Add XCUITest smoke target | You | Planned |

## Tasks

| Task ID | Description | Assigned agent | Dependencies | Status | Test results | Review |
| --- | --- | --- | --- | --- | --- | --- |
| T0.1 | Complete command model | Codex | P1 | Completed | 88/88 on integration (28 new) | Reviewed; merged `7fa45c2` |
| T0.2 | Networking hardening, upload/download/NDJSON | Codex | P1 | Completed | 102/102 (14 new) | Two review rounds (400 mapping, timeouts; simulator file protection); merged `3ee5f33` |
| T0.3 | PersonalStateStore | Codex | T0.1, T0.2 | Completed | 110/110 (8 new) | Reviewed; merged `2b16637` |
| T0.4 | Contract-first scaffolding (T0.4a models/services, T0.4b routes/placeholders) | Codex | T0.3 | Completed | 123/123 (13 new) | Reviewed; screenshots unchanged (movie, series, settings); merged |
| T1.1 | Related titles section | Codex | T0.4 | Completed | 152/152 on integration | Reviewed; merged in M1 |
| T1.2 | Where to watch | Codex | T0.4 | Completed | 152/152 on integration | Reviewed; merged in M1 |
| T1.3 | Episode ratings heatmap | Codex | T0.4 | Completed | 152/152 on integration | Reviewed; merged in M1 |
| T1.4 | Franchise screen/link, About & credits | Codex | T0.4 | Completed | 152/152 on integration | Reviewed; merged in M1 |
| T1.5 | Brand marks, platforms, credits on detail | Codex | T0.4 | Completed | 152/152 on integration | Reviewed; merged in M1 |
| T2.1 | Logging completeness (viewing context, favourite, recents) | Codex | T0.4 | Completed | 176/176 on integration | Reviewed (1 round: movie logging must not block on Library); merged in M2 |
| T2.2 | Movie watch history + editor | Codex | T0.4 | Completed | 176/176 on integration | Reviewed; merged in M2 |
| T2.3 | Reviews | Codex | T0.4 | Completed | 176/176 on integration | Reviewed; merged in M2 |
| T3.1 | List creation and editor | Codex | T0.4 | Ready for delegation | — | — |
| T3.2 | Add to list from detail | Codex | T0.4 | Ready for delegation | — | — |
| T4.1 | Full activity, filters, movie diary | Codex | T2.2 | Planned | — | — |
| T4.2 | Profile structure | Codex | T4.4 | Planned | — | — |
| T4.3 | Stats screen | Codex | T0.4, TB2 deployed | Ready for delegation | — | — |
| T4.4 | Avatar preset assets | Codex | T0.4 | Ready for delegation | — | — |
| T5.1 | Your Mosaic | Codex | T0.4, D1 | Ready for delegation | — | — |
| T5.2 | Recap | Codex | T0.4 | Ready for delegation | — | — |
| T6.1 | Email sign-in and sign-up | Codex | T0.4 | Ready for delegation | — | — |
| TB1 | [web] Bearer auth for imports/export | Codex | P4 | Completed | lint, typecheck clean; 313/313 | `f8105c5` on web `main`; deployed, invalid Bearer → 401 |
| TB2 | [web] Profile stats endpoint | Codex | P4, D4 | Completed | lint, typecheck, build clean; 330/330 | `9ccbee0` on web `main`; deployed, 401 envelope verified |
| T6.2 | Export | Codex | TB1 deployed | Ready for delegation | — | — |
| T6.3 | Import: upload, preview, apply | Codex | TB1 deployed | Ready for delegation | — | — |
| T6.4 | Import: reconciliation, history, undo | Codex | T6.3 | Planned | — | — |
| T7.1 | People search + public profile | — | D3, B4 | Deferred | — | — |
| T8.1 | Ask Mosaic | Codex | T0.2, T0.4 | Ready for delegation | — | — |
| T9.1 | Integration, accessibility, docs | Codex + Claude review | all above | Planned | — | — |

## Log

| Date | Event |
| --- | --- |
| 2026-11-14 | Reconnaissance of both repos; baseline `build-for-testing` succeeded (60 tests compile, not run: no simulator runtime). Plan, task cards and tracker written. |
| 2026-11-14 | Plan approved. Decisions D1 3D, D2 build AI, D3 defer, D4 B2, D5 TestFlight. `iPhone 17` simulator created. |
| 2026-11-14 | Baseline suite run: 59/60; fixed a wrong username assertion (`8e2b716`). T0.1 merged (88/88). TB1 committed. Server has 20 commands, not 22 (docs corrected). |
| 2026-11-14 | T0.2 merged (102/102). Web `main` → `9ccbee0` pushed; Vercel production deploy succeeded via Git integration (Vercel CLI token is expired). `docs/mobile-api.md` synced. T0.3 delegated. |
| 2026-11-14 | T0.3 merged (110/110). T0.4 split into T0.4a (models, services) and T0.4b (routes, placeholders, slots); T0.4a delegated. |
| 2026-11-14 | T0.4a and T0.4b merged; M0 complete (123/123; fixture screenshots unchanged). Wave D tasks ready. |
| 2026-11-14 | M0 merged into `main` (`4fa1867`). M1 approved; T1.1–T1.4 delegated in parallel. Policy: one milestone at a time with approval; merge integration → main at each milestone end. |
| 2026-11-14 | M1 complete: related titles, where to watch, episode ratings heatmap, franchise + credits, brand marks/game credits. 152/152. Merged to `main`. Follow-up: `CatalogMedia` lacks `developerLogoUrl`/`publisherLogoUrl` (names shown, no logos) — add in M9. Fixture catalog lacks franchise titles (loaded state verified by unit tests only). |
| 2026-11-14 | M2 approved; T2.1, T2.2, T2.3 delegated in parallel. |
| 2026-11-15 | M2 complete: viewing context, favourite on log, Quick Log recents, movie watch history with edit/delete, reviews. 176/176. Merged to `main`. Polish for M9: personal panel buttons wrap to three rows with the Review button; Review button stays disabled if the state load fails (no retry until relaunch). |
