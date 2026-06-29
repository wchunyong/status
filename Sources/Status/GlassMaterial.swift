import SwiftUI

/// macOS 26+ 液态玻璃材质适配（B7）。
/// 26+ 用 `.glassEffect()`，旧系统回退 `.ultraThinMaterial`，集中封装避免散落。
struct GlassBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect()
        } else {
            content.background(.ultraThinMaterial)
        }
    }
}

extension View {
    /// 应用液态玻璃背景（26+）或毛玻璃回退（14+）。
    func glassBackground() -> some View {
        modifier(GlassBackground())
    }
}
