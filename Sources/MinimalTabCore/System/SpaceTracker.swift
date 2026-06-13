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
