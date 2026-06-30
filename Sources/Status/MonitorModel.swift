import Combine
import StatusCore

/// 实时采样的可观察中枢。Sampler 每秒写入 `sample`，状态栏与浮窗都读它。
/// 下拉浮窗默认随此 1s 刷新（B3/B8）。@MainActor，所有访问主线程。
@MainActor
final class MonitorModel: ObservableObject {
    @Published var sample: Sample?
}
