import CoreGraphics

/// A user-configurable shortcut: one trigger key + required modifier mask.
/// Stored in UserDefaults as JSON via `Preferences`.
public struct KeyboardShortcut: Codable, Equatable {
    public var keyCode: UInt16
    /// Raw CGEventFlags, already restricted to `relevantModifierMask` bits.
    public var modifiers: UInt64

    public init(keyCode: UInt16, modifiers: UInt64) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// The modifier bits we compare; everything else on a real CGEvent
    /// (non-coalesced flag, left/right device bits, caps lock) is ignored.
    public static let relevantModifierMask: UInt64 =
        CGEventFlags.maskCommand.rawValue
        | CGEventFlags.maskAlternate.rawValue
        | CGEventFlags.maskControl.rawValue
        | CGEventFlags.maskShift.rawValue

    public static let globalDefault = KeyboardShortcut(
        keyCode: 48, // kVK_Tab
        modifiers: CGEventFlags.maskAlternate.rawValue
    )
    public static let sameAppDefault = KeyboardShortcut(
        keyCode: 50, // kVK_ANSI_Grave (`)
        modifiers: CGEventFlags.maskAlternate.rawValue
    )

    /// True when a keyDown event is exactly this shortcut (no extra
    /// relevant modifiers allowed).
    public func matches(keyCode: Int64, flags: CGEventFlags) -> Bool {
        guard keyCode == Int64(self.keyCode) else { return false }
        return (flags.rawValue & Self.relevantModifierMask) == modifiers
    }

    /// True while every required modifier is still pressed — used on
    /// flagsChanged events to detect release-to-commit.
    public func modifiersStillHeld(flags: CGEventFlags) -> Bool {
        (flags.rawValue & modifiers) == modifiers && modifiers != 0
    }

    public var displayString: String {
        Self.modifierSymbols(modifiers) + Self.keyName(for: keyCode)
    }

    /// Symbols for a raw modifier mask, in standard macOS order — used for
    /// live feedback while recording a shortcut one key at a time.
    public static func modifierSymbols(_ modifiers: UInt64) -> String {
        var s = ""
        if modifiers & CGEventFlags.maskControl.rawValue != 0 { s += "⌃" }
        if modifiers & CGEventFlags.maskAlternate.rawValue != 0 { s += "⌥" }
        if modifiers & CGEventFlags.maskShift.rawValue != 0 { s += "⇧" }
        if modifiers & CGEventFlags.maskCommand.rawValue != 0 { s += "⌘" }
        return s
    }

    public static func keyName(for keyCode: UInt16) -> String {
        let names: [UInt16: String] = [
            48: "⇥", 50: "`", 49: "Space", 36: "↩", 53: "⎋", 51: "⌫",
            0: "A", 11: "B", 8: "C", 2: "D", 14: "E", 3: "F", 5: "G",
            4: "H", 34: "I", 38: "J", 40: "K", 37: "L", 46: "M", 45: "N",
            31: "O", 35: "P", 12: "Q", 15: "R", 1: "S", 17: "T", 32: "U",
            9: "V", 13: "W", 7: "X", 16: "Y", 6: "Z",
            18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6",
            26: "7", 28: "8", 25: "9", 29: "0",
            123: "←", 124: "→", 125: "↓", 126: "↑",
        ]
        return names[keyCode] ?? "key\(keyCode)"
    }
}
