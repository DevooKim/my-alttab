import CoreGraphics
import Foundation

/// EXPERIMENTAL: jumps to another Space without the slide animation by
/// synthesizing a fast Dock-swipe gesture, the SIP-free technique yabai uses
/// as its fallback (`space_manager_focus_space_using_gesture`).
///
/// macOS has no public or clean-private API to switch Spaces without the
/// animation from an ordinary app process. This posts a CGEvent carrying the
/// undocumented Dock-swipe gesture fields at very high velocity, which makes
/// macOS snap to the adjacent Space instead of sliding. The field numbers and
/// the velocity magnitude (±9999) are load-bearing magic constants; they can
/// change across macOS versions, so every caller must treat this as
/// best-effort and fall back to the normal animated activation.
enum SpaceSwitcher {
    // Undocumented CGEvent field numbers for a Dock-swipe gesture (from yabai
    // src/space_manager.c). The CGEvent functions themselves are public.
    private static let fieldEventType = CGEventField(rawValue: 55)!     // = 30 (gesture)
    private static let fieldSubtype = CGEventField(rawValue: 110)!      // = 23 (dock swipe)
    private static let fieldGestureFlag = CGEventField(rawValue: 123)!  // = 1
    private static let fieldDirection = CGEventField(rawValue: 124)!    // ±1.0
    private static let fieldVelocity = CGEventField(rawValue: 129)!     // ±9999.0 (skips animation)
    private static let fieldPhase = CGEventField(rawValue: 132)!        // 1=begin, 4=end

    /// Attempt to switch to the Space containing `windowID` without animation.
    /// Returns true only if a switch was posted (or none was needed because the
    /// window is already on the current Space); false means the caller should
    /// fall back to the normal animated activation.
    @discardableResult
    static func jumpToSpace(ofWindowID windowID: CGWindowID) -> Bool {
        guard windowID != 0,
              let targetSpaceID = SpaceTracker.spaceID(forWindowID: windowID),
              let (displayID, currentSpaceID) = SpaceTracker.displayAndCurrentSpace(forSpaceID: targetSpaceID)
        else { return false }

        // Already on the target Space — nothing to do, no fallback needed.
        if currentSpaceID == targetSpaceID { return true }

        // A transition already in flight would make the swipe land wrong.
        if SpaceTracker.isAnimating(displayID: displayID) { return false }

        guard let curIndex = SpaceTracker.missionControlIndex(ofSpaceID: currentSpaceID),
              let newIndex = SpaceTracker.missionControlIndex(ofSpaceID: targetSpaceID)
        else { return false }

        let delta = newIndex - curIndex
        guard delta != 0 else { return true }
        let steps = abs(delta)
        let sign: Double = delta > 0 ? 1.0 : -1.0

        guard let event = CGEvent(source: nil) else { return false }
        event.setIntegerValueField(fieldEventType, value: 30)
        event.setIntegerValueField(fieldSubtype, value: 23)
        event.setIntegerValueField(fieldGestureFlag, value: 1)
        event.setDoubleValueField(fieldDirection, value: sign)
        event.setDoubleValueField(fieldVelocity, value: sign * 9999.0)

        // No delays between posts: the snap (vs. slide) comes from the high
        // velocity, and delays reintroduce the animation. One begin/end pair
        // per Space to traverse.
        for _ in 0..<steps {
            event.setIntegerValueField(fieldPhase, value: 1) // began
            event.post(tap: .cgSessionEventTap)
            event.setIntegerValueField(fieldPhase, value: 4) // ended
            event.post(tap: .cgSessionEventTap)
        }
        return true
    }
}
