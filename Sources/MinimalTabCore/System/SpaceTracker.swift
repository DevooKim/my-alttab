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
        var wid: CGWindowID = 0
        guard _AXUIElementGetWindow(axWindow, &wid) == .success, wid != 0 else { return nil }
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
}

// CGSSpaceMask bit covering user + system Spaces; 7 in practice.
private let kCGSAllSpacesMask = 7

@_silgen_name("_CGSDefaultConnection")
private func _CGSDefaultConnection() -> UInt32

@_silgen_name("CGSCopyManagedDisplaySpaces")
private func CGSCopyManagedDisplaySpaces(_ cid: UInt32) -> CFArray?

@_silgen_name("CGSCopySpacesForWindows")
private func CGSCopySpacesForWindows(_ cid: UInt32, _ mask: Int, _ windowIDs: CFArray) -> CFArray?

@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ wid: UnsafeMutablePointer<CGWindowID>) -> AXError
