import SwiftUI
import AppKit

/// Click-to-record shortcut field. While recording, a local key monitor
/// captures the next modifier+key combination.
public struct ShortcutRecorderView: View {
    let label: String
    @Binding var shortcut: KeyboardShortcut
    @State private var isRecording = false
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
                Text(isRecording ? "키를 누르세요…" : shortcut.displayString)
                    .frame(minWidth: 90)
            }
        }
        .onDisappear { stopRecording() }
    }

    private func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        isRecording = true
        ShortcutCapture.isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let mods = UInt64(event.modifierFlags.rawValue) & KeyboardShortcut.relevantModifierMask
            if event.keyCode == 53 && mods == 0 { // bare Escape cancels recording
                stopRecording()
                return nil
            }
            guard mods != 0 else { return nil } // require at least one modifier
            shortcut = KeyboardShortcut(keyCode: event.keyCode, modifiers: mods)
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
        ShortcutCapture.isRecording = false
    }
}
