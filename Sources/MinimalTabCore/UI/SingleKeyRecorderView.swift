import SwiftUI
import AppKit

/// Click-to-record a single key (no modifier required) — used for the
/// Quick Action keys. Escape cancels recording.
public struct SingleKeyRecorderView: View {
    let label: String
    @Binding var keyCode: UInt16
    @State private var isRecording = false
    @State private var monitor: Any?

    public init(label: String, keyCode: Binding<UInt16>) {
        self.label = label
        self._keyCode = keyCode
    }

    public var body: some View {
        HStack {
            Text(label)
            Spacer()
            Button(action: toggleRecording) {
                Text(isRecording ? "키 입력…" : KeyboardShortcut.keyName(for: keyCode))
                    .frame(minWidth: 60)
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
            if event.keyCode != 53 { // Escape cancels
                keyCode = event.keyCode
            }
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
