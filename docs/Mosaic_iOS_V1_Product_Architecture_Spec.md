# Mosaic iOS V1 — Product + Architecture Specification

## Product goal
Build a native iPhone client for Mosaic in SwiftUI, backed by the existing Mosaic backend and Supabase authentication. The iOS app is a new client, not a second backend.

## V1 scope
Auth, Home, Discover, Library, Search, Media Detail, Quick Log, Profile.

Defer: advanced Stats, full Lists management, Diary, Reviews management, Episode Ratings matrix, AI/Taste Engine, widgets, push notifications, App Intents, Live Activities, Share Sheet extension, social, and offline write queue.

## Platform
Use SwiftUI, Observation, async/await, URLSession, and Supabase Swift. Avoid heavyweight state/architecture frameworks in V1.

Keep the current deployment target. Use native Liquid Glass conditionally on iOS 26+ and a coherent material fallback on older supported versions.

## Design principle
Media artwork is the content layer; glass/material is the interaction layer.

Use glass for tab/navigation chrome, toolbars, floating actions, search, sheets, and important controls. Avoid wrapping every poster/card in glass.

Visual direction: dark, cinematic, editorial, premium, content-first.

## Navigation
Tabs:
- Home
- Discover
- Library
- Search
- Profile

Quick Log should be a prominent global action, not a permanent tab unless implementation constraints make that clearly better.

## App state
Use a small root app state for session state and selected tab. Keep feature-local state inside features.

Session states should cover launching, signed out, signed in, and recoverable error.

## Authentication
Use Supabase Swift. The iOS app gets a Supabase access token and calls Mosaic APIs using:

Authorization: Bearer <Supabase access token>

Do not trust client-supplied user IDs. Never ship service-role credentials.

## Networking
One reusable Mosaic API client should handle base URL, Bearer token injection, JSON coding, status handling, normalized Mosaic API errors, and cancellation.

Views should never construct raw URLRequests.

## Configuration
Production API base:
https://mosaic-eight-theta.vercel.app

Configuration should expose:
- Mosaic API base URL
- Supabase URL
- Supabase publishable/anon key

Use .xcconfig or equivalent. Never include service-role keys, DB passwords, or server-only provider secrets.

## API contract
The source of truth is:
Docs/mobile-api.md

Do not invent undocumented endpoints. If a capability is missing, treat it as a backend gap rather than duplicating business rules in Swift.

## Client models
Use normalized models such as MediaSummary, MediaDetail, ContinueItem, LibraryItem, ActivityItem, Profile, User, Progress, SearchResult, LoggingInput, and APIError.

Keep domain-specific data domain-specific.

## Source layout
Recommended:

Mosaic-iOS/
├── App/
├── Core/
│   ├── Auth/
│   ├── Networking/
│   ├── Models/
│   ├── Configuration/
│   └── DesignSystem/
├── Features/
│   ├── Auth/
│   ├── Home/
│   ├── Discover/
│   ├── Library/
│   ├── Search/
│   ├── QuickLog/
│   ├── MediaDetail/
│   └── Profile/
└── Resources/

Do not create empty folders/files just for ceremony.

## Design system
Create semantic color, spacing, radius, typography, and motion tokens. Prefer semantic names instead of scattered literals.

## Feature direction

### Home
Eventually: Continue Your Stories, recent activity, compact discovery surface.
Do not recompute tracking state/progress/next episode on-device.

### Discover
Editorial spotlight and discovery rails; avoid dashboard/filter-heavy design.

### Library
Browse Movies, Series, Games, Books, with progress driven by backend state.

### Search
Native search, debounced query, cross-media results, clear media-type identity.

### Media Detail
Domain-specific detail pages with shared visual structure but distinct actions/data per media type.

### Quick Log
One of the most important native interactions:
Log → media category → search/select → domain-specific form → save.

### Profile
Identity-first: avatar, display name, current media, recent activity, highlights.

## Loading/error states
Every network screen supports loading, loaded, empty, and recoverable error.

## Milestones
0. Foundation: structure, config, design tokens, Supabase auth, Mosaic API client, authenticated shell
1. Home + Continue
2. Search + Media Detail
3. Library
4. Quick Log
5. Profile
6. Discover
7. V1 polish / accessibility / Liquid Glass refinement / TestFlight readiness

## V1 success
A user can authenticate, see active media, search, open a detail page, browse library, log/update progress, and view profile on a real iPhone.

## Engineering rules
- server remains source of truth
- no backend business-rule duplication in Swift
- no service-role credentials
- views do not issue raw API requests
- authenticated requests use Supabase access tokens
- prefer native frameworks
- add third-party packages only when justified
- test frequently on the physical iPhone
- build in small vertical slices
