import Foundation

/// Switcher list size (settings > UI tab).
public enum ListSize: String, CaseIterable {
    case small
    case medium
    case large

    public var panelWidth: CGFloat {
        switch self {
        case .small: return 360
        case .medium: return 440
        case .large: return 540
        }
    }

    public var fontSize: CGFloat {
        switch self {
        case .small: return 12
        case .medium: return 13
        case .large: return 15
        }
    }

    public var iconSize: CGFloat {
        switch self {
        case .small: return 16
        case .medium: return 20
        case .large: return 24
        }
    }

    public var rowVerticalPadding: CGFloat {
        switch self {
        case .small: return 5
        case .medium: return 7
        case .large: return 9
        }
    }

    public var label: String {
        switch self {
        case .small: return L("listSize.small")
        case .medium: return L("listSize.medium")
        case .large: return L("listSize.large")
        }
    }
}

/// How the selected row is highlighted (settings > UI tab).
public enum HighlightStyle: String, CaseIterable {
    /// Accent-color filled rounded rectangle (default).
    case fill
    /// Accent-color outline only; row text keeps its normal color.
    case border

    public var label: String {
        switch self {
        case .fill: return L("highlight.fill")
        case .border: return L("highlight.border")
        }
    }
}
