import SwiftUI

/// Liquid Glass (macOS 26+) with a material fallback for macOS 13–15.
///
/// The app deploys back to macOS 13, where `glassEffect` does not exist, so
/// every glass call must be `#available`-gated. This helper centralizes that
/// gate: on macOS 26 it applies a native `glassEffect`; on older systems it
/// falls back to a blurred material that approximates the look.
extension View {
    /// - Parameters:
    ///   - tint: Optional accent tint. Use opacity (not a non-existent
    ///     `.prominent`) to make a surface read as more prominent.
    ///   - interactive: Pass `true` only for elements that respond to input
    ///     (buttons, tappable rows); never on static content.
    ///   - shape: The clip/refraction shape for the glass (and the fallback).
    ///   - fallbackMaterial: Material used on macOS 13–15.
    @ViewBuilder
    func glassEffectWithFallback<S: Shape>(
        tint: Color? = nil,
        interactive: Bool = false,
        in shape: S,
        fallbackMaterial: Material = .ultraThinMaterial
    ) -> some View {
        if #available(macOS 26, *) {
            self.glassEffect(Self.makeGlass(tint: tint, interactive: interactive), in: shape)
        } else {
            self.background(fallbackMaterial, in: shape)
        }
    }

    @available(macOS 26, *)
    private static func makeGlass(tint: Color?, interactive: Bool) -> Glass {
        var glass = Glass.regular
        if let tint { glass = glass.tint(tint) }
        if interactive { glass = glass.interactive() }
        return glass
    }

    /// `.glass` button style on macOS 26, untouched (system default) below.
    @ViewBuilder
    func glassButtonStyle() -> some View {
        if #available(macOS 26, *) {
            self.buttonStyle(.glass)
        } else {
            self
        }
    }

    /// `.glassProminent` button style on macOS 26, untouched below.
    @ViewBuilder
    func glassProminentButtonStyle() -> some View {
        if #available(macOS 26, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self
        }
    }
}
