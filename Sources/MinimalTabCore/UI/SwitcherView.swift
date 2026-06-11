import SwiftUI
import AppKit

/// Observable bridge between SwitcherController and SwiftUI.
@MainActor
public final class SwitcherViewModel: ObservableObject {
    @Published public var windows: [WindowInfo] = []
    @Published public var selectedIndex: Int = 0
    /// Set by the view when the user clicks a row.
    public var onRowClicked: ((Int) -> Void)?

    public init() {}
}

/// NSVisualEffectView bridge for the frosted-glass background (PRD 2.A).
struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

public struct SwitcherView: View {
    @ObservedObject var model: SwitcherViewModel

    public init(model: SwitcherViewModel) {
        self.model = model
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 2) {
                    ForEach(Array(model.windows.enumerated()), id: \.element.id) { index, window in
                        SwitcherRow(window: window, isSelected: index == model.selectedIndex)
                            .id(index)
                            .onTapGesture { model.onRowClicked?(index) }
                    }
                }
                .padding(12)
            }
            .onChange(of: model.selectedIndex) { newIndex in
                withAnimation(.easeOut(duration: 0.1)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
        .frame(width: 440)
        .frame(maxHeight: 480)
        .background(VisualEffectBackground())
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
        )
    }
}

private struct SwitcherRow: View {
    let window: WindowInfo
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            if let icon = window.appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: "macwindow")
                    .frame(width: 20, height: 20)
            }
            // PRD 2.B: [icon] + [bold app name] - [regular window title]
            Text(window.appName).fontWeight(.bold)
                + Text("  —  ").foregroundColor(.secondary)
                + Text(window.displayTitle)
            Spacer(minLength: 0)
        }
        .font(.system(size: 13))
        .lineLimit(1)
        .truncationMode(.middle)
        // PRD 4.A: minimized items at 50% text opacity
        .opacity(window.isMinimized ? 0.5 : 1.0)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            // PRD 2.A: rounded accent-color highlight on selection
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.85) : Color.clear)
        )
        .foregroundColor(isSelected ? .white : .primary)
        .contentShape(Rectangle())
    }
}
