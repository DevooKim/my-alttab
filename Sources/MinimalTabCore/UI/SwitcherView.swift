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

/// Panel chrome: native Liquid Glass on macOS 26, frosted material + hairline
/// stroke fallback on macOS 13–15.
private struct PanelBackground: ViewModifier {
    let shape: RoundedRectangle

    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            // Native glass supplies its own edge highlight — no manual stroke.
            content.glassEffect(.regular, in: shape)
        } else {
            content
                .background(VisualEffectBackground())
                .clipShape(shape)
                .overlay(shape.strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
        }
    }
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
    @AppStorage(Preferences.Key.listSize) private var listSizeRaw = ListSize.medium.rawValue
    @AppStorage(Preferences.Key.highlightStyle) private var highlightStyleRaw = HighlightStyle.fill.rawValue

    public init(model: SwitcherViewModel) {
        self.model = model
    }

    private var listSize: ListSize { ListSize(rawValue: listSizeRaw) ?? .medium }
    private var highlightStyle: HighlightStyle { HighlightStyle(rawValue: highlightStyleRaw) ?? .fill }

    private let panelShape = RoundedRectangle(cornerRadius: 16, style: .continuous)

    public var body: some View {
        sizedContent
            .modifier(PanelBackground(shape: panelShape))
    }

    private var sizedContent: some View {
        content
            .frame(width: listSize.panelWidth)
            .frame(maxHeight: 480)
    }

    @ViewBuilder
    private var content: some View {
        if model.windows.isEmpty {
            emptyState
        } else {
            list
        }
    }

    private var emptyState: some View {
        HStack(spacing: 10) {
            Image(systemName: "macwindow")
                .frame(width: listSize.iconSize, height: listSize.iconSize)
                .foregroundColor(.secondary)
            Text(L("switcher.empty"))
                .font(.system(size: listSize.fontSize))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 2) {
                    ForEach(Array(model.windows.enumerated()), id: \.element.id) { index, window in
                        SwitcherRow(window: window,
                                    isSelected: index == model.selectedIndex,
                                    size: listSize,
                                    highlight: highlightStyle)
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
    }
}

private struct SwitcherRow: View {
    let window: WindowInfo
    let isSelected: Bool
    let size: ListSize
    let highlight: HighlightStyle

    var body: some View {
        HStack(spacing: 10) {
            if let icon = window.appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: size.iconSize, height: size.iconSize)
            } else {
                Image(systemName: "macwindow")
                    .frame(width: size.iconSize, height: size.iconSize)
            }
            // PRD 2.B: [icon] + [bold app name] - [regular window title]
            (Text(window.appName).fontWeight(.bold)
                + Text("  —  ").foregroundColor(.secondary)
                + Text(window.displayTitle(untitled: L("switcher.untitled"), minimizedSuffix: L("switcher.minimizedSuffix"))))
                .font(.system(size: size.fontSize))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 8)
            if let space = window.spaceNumber {
                // Space (desktop) number badge at the trailing edge.
                Text("\(space)")
                    .font(.system(size: size.fontSize - 2, weight: .medium))
                    .monospacedDigit()
                    .foregroundColor(isSelected && highlight == .fill ? .white.opacity(0.9) : .secondary)
                    .frame(minWidth: size.fontSize + 4)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(
                        Capsule().fill(
                            isSelected && highlight == .fill
                                ? Color.white.opacity(0.2)
                                : Color.secondary.opacity(0.15)
                        )
                    )
            }
        }
        // PRD 4.A: minimized items at 50% text opacity
        .opacity(window.isMinimized ? 0.5 : 1.0)
        .padding(.horizontal, 12)
        .padding(.vertical, size.rowVerticalPadding)
        .background(selectionBackground)
        .foregroundColor(isSelected && highlight == .fill ? .white : .primary)
        .contentShape(Rectangle())
    }

    private var selectionShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
    }

    @ViewBuilder
    private var selectionBackground: some View {
        // PRD 2.A: rounded accent-color highlight on selection
        switch (isSelected, highlight) {
        case (false, _):
            Color.clear
        case (true, .fill):
            fillHighlight
        case (true, .border):
            selectionShape.strokeBorder(Color.accentColor, lineWidth: 2)
        }
    }

    /// Selected-row fill: a morphing tinted glass capsule on macOS 26
    /// (shared `glassEffectID` so it slides between rows), solid accent
    /// fill on macOS 13–15.
    private var fillHighlight: some View {
        // Solid accent fill, all OS versions. Glass-on-glass (a glass selection
        // plate over the already-glass panel) renders as an opaque plate that
        // covers the row's icon/title, so the selection stays a plain accent
        // fill — like macOS's own AltTab/Spotlight highlight. The panel
        // background keeps its Liquid Glass.
        selectionShape.fill(Color.accentColor.opacity(0.85))
    }
}
