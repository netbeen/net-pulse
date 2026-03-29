# NetPulse 实现路径规划（macOS 菜单栏网速 + 进程 Top10）

## 目标
- 菜单栏实时展示设备总上传/下载速度
- 点击后下拉菜单显示“上传+下载总速度”排名前 10 的进程名称与 PID
- 原生体验、低功耗、可持续运行

## 技术选型
- 语言/框架：Swift + AppKit
- 理由：
  - 菜单栏应用原生体验最佳
  - 系统接口完整，可调用 getifaddrs 获取全局流量
  - 与 nettop 交互更稳定，进程维度更容易落地

## 功能模块拆分
```
NetPulse/
├── AppDelegate.swift            // 入口 + 生命周期
├── StatusBarController.swift    // 菜单栏图标 + 下拉菜单
├── NetworkMonitor.swift         // 系统级总速率
├── ProcessNetworkMonitor.swift  // 进程速率 Top10
└── Info.plist                   // LSUIElement=true 隐藏 Dock 图标
```

## 核心实现步骤（推荐顺序）

### Step 1：项目初始化
- Xcode 新建 macOS App（AppKit）
- Info.plist 设置 Application is agent (UIElement) = YES
- 目标：菜单栏出现固定文字图标（确认启动流程）

### Step 2：菜单栏图标 + 定时刷新框架
- 创建 NSStatusItem
- 启动 Timer 周期更新
- 目标：每 2s 更新标题文本

### Step 3：系统总速率监测
- 使用 getifaddrs + if_data 统计全网卡字节累计
- 通过时间差计算 bytes/s
- 目标：菜单栏显示实时 ↑X ↓Y

### Step 4：进程维度 Top10（最关键）
- 调用系统命令 nettop 采样 1s  
  nettop -P -x -s 1 -L 1 -J bytes_in,bytes_out
- 解析输出，提取进程名、PID、上下行速率
- 排序取 Top10
- 目标：点击菜单显示 Top10 列表

### Step 5：交互与体验优化
- 菜单标题、分割线
- 速率格式化（B/KB/MB）
- 增加“退出”菜单项

## 风险与解决策略

### 1）nettop 权限问题
- nettop 在沙盒内会失败
- 建议：
  - 开发调试阶段关闭 App Sandbox
  - 分发：自签或非 App Store

### 2）nettop 性能
- 每 2s 调一次 nettop 会阻塞 1s
- 解决：
  - 放入后台线程
  - 菜单更新回主线程

### 3）输出解析不稳定
- nettop 输出可能含空格/逗号
- 解决：
  - 正则拆分
  - 清理数字中的 ,

## 代码实现节奏建议
- Day 1：菜单栏 + 固定文字
- Day 2：接入总速率
- Day 3：接入 nettop + Top10
- Day 4：UI + 格式优化
- Day 5：打包 + 自启动

## 验证清单
- 菜单栏速度是否与实际体验一致
- Top10 是否随下载/上传变化而刷新
- 退出菜单能否正确关闭
- CPU 占用是否可接受（nettop 调用频率）

## 你可以先完成的最小可用版本（MVP）
- 菜单栏显示：↑X ↓Y
- 菜单点击显示 Top10
- 退出功能
