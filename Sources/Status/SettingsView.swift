import StatusCore
import SwiftUI

/// 主设置界面（PRD §5.2 五 Tab）。绑定 SettingsModel，改动经 onChange → persist() 写回并实时生效。
struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        TabView {
            general.tabItem { Label("通用", systemImage: "gearshape") }
            network.tabItem { Label("网络", systemImage: "network") }
            memory.tabItem { Label("内存", systemImage: "memorychip") }
            cpuTab.tabItem { Label("CPU", systemImage: "cpu") }
            display.tabItem { Label("显示", systemImage: "rectangle.3.group") }
        }
        .frame(width: 480, height: 340)
        .onChange(of: model.value) { _, _ in model.persist() }
    }

    // MARK: 通用

    private var general: some View {
        Form {
            Picker("刷新间隔", selection: $model.value.refreshIntervalSeconds) {
                Text("1 秒").tag(1.0)
                Text("2 秒").tag(2.0)
                Text("5 秒").tag(5.0)
            }
            Picker("外观", selection: $model.value.appearance) {
                Text("跟随系统").tag(AppearanceMode.system)
                Text("浅色").tag(AppearanceMode.light)
                Text("深色").tag(AppearanceMode.dark)
            }
            Toggle("开机自启动", isOn: Binding(
                get: { model.value.launchAtLogin },
                set: { newValue in
                    model.value.launchAtLogin = newValue
                    LoginItemManager.setEnabled(newValue)
                }
            ))
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: 网络

    private var network: some View {
        Form {
            Picker("速率单位", selection: $model.value.networkUnit) {
                Text("自动").tag(NetworkSpeedUnit.auto)
                Text("KB/s").tag(NetworkSpeedUnit.kbs)
                Text("MB/s").tag(NetworkSpeedUnit.mbs)
                Text("Kbps").tag(NetworkSpeedUnit.kbps)
                Text("Mbps").tag(NetworkSpeedUnit.mbps)
            }
            Toggle("显示方向箭头（↓↑）", isOn: $model.value.showNetworkArrows)
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: 内存

    private var memory: some View {
        Form {
            Picker("显示单位", selection: $model.value.memoryUnit) {
                Text("自动 GB/MB").tag(MemoryUnit.autoGB)
                Text("GB").tag(MemoryUnit.gb)
                Text("MB").tag(MemoryUnit.mb)
            }
            Picker("显示格式", selection: $model.value.memoryFormat) {
                Text("仅已用").tag(MemoryFormat.usedOnly)
                Text("已用 / 总量").tag(MemoryFormat.usedOfTotal)
                Text("百分比").tag(MemoryFormat.percent)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: CPU

    private var cpuTab: some View {
        Form {
            Toggle("显示单核占用（菜单详情）", isOn: $model.value.showCPUPerCore)
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: 显示

    private var display: some View {
        Form {
            Section("状态栏项顺序与显隐") {
                ForEach(Array(model.value.itemOrder.enumerated()), id: \.element) { index, item in
                    HStack {
                        Toggle(item.title, isOn: bindingForVisible(item))
                        Spacer()
                        Button("↑") { move(from: index, delta: -1) }
                            .disabled(index == 0)
                        Button("↓") { move(from: index, delta: 1) }
                            .disabled(index == model.value.itemOrder.count - 1)
                    }
                }
            }
            Toggle("紧凑模式", isOn: $model.value.compactMode)
        }
        .formStyle(.grouped)
        .padding()
    }

    private func bindingForVisible(_ item: StatusItem) -> Binding<Bool> {
        Binding(
            get: { model.value.isVisible(item) },
            set: { visible in
                if visible {
                    model.value.hiddenItems.remove(item)
                } else {
                    model.value.hiddenItems.insert(item)
                }
            }
        )
    }

    private func move(from index: Int, delta: Int) {
        let target = index + delta
        guard model.value.itemOrder.indices.contains(target) else { return }
        model.value.itemOrder.swapAt(index, target)
    }
}

private extension StatusItem {
    var title: String {
        switch self {
        case .network: "网络"
        case .memory: "内存"
        case .cpu: "CPU"
        }
    }
}
