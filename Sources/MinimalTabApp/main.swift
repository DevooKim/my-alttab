import AppKit
import MinimalTabCore

// Top-level code in a file named main.swift is not MainActor-isolated,
// but the process entry point always runs on the main thread.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
