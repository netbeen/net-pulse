import AppKit

final class StatusBarController {
    private let statusItem: NSStatusItem
    private let menu: NSMenu
    private let netMonitor: NetworkMonitor
    private let procMonitor: ProcessNetworkMonitor
    private var timer: Timer?

    /// 初始化菜单栏图标与监控器
    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menu = NSMenu()
        netMonitor = NetworkMonitor()
        procMonitor = ProcessNetworkMonitor()
        statusItem.menu = menu
        startMonitoring()
    }

    /// 启动定时器并刷新标题与菜单内容
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let speed = self.netMonitor.getSpeed()
            self.updateTitle(up: speed.up, down: speed.down)

            DispatchQueue.global(qos: .background).async {
                self.procMonitor.fetchTop10 { processes in
                    self.updateMenu(processes: processes)
                }
            }
        }
        timer?.fire()
    }

    /// 更新菜单栏标题显示当前上下行速率
    func updateTitle(up: Double, down: Double) {
        let title = "↑\(formatSpeed(up)) ↓\(formatSpeed(down))"
        DispatchQueue.main.async {
            self.statusItem.button?.title = title
        }
    }

    /// 刷新下拉菜单展示进程 Top10
    func updateMenu(processes: [ProcessNetworkMonitor.ProcessNetInfo]) {
        DispatchQueue.main.async {
            self.menu.removeAllItems()
            let header = NSMenuItem(title: "🔝 进程网速 Top 10", action: nil, keyEquivalent: "")
            header.isEnabled = false
            self.menu.addItem(header)
            self.menu.addItem(.separator())

            for (index, proc) in processes.enumerated() {
                let upStr = self.formatSpeed(proc.bytesOut)
                let downStr = self.formatSpeed(proc.bytesIn)
                let label = "\(index + 1). \(proc.name) (\(proc.pid))  ↑\(upStr) ↓\(downStr)"
                self.menu.addItem(NSMenuItem(title: label, action: nil, keyEquivalent: ""))
            }

            self.menu.addItem(.separator())
            let quit = NSMenuItem(title: "退出 NetPulse", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            self.menu.addItem(quit)
        }
    }

    /// 将字节速率格式化为可读字符串
    func formatSpeed(_ bytes: Double) -> String {
        if bytes >= 1_000_000 {
            return String(format: "%.1fMB/s", bytes / 1_000_000)
        }
        if bytes >= 1_000 {
            return String(format: "%.0fKB/s", bytes / 1_000)
        }
        return String(format: "%.0fB/s", bytes)
    }
}
