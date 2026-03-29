import AppKit

final class StatusBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let menu: NSMenu
    private let netMonitor: NetworkMonitor
    private let procMonitor: ProcessNetworkMonitor
    private var timer: Timer?
    private let refreshInterval: Int = 5
    private var secondsRemaining: Int = 0
    private var lastUp: Double = 0
    private var lastDown: Double = 0
    private var lastProcesses: [ProcessNetworkMonitor.ProcessNetInfo] = []
    private var headerItem: NSMenuItem?
    private var countdownItem: NSMenuItem?
    private var processItems: [NSMenuItem] = []
    private var footerSeparator: NSMenuItem?
    private var quitItem: NSMenuItem?
    private var isMenuOpen: Bool = false
    private let monoFont = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)

    /// 初始化菜单栏图标与监控器
    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menu = NSMenu()
        netMonitor = NetworkMonitor()
        procMonitor = ProcessNetworkMonitor()
        super.init()
        statusItem.menu = menu
        menu.delegate = self
        menu.autoenablesItems = false
        buildMenuSkeleton()
        startMonitoring()
    }

    /// 启动定时器并刷新标题与菜单内容
    func startMonitoring() {
        let newTimer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.secondsRemaining <= 0 {
                self.refreshData()
            } else {
                self.secondsRemaining -= 1
                self.updateTitle(up: self.lastUp, down: self.lastDown)
                self.updateCountdown(secondsRemaining: self.secondsRemaining)
            }
        }
        timer = newTimer
        RunLoop.main.add(newTimer, forMode: .common)
        refreshData()
        timer?.fire()
    }

    /// 刷新进程与总网速数据
    func refreshData() {
        DispatchQueue.global(qos: .background).async {
            self.procMonitor.fetchTop10 { sample in
                if sample.totalIn > 0 || sample.totalOut > 0 {
                    self.lastUp = sample.totalOut
                    self.lastDown = sample.totalIn
                } else {
                    let speed = self.netMonitor.getSpeed()
                    self.lastUp = speed.up
                    self.lastDown = speed.down
                }
                self.lastProcesses = sample.top
                self.secondsRemaining = self.refreshInterval
                self.updateTitle(up: self.lastUp, down: self.lastDown)
                self.updateMenu(processes: self.lastProcesses, secondsRemaining: self.secondsRemaining)
            }
        }
    }

    /// 更新菜单栏标题显示当前上下行速率
    func updateTitle(up: Double, down: Double) {
        let title = "↑\(formatSpeed(up)) ↓\(formatSpeed(down))"
        DispatchQueue.main.async {
            self.statusItem.button?.title = title
        }
    }

    /// 刷新下拉菜单展示进程 Top10
    func updateMenu(processes: [ProcessNetworkMonitor.ProcessNetInfo], secondsRemaining: Int) {
        DispatchQueue.main.async {
            self.countdownItem?.title = "下次刷新：\(secondsRemaining) 秒"
            let lines = self.buildAlignedProcessLines(processes: processes)
            let maxCount = self.processItems.count
            for index in 0..<maxCount {
                let item = self.processItems[index]
                if index < lines.count {
                    let attributed = NSAttributedString(string: lines[index], attributes: [.font: self.monoFont])
                    item.attributedTitle = attributed
                    item.isHidden = false
                    item.isEnabled = true
                } else {
                    item.title = ""
                    item.isHidden = true
                    item.isEnabled = false
                }
            }
        }
    }

    /// 初始化菜单结构并创建占位项
    func buildMenuSkeleton() {
        menu.removeAllItems()
        let header = NSMenuItem(title: "🔝 进程网速 Top 10", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        headerItem = header

        let countdown = NSMenuItem(title: "下次刷新：\(refreshInterval) 秒", action: nil, keyEquivalent: "")
        countdown.isEnabled = false
        menu.addItem(countdown)
        countdownItem = countdown

        menu.addItem(.separator())

        processItems = (0..<10).map { _ in
            let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
            item.isEnabled = true
            item.isHidden = true
            menu.addItem(item)
            return item
        }

        let footer = NSMenuItem.separator()
        menu.addItem(footer)
        footerSeparator = footer

        let quit = NSMenuItem(title: "退出 NetPulse", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        quitItem = quit
    }
    /// 只更新倒计时文案以支持菜单动态刷新
    func updateCountdown(secondsRemaining: Int) {
        DispatchQueue.main.async {
            guard self.isMenuOpen else { return }
            self.countdownItem?.title = "下次刷新：\(secondsRemaining) 秒"
        }
    }

    /// 菜单打开时允许倒计时动态更新
    func menuWillOpen(_ menu: NSMenu) {
        isMenuOpen = true
        updateCountdown(secondsRemaining: secondsRemaining)
    }

    /// 菜单关闭时停止倒计时文案刷新
    func menuDidClose(_ menu: NSMenu) {
        isMenuOpen = false
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

    /// 构建对齐后的进程行文本
    func buildAlignedProcessLines(processes: [ProcessNetworkMonitor.ProcessNetInfo]) -> [String] {
        let namePidList = processes.enumerated().map { index, proc in
            "\(index + 1). \(proc.name) (\(proc.pid))"
        }
        let upList = processes.map { "↑\(formatSpeed($0.bytesOut))" }
        let downList = processes.map { "↓\(formatSpeed($0.bytesIn))" }

        let nameWidth = namePidList.map { $0.count }.max() ?? 0
        let upWidth = upList.map { $0.count }.max() ?? 0
        let downWidth = downList.map { $0.count }.max() ?? 0

        return processes.enumerated().map { index, _ in
            let name = padRight(namePidList[index], to: nameWidth)
            let up = padRight(upList[index], to: upWidth)
            let down = padRight(downList[index], to: downWidth)
            return "\(name)  \(up)  \(down)"
        }
    }

    /// 右侧补空格以实现等宽对齐
    func padRight(_ text: String, to length: Int) -> String {
        let padding = max(0, length - text.count)
        return text + String(repeating: " ", count: padding)
    }
}
