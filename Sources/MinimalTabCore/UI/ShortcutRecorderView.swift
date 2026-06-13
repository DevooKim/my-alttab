import SwiftUI
import AppKit

/// Two-part shortcut editor: the modifier is picked from a dropdown and the
/// trigger key is captured separately with a click-to-record button.
public struct ShortcutRecorderView: View {
    let label: String
    @Binding var shortcut: KeyboardShortcut
    @State private var isRecordingKey = false
    @State private var monitor: Any?

    private static let modifierOptions: [(symbol: String, rawValue: UInt64)] = [
        ("⌃ Control", CGEventFlags.maskControl.rawValue),
        ("⌥ Option", CGEventFlags.maskAlternate.rawValue),
        ("⇧ Shift", CGEventFlags.maskShift.rawValue),
        ("⌘ Command", CGEventFlags.maskCommand.rawValue),
    ]

    public init(label: String, shortcut: Binding<KeyboardShortcut>) {
        self.label = label
        self._shortcut = shortcut
    }

    public var body: some View {
        HStack {
            Text(label)
            Spacer()
            Picker("", selection: modifierBinding) {
                ForEach(Self.modifierOptions, id: \.rawValue) { option in
                    Text(option.symbol).tag(option.rawValue)
                }
            }
            .labelsHidden()
            .frame(width: 130)

            Text("+")
                .foregroundColor(.secondary)

            Button(action: toggleKeyRecording) {
                Text(isRecordingKey ? L("recorder.pressKey") : KeyboardShortcut.keyName(for: shortcut.keyCode))
                    .frame(minWidth: 60)
            }
        }
        .onDisappear { stopKeyRecording() }
    }

    private var modifierBinding: Binding<UInt64> {
        Binding(
            get: {
                // A stored combo not in the picker list (e.g. ⌥⌘ from an
                // old version) falls back to showing Option.
                Self.modifierOptions.first { $0.rawValue == shortcut.modifiers }?.rawValue
                    ?? CGEventFlags.maskAlternate.rawValue
            },
            set: { shortcut.modifiers = $0 }
        )
    }

    private func toggleKeyRecording() {
        isRecordingKey ? stopKeyRecording() : startKeyRecording()
    }

    private func startKeyRecording() {
        isRecordingKey = true
        ShortcutCapture.isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Escape cancels recording
                stopKeyRecording()
                return nil
            }
            // Any other single key becomes the trigger; modifiers held
            // during capture are ignored — they come from the picker.
            shortcut.keyCode = event.keyCode
            stopKeyRecording()
            return nil
        }
    }

    private func stopKeyRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecordingKey = false
        ShortcutCapture.isRecording = false
    }
}
