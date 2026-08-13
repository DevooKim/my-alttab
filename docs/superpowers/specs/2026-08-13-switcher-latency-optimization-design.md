# Switcher Latency Optimization Design

## Context

My AltTab already enumerates windows in a detached task, but the trigger path
still refreshes the frontmost window synchronously on the main actor before
that task starts. `MRUTracker.focusedWindowID(of:)` performs Accessibility IPC
with a 250 ms timeout. A live `sample` capture of version 0.7.7 caught the main
thread inside that AX request from `SwitcherController.begin`, while an idle
capture showed 0% CPU and a roughly 29 MB physical footprint. The optimization
therefore targets switcher-open latency rather than background resource use.

The same open path also performs three avoidable kinds of repeated work:

- An MRU snapshot searches an array for every window rank lookup.
- With all-Spaces mode enabled, Space membership is collected once for active
  AX windows and then collected again for inactive windows.
- App icon and hidden-state properties are read once per window even though
  they are constant for all windows belonging to the same app.

## Goals

- Never perform the trigger-time focused-window AX lookup on the main actor.
- Preserve the freshly launched app fix: the actual frontmost window must be
  promoted in MRU ordering before enumeration is sorted.
- Preserve pending trigger, reverse, commit, and cancellation behavior while
  loading.
- Make MRU snapshot rank lookup constant time.
- Reuse the existing Space-membership map in all-Spaces enumeration.
- Read app-level presentation state once per enumerated app.

## Non-goals

- Do not cache the complete window list between switcher invocations; stale
  windows would require a separate invalidation design.
- Do not remove the trigger-time focused-window refresh; doing so would
  reintroduce incorrect ordering for newly launched apps.
- Do not change UI appearance, shortcuts, Space behavior, permissions, bundle
  identity, signing, or release metadata.

## Design

### Asynchronous load preparation

`SwitcherController.begin` captures the frontmost PID and other main-actor
state, marks the controller as loading, and starts the detached load before any
AX request. The detached task resolves the focused window. It then briefly
hops to the main actor to apply the existing activation-source MRU guard and
take a rank snapshot. Only after that snapshot is produced does detached
window enumeration continue.

The main-actor hop checks the load token and loading state. A cancellation that
arrives during the AX request therefore prevents both MRU mutation and the more
expensive enumeration. The final completion retains the existing token check
to discard results cancelled later in the load.

`MRUTracker.focusedWindowID(of:)` becomes `nonisolated` because it reads no
tracker state. Its blocking AX IPC is called only from the detached load and
from the existing activation retry, whose behavior remains unchanged.

### Constant-time MRU snapshot

Introduce an immutable `MRURankSnapshot` value that builds a
`[CGWindowID: Int]` dictionary from the ordered ID list. Its `rank(of:)` method
returns `nil` for zero and otherwise performs one dictionary lookup.
`MRUTracker.rankSnapshot()` returns this value, and the enumerator closure uses
it without touching main-actor state.

The value type creates a testable boundary for ordering and snapshot
immutability while keeping the tracker actor-isolated.

### Enumeration reuse

`WindowEnumerator.allWindows` already computes `spaceByWindowID`. Pass that map
to `inactiveSpaceWindows` instead of rebuilding it via
`SpaceTracker.allSpaceWindowIDs`. The map contains the same deduplicated,
lowest-ordinal membership used by both paths.

Inside `windowsOf`, capture `app.icon` and `app.isHidden` once after the AX
window list succeeds and reuse them for every `WindowInfo` from that app.

## Error and cancellation behavior

- A failed focused-window lookup yields no MRU touch and enumeration continues
  with the prior snapshot, matching current fallback behavior.
- If the load token is stale after the lookup, the task exits without
  enumeration or UI updates.
- AX timeouts and per-app enumeration failures remain bounded and isolated as
  they are today.
- All-Spaces metadata and Screen Recording permission boundaries remain
  unchanged; `kCGWindowName` is still read only in the opt-in inactive-Space
  path.

## Verification

- Add focused tests for `MRURankSnapshot`: ordered ranks, zero/unknown IDs, and
  immutability after the source array changes.
- Keep all existing ordering, session, preference, and localization tests
  green.
- Build the release app with `make app` to catch AppKit, SwiftUI, and signing
  integration errors.
- Run the automated trigger/cancel smoke flow and capture `sample` again. The
  main-thread call graph must no longer contain
  `MRUTracker.focusedWindowID(of:)`; the focused lookup must appear only on the
  detached user-initiated task when sampled.
- Run the relevant manual smoke-test items for opening, cycling, cancelling,
  reverse opening, and rapid modifier release.
