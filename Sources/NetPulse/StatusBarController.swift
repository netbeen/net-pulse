import AppKit

final class StatusBarController: NSObject, NSMenuDelegate {
    struct AppNetInfo {
        let name: String
        let bytesIn: Double
        let bytesOut: Double
        let processes: [ProcessNetworkMonitor.ProcessNetInfo]

        /// 计算应用聚合的总流量
        func total() -> Double {
            bytesIn + bytesOut
        }
    }

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
    private var lastApps: [AppNetInfo] = []
    private var interfaceType: ProcessNetworkMonitor.InterfaceType = .all
    private var blacklistEnabled: Bool = true
    private var headerItem: NSMenuItem?
    private var interfaceFilterItem: NSMenuItem?
    private var blacklistToggleItem: NSMenuItem?
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
            self.procMonitor.fetchSample(interfaceType: self.interfaceType) { sample in
                self.lastProcesses = self.applyBlacklist(processes: sample.processes)
                let totals = self.sumTotals(processes: self.lastProcesses)
                self.lastUp = totals.up
                self.lastDown = totals.down
                self.lastApps = self.aggregateByApp(processes: self.lastProcesses)
                self.secondsRemaining = self.refreshInterval
                self.updateTitle(up: self.lastUp, down: self.lastDown)
                self.updateMenu(apps: self.lastApps, secondsRemaining: self.secondsRemaining)
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
    func updateMenu(apps: [AppNetInfo], secondsRemaining: Int) {
        DispatchQueue.main.async {
            self.countdownItem?.title = "下次刷新：\(secondsRemaining) 秒"
            let lines = self.buildAlignedAppLines(apps: apps)
            let maxCount = self.processItems.count
            for index in 0..<maxCount {
                let item = self.processItems[index]
                if index < lines.count {
                    let color = self.colorForSpeed(lines[index].speed)
                    let attributed = NSAttributedString(
                        string: lines[index].text,
                        attributes: [.font: self.monoFont, .foregroundColor: color]
                    )
                    item.attributedTitle = attributed
                    item.isHidden = false
                    item.isEnabled = true
                    self.updateSubmenu(for: item, app: apps[index])
                } else {
                    item.title = ""
                    item.isHidden = true
                    item.isEnabled = false
                    item.submenu = nil
                }
            }
        }
    }

    /// 初始化菜单结构并创建占位项
    func buildMenuSkeleton() {
        menu.removeAllItems()
        let header = NSMenuItem(title: "🔝 应用网速 Top 20", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        headerItem = header

        let filterItem = NSMenuItem(title: "", action: #selector(toggleInterfaceFilter(_:)), keyEquivalent: "")
        filterItem.target = self
        filterItem.isEnabled = true
        menu.addItem(filterItem)
        interfaceFilterItem = filterItem
        updateFilterItemTitle()

        let blacklistItem = NSMenuItem(title: "", action: #selector(toggleBlacklist(_:)), keyEquivalent: "")
        blacklistItem.target = self
        blacklistItem.isEnabled = true
        menu.addItem(blacklistItem)
        blacklistToggleItem = blacklistItem
        updateBlacklistItemTitle()

        let countdown = NSMenuItem(title: "下次刷新：\(refreshInterval) 秒", action: nil, keyEquivalent: "")
        countdown.isEnabled = false
        menu.addItem(countdown)
        countdownItem = countdown

        menu.addItem(.separator())

        processItems = (0..<20).map { _ in
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

    /// 构建对齐后的应用行文本
    func buildAlignedAppLines(apps: [AppNetInfo]) -> [(text: String, speed: Double)] {
        let nameList = apps.enumerated().map { index, app in
            "\(index + 1). \(app.name) [\(app.processes.count)]"
        }
        let upList = apps.map { "↑\(formatSpeed($0.bytesOut))" }
        let downList = apps.map { "↓\(formatSpeed($0.bytesIn))" }

        let nameWidth = nameList.map { $0.count }.max() ?? 0
        let upWidth = upList.map { $0.count }.max() ?? 0
        let downWidth = downList.map { $0.count }.max() ?? 0

        return apps.enumerated().map { index, app in
            let name = padRight(nameList[index], to: nameWidth)
            let up = padRight(upList[index], to: upWidth)
            let down = padRight(downList[index], to: downWidth)
            let text = "\(name)  \(up)  \(down)"
            let speed = app.total()
            return (text: text, speed: speed)
        }
    }

    /// 右侧补空格以实现等宽对齐
    func padRight(_ text: String, to length: Int) -> String {
        let padding = max(0, length - text.count)
        return text + String(repeating: " ", count: padding)
    }

    /// 将进程列表按应用名称聚合并返回 Top20
    func aggregateByApp(processes: [ProcessNetworkMonitor.ProcessNetInfo]) -> [AppNetInfo] {
        var map: [String: (bytesIn: Double, bytesOut: Double, processes: [ProcessNetworkMonitor.ProcessNetInfo])] = [:]
        for proc in processes {
            let appName = canonicalAppName(proc.name)
            var entry = map[appName] ?? (bytesIn: 0, bytesOut: 0, processes: [])
            entry.bytesIn += proc.bytesIn
            entry.bytesOut += proc.bytesOut
            entry.processes.append(proc)
            map[appName] = entry
        }

        let apps = map.map { name, entry in
            AppNetInfo(name: name, bytesIn: entry.bytesIn, bytesOut: entry.bytesOut, processes: entry.processes)
        }
        let filtered = apps.filter { $0.total() > 0 }
        return filtered.sorted { $0.total() > $1.total() }.prefix(20).map { $0 }
    }

    /// 将进程名称归一化到应用名称（聚合使用）
    func canonicalAppName(_ processName: String) -> String {
        if processName.hasPrefix("Google Chrome") { return "Google Chrome" }
        if let range = processName.range(of: " Helper") {
            let base = String(processName[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !base.isEmpty { return base }
        }
        return processName
    }

    /// 为聚合应用项构建子菜单，展示隐藏的子进程列表
    func updateSubmenu(for item: NSMenuItem, app: AppNetInfo) {
        let submenu = item.submenu ?? NSMenu()
        submenu.autoenablesItems = false
        submenu.removeAllItems()
        let header = NSMenuItem(title: "进程列表（\(app.processes.count)）", action: nil, keyEquivalent: "")
        header.isEnabled = false
        submenu.addItem(header)
        submenu.addItem(.separator())

        let sorted = app.processes.sorted { $0.total() > $1.total() }
        let limit = 50
        let shown = sorted.prefix(limit)
        for proc in shown {
            let upStr = formatSpeed(proc.bytesOut)
            let downStr = formatSpeed(proc.bytesIn)
            let title = "\(proc.name) (\(proc.pid))  ↑\(upStr) ↓\(downStr)"
            let child = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            child.isEnabled = true
            submenu.addItem(child)
        }

        if sorted.count > limit {
            submenu.addItem(.separator())
            let more = NSMenuItem(title: "… 还有 \(sorted.count - limit) 个进程", action: nil, keyEquivalent: "")
            more.isEnabled = false
            submenu.addItem(more)
        }

        item.submenu = submenu
    }

    /// 切换 nettop 统计接口范围（external / all）
    @objc func toggleInterfaceFilter(_ sender: NSMenuItem) {
        interfaceType = (interfaceType == .external) ? .all : .external
        updateFilterItemTitle()
        secondsRemaining = 0
        refreshData()
    }

    /// 切换黑名单过滤开关（影响列表与总计）
    @objc func toggleBlacklist(_ sender: NSMenuItem) {
        blacklistEnabled.toggle()
        updateBlacklistItemTitle()
        secondsRemaining = 0
        refreshData()
    }

    /// 更新过滤开关菜单项文案
    func updateFilterItemTitle() {
        let modeText = (interfaceType == .external) ? "外网接口" : "全部接口"
        interfaceFilterItem?.title = "统计范围：\(modeText)（点击切换）"
    }

    /// 更新黑名单开关菜单项文案
    func updateBlacklistItemTitle() {
        let stateText = blacklistEnabled ? "开" : "关"
        blacklistToggleItem?.title = "过滤黑名单：\(stateText)（点击切换）"
    }

    func colorForSpeed(_ bytesPerSecond: Double) -> NSColor {
        if bytesPerSecond < 500_000 {
            return .secondaryLabelColor
        }
        if bytesPerSecond < 1_000_000 {
            return .systemGreen
        }
        if bytesPerSecond < 10_000_000 {
            return .systemOrange
        }
        return .systemRed
    }

    /// 对进程列表应用黑名单过滤
    func applyBlacklist(processes: [ProcessNetworkMonitor.ProcessNetInfo]) -> [ProcessNetworkMonitor.ProcessNetInfo] {
        guard blacklistEnabled else { return processes }
        return processes.filter { proc in
            let appName = canonicalAppName(proc.name)
            return !isBlacklisted(appName: appName)
        }
    }

    /// 判断应用名是否在黑名单中
    func isBlacklisted(appName: String) -> Bool {
        let key = normalizedNameKey(appName)
        if key == "mdnsresponder" { return true }
        if key.hasPrefix("corplink") { return true }
        return false
    }

    /// 归一化名称用于匹配（小写、去掉非字母数字字符）
    func normalizedNameKey(_ name: String) -> String {
        let lower = name.lowercased()
        return String(lower.filter { $0.isLetter || $0.isNumber })
    }

    /// 计算过滤后的总上下行速率
    func sumTotals(processes: [ProcessNetworkMonitor.ProcessNetInfo]) -> (up: Double, down: Double) {
        var up: Double = 0
        var down: Double = 0
        for proc in processes {
            down += proc.bytesIn
            up += proc.bytesOut
        }
        return (up: up, down: down)
    }
}
