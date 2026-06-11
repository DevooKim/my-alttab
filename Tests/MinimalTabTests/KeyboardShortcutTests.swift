import Foundation
import CoreGraphics
import MinimalTabCore

func runKeyboardShortcutTests() {
    expectEqual(KeyboardShortcut.globalDefault.keyCode, 48, "global default is Tab")
    expectEqual(KeyboardShortcut.sameAppDefault.keyCode, 50, "same-app default is backtick")
    expectEqual(KeyboardShortcut.globalDefault.modifiers, CGEventFlags.maskAlternate.rawValue,
                "default modifier is Option")

    let s = KeyboardShortcut.globalDefault
    expect(s.matches(keyCode: 48, flags: .maskAlternate), "matches exact key and modifier")
    expect(!s.matches(keyCode: 49, flags: .maskAlternate), "does not match wrong key")
    expect(!s.matches(keyCode: 48, flags: []), "does not match missing modifier")

    // Option+Cmd+Tab must NOT trigger an Option+Tab shortcut.
    expect(!s.matches(keyCode: 48, flags: [.maskAlternate, .maskCommand]),
           "does not match extra relevant modifier")

    // Real CGEvents carry extra bits (non-coalesced, left/right device
    // distinction). Matching must mask those out. 0x20 = NX_DEVICELALTKEYMASK.
    let hardwareFlags = CGEventFlags(rawValue: CGEventFlags.maskAlternate.rawValue | 0x20)
    expect(s.matches(keyCode: 48, flags: hardwareFlags), "ignores irrelevant hardware flags")

    expect(s.modifiersStillHeld(flags: .maskAlternate), "modifiers held detected")
    expect(!s.modifiersStillHeld(flags: []), "release detected")
    expect(!s.modifiersStillHeld(flags: .maskShift), "different modifier is a release")

    // Codable round trip
    let custom = KeyboardShortcut(keyCode: 49, modifiers: CGEventFlags.maskControl.rawValue)
    if let data = try? JSONEncoder().encode(custom),
       let back = try? JSONDecoder().decode(KeyboardShortcut.self, from: data) {
        expectEqual(back, custom, "Codable round trip")
    } else {
        expect(false, "Codable round trip encode/decode failed")
    }

    expectEqual(KeyboardShortcut.globalDefault.displayString, "⌥⇥", "display string for Option+Tab")
    expectEqual(custom.displayString, "⌃Space", "display string for Control+Space")

    // Reverse direction: trigger + Shift on top of the required modifiers
    expect(s.matchesWithShift(keyCode: 48, flags: [.maskAlternate, .maskShift]),
           "shift+trigger matches reverse")
    expect(!s.matchesWithShift(keyCode: 48, flags: .maskAlternate),
           "plain trigger is not reverse")
    expect(!s.matchesWithShift(keyCode: 48, flags: [.maskAlternate, .maskShift, .maskCommand]),
           "extra modifier breaks reverse match")
    expect(!s.matchesWithShift(keyCode: 49, flags: [.maskAlternate, .maskShift]),
           "wrong key is not reverse")

    // Modifier keys as standalone keys (e.g. Shift as the reverse key):
    // keyDown never fires for them, so they are identified by keycode on
    // flagsChanged via this mapping.
    expectEqual(KeyboardShortcut.modifierFlag(for: 56), CGEventFlags.maskShift,
                "left shift maps to shift flag")
    expectEqual(KeyboardShortcut.modifierFlag(for: 60), CGEventFlags.maskShift,
                "right shift maps to shift flag")
    expectEqual(KeyboardShortcut.modifierFlag(for: 59), CGEventFlags.maskControl,
                "left control maps to control flag")
    expect(KeyboardShortcut.modifierFlag(for: 48) == nil, "Tab is not a modifier")
    expectEqual(KeyboardShortcut.keyName(for: 56), "⇧", "left shift display name")

    // Live modifier preview while recording one key at a time
    expectEqual(KeyboardShortcut.modifierSymbols(CGEventFlags.maskAlternate.rawValue), "⌥",
                "modifier symbols for Option alone")
    expectEqual(
        KeyboardShortcut.modifierSymbols(CGEventFlags.maskAlternate.rawValue | CGEventFlags.maskCommand.rawValue),
        "⌥⌘", "modifier symbols for Option+Command")
    expectEqual(KeyboardShortcut.modifierSymbols(0), "", "no modifiers yields empty string")
}
