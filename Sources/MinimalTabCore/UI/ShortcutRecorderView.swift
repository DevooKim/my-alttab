import SwiftUI
import AppKit

/// Click-to-record shortcut field. Captures the combination one key at a
/// time: held modifiers show live (e.g. "⌥…"), and the first non-modifier
/// key pressed while a modifier is held finalizes the shortcut.
public struct ShortcutRecorderView: View {
    let label: String
    @Binding var shortcut: KeyboardShortcut
    @State private var isRecording = false
    @State private var liveModifiers: UInt64 = 0
    @State private var monitor: Any?

    public init(label: String, shortcut: Binding<KeyboardShortcut>) {
        self.label = label
        self._shortcut = shortcut
    }

    public var body: some View {
        HStack {
            Text(label)
            Spacer()
            Button(action: toggleRecording) {
                Text(buttonTitle)
                    .frame(minWidth: 110)
            }
        }
        .onDisappear { stopRecording() }
    }

    private var buttonTitle: String {
        guard isRecording else { return shortcut.displayString }
        let symbols = KeyboardShortcut.modifierSymbols(liveModifiers)
        return symbols.isEmpty ? "키를 누르세요…" : symbols + "…"
    }

    private func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        isRecording = true
        liveModifiers = 0
        ShortcutCapture.isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            switch event.type {
            case .flagsChanged:
                // Live preview: show modifiers as the user holds them.
                liveModifiers = UInt64(event.modifierFlags.rawValue) & KeyboardShortcut.relevantModifierMask
                return nil
            case .keyDown:
                let mods = UInt64(event.modifierFlags.rawValue) & KeyboardShortcut.relevantModifierMask
                if event.keyCode == 53 && mods == 0 { // bare Escape cancels recording
                    stopRecording()
                    return nil
                }
                guard mods != 0 else { return nil } // require at least one modifier
                shortcut = KeyboardShortcut(keyCode: event.keyCode, modifiers: mods)
                stopRecording()
                return nil
            default:
                return event
            }
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
        liveModifiers = 0
        ShortcutCapture.isRecording = false
    }
}
