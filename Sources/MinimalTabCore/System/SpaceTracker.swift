import AppKit
import ApplicationServices

/// Maps windows to their Space (virtual desktop) number, unifying windows
/// across all Spaces into one list.
///
/// This relies on private CoreGraphics Services (CGS) symbols — there is no
/// public API for window↔Space association. They read only Space topology
/// and window IDs (no window contents), so no Screen Recording permission
/// is needed. Isolated here so the rest of the app stays on public APIs.
enum SpaceTracker {
    // MARK: Private CGS bridges

    private typealias CGSConnectionID = UInt32

    private static let connection: CGSConnectionID = _CGSDefaultConnection()

    /// 1-based ordinal for each CGS Space id, numbered across displays in
    /// the order Mission Control lays them out. Rebuilt per enumeration so
    /// it reflects Spaces added/removed since last time.
    static func currentSpaceOrdinals() -> [Int: Int] {
        guard let displays = CGSCopyManagedDisplaySpaces(connection) as? [[String: Any]] else {
            return [:]
        }
        var ordinals: [Int: Int] = [:]
        var n = 0
        for display in displays {
            guard let spaces = display["Spaces"] as? [[String: Any]] else { continue }
            for space in spaces {
                n += 1
                if let id = space["ManagedSpaceID"] as? Int { ordinals[id] = n }
                if let id = space["id64"] as? Int { ordinals[id] = n }
            }
        }
        return ordinals
    }

    /// The Space ordinal a given AX window lives on, or nil if it can't be
    /// resolved (window has no CGWindowID, or isn't on any user Space).
    static func spaceNumber(for axWindow: AXUIElement, ordinals: [Int: Int]) -> Int? {
        guard let wid = windowID(for: axWindow) else { return nil }
        return spaceNumber(forWindowID: wid, ordinals: ordinals)
    }

    /// CGWindowID backing an AX window element, or nil if unavailable.
    static func windowID(for axWindow: AXUIElement) -> CGWindowID? {
        var wid: CGWindowID = 0
        guard _AXUIElementGetWindow(axWindow, &wid) == .success, wid != 0 else { return nil }
        return wid
    }

    /// windowID → Space ordinal for every window across all Spaces, built
    /// with one `CGSCopyWindowsWithOptionsAndTags` per Space (bounded by the
    /// Space count) instead of one `CGSCopySpacesForWindows` per window.
    /// `CGSCopySpacesForWindows` does not preserve a per-window mapping when
    /// passed multiple IDs (it returns the union of containing Spaces), so it
    /// can't be batched directly — this inverts the lookup instead.
    static func spaceNumbersByWindowID(ordinals: [Int: Int]) -> [CGWindowID: Int] {
        // allSpaceWindowIDs already dedupes a multi-Space window to its
        // first-seen entry, and Spaces are walked in ascending ordinal order,
        // so the first ordinal seen is the lowest — matching the per-window
        // path's `.min()`.
        var map: [CGWindowID: Int] = [:]
        for (wid, ordinal) in allSpaceWindowIDs(ordinals: ordinals) where map[wid] == nil {
            map[wid] = ordinal
        }
        return map
    }

    // MARK: Animation-free Space switching helpers (experimental)

    /// The CGS Space id (id64) a window currently lives on, or nil. Used to
    /// decide whether activating it requires a Space switch and to which one.
    static func spaceID(forWindowID wid: CGWindowID) -> Int? {
        guard let spaceIDs = CGSCopySpacesForWindows(
            connection, kCGSAllSpacesMask, [Int(wid)] as CFArray
        ) as? [Int] else { return nil }
        return spaceIDs.first
    }

    /// 1-based Mission Control index (global walk: displays in order, then
    /// spaces in order) of a CGS Space id, or nil if not found. For two
    /// spaces on the SAME display the difference of their indices equals the
    /// within-display step count (a display's spaces are contiguous in the
    /// walk), which is what the Dock-swipe gesture needs.
    static func missionControlIndex(ofSpaceID sid: Int) -> Int? {
        guard let displays = CGSCopyManagedDisplaySpaces(connection) as? [[String: Any]] else {
            return nil
        }
        var n = 0
        for display in displays {
            guard let spaces = display["Spaces"] as? [[String: Any]] else { continue }
            for space in spaces {
                n += 1
                let id = (space["id64"] as? Int) ?? (space["ManagedSpaceID"] as? Int)
                if id == sid { return n }
            }
        }
        return nil
    }

    /// The display-identifier CFString and current Space id64 for the display
    /// that owns the given Space id. Returns nil if the space isn't found.
    static func displayAndCurrentSpace(forSpaceID sid: Int) -> (displayID: String, currentSpaceID: Int)? {
        guard let displays = CGSCopyManagedDisplaySpaces(connection) as? [[String: Any]] else {
            return nil
        }
        for display in displays {
            guard let spaces = display["Spaces"] as? [[String: Any]],
                  let displayID = display["Display Identifier"] as? String else { continue }
            let contains = spaces.contains { space in
                let id = (space["id64"] as? Int) ?? (space["ManagedSpaceID"] as? Int)
                return id == sid
            }
            if contains {
                let current = display["Current Space"] as? [String: Any]
                let currentID = (current?["id64"] as? Int) ?? (current?["ManagedSpaceID"] as? Int) ?? -1
                return (displayID, currentID)
            }
        }
        return nil
    }

    /// True if a Space transition is already animating on the given display —
    /// posting a swipe during one causes wrong landings, so callers abort.
    static func isAnimating(displayID: String) -> Bool {
        SLSManagedDisplayIsAnimating(connection, displayID as CFString)
    }

    static func spaceNumber(forWindowID wid: CGWindowID, ordinals: [Int: Int]) -> Int? {
        guard let spaceIDs = CGSCopySpacesForWindows(
            connection,
            kCGSAllSpacesMask,
            [Int(wid)] as CFArray
        ) as? [Int] else {
            return nil
        }
        // A window may report several Spaces (e.g. pinned to all); take the
        // lowest ordinal for a stable badge.
        return spaceIDs.compactMap { ordinals[$0] }.min()
    }

    /// CGWindowIDs of standard windows on every Space, paired with their
    /// Space ordinal. Used (only when "show all Spaces" is on) to find
    /// windows AX omits because they live on inactive Spaces.
    static func allSpaceWindowIDs(ordinals: [Int: Int]) -> [(id: CGWindowID, space: Int)] {
        guard let displays = CGSCopyManagedDisplaySpaces(connection) as? [[String: Any]] else {
            return []
        }
        var result: [(CGWindowID, Int)] = []
        var seen = Set<CGWindowID>()
        for display in displays {
            guard let spaces = display["Spaces"] as? [[String: Any]] else { continue }
            for space in spaces {
                let sid = (space["ManagedSpaceID"] as? Int) ?? (space["id64"] as? Int) ?? -1
                guard let ordinal = ordinals[sid] else { continue }
                var setTags: UInt64 = 0
                var clearTags: UInt64 = 0
                // owner 0, options 2 = all windows assigned to the space.
                guard let ids = CGSCopyWindowsWithOptionsAndTags(
                    connection, 0, [sid] as CFArray, 2, &setTags, &clearTags
                ) as? [Int] else { continue }
                for raw in ids {
                    let wid = CGWindowID(raw)
                    if seen.insert(wid).inserted {
                        result.append((wid, ordinal))
                    }
                }
            }
        }
        return result
    }
}

// CGSSpaceMask bit covering user + system Spaces; 7 in practice.
private let kCGSAllSpacesMask = 7

@_silgen_name("_CGSDefaultConnection")
private func _CGSDefaultConnection() -> UInt32

@_silgen_name("CGSCopyManagedDisplaySpaces")
private func CGSCopyManagedDisplaySpaces(_ cid: UInt32) -> CFArray?

@_silgen_name("CGSCopySpacesForWindows")
private func CGSCopySpacesForWindows(_ cid: UInt32, _ mask: Int, _ windowIDs: CFArray) -> CFArray?

@_silgen_name("CGSCopyWindowsWithOptionsAndTags")
private func CGSCopyWindowsWithOptionsAndTags(_ cid: UInt32, _ owner: Int, _ spaces: CFArray, _ options: Int, _ setTags: UnsafeMutablePointer<UInt64>, _ clearTags: UnsafeMutablePointer<UInt64>) -> CFArray?

@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ wid: UnsafeMutablePointer<CGWindowID>) -> AXError

@_silgen_name("CGSManagedDisplayIsAnimating")
private func SLSManagedDisplayIsAnimating(_ cid: UInt32, _ display: CFString) -> Bool
