# Mosaic iOS emergency layout and Search QA

Run this checklist on a signed-in iPhone after installing a Debug build. Do not use
iPhone Mirroring. The app must be tested with normal Dynamic Type and portrait
orientation on both a normal-width iPhone and a larger iPhone when available.

## Layout

- [ ] Home: `Your stories`, hero title, hero metadata, and action are fully visible.
- [ ] Home: `Continue your stories` begins at the normal left margin. Cards may
      scroll horizontally, but the screen itself must not.
- [ ] Home: the discovery rail begins at the normal left margin and has no
      left/right clipping outside its own horizontal scroll view.
- [ ] Discover: `Discover` and `Find your next obsession` have normal leading
      margins. Every filter chip is reachable by horizontal scrolling.
- [ ] Discover: spotlight copy stays inside its artwork card; poster rails are
      the only horizontally scrolling content.
- [ ] Library: all media-type filters, including `Books`, are reachable. The
      final collection card can be scrolled fully above the tab bar.
- [ ] Profile: no generated `@user_…` handle is shown. The final activity row
      and Sign Out control can be scrolled fully above the tab bar.
- [ ] Movie, series, game, and book details have no horizontal overflow. A
      pushed detail screen hides the tab bar.

## Search

For `Dune`, repeat the following for All, Movies, Series, Games, and Books:

- [ ] Search leaves the loading skeleton with results, empty state, or a
      recoverable error.
- [ ] Changing the filter never leaves an old spinner on screen.
- [ ] Turn off connectivity once: Search shows a recoverable error and Retry
      works after connectivity returns.
- [ ] Simulate or wait for a slow request: after 12 seconds Search shows
      `Search is taking too long` and Retry.

## DEBUG timing capture

Connect the device and select it in macOS Console while running the query above.
Filter for subsystem `com.shanmukhpgsspersonalteam.MosaiciOS`. For a simulator,
use:

```sh
xcrun simctl spawn booted log stream --style compact --predicate 'subsystem == "com.shanmukhpgsspersonalteam.MosaiciOS"'
```

Record these messages for every filter:

1. `Search state loading`
2. `Public request starting`
3. `Public response received`
4. `Public response decoded`
5. `Search state updated` (or `Search state error`)

The elapsed time reported by `Public catalog request completed` is the total
client request duration. Attach the log excerpt to the recovery report.
