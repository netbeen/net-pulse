# NetPulse

菜单栏实时网速与应用/进程网络速率监控（macOS）。

## 功能
- 菜单栏实时显示总上传/下载速率
- 点击下拉查看应用网速 Top 20（按应用名聚合，显示上行/下行）
- 支持展开子菜单查看该应用下的进程列表（含 PID）
- 统计范围可切换：全部接口 / 外网接口
- 黑名单过滤（影响列表与总计）：过滤 corplink*、mDNSResponder 等
- 5 秒刷新一次，菜单内显示倒计时并动态更新
- 速率分级着色：<500KB/s、<1MB/s、<10MB/s、≥10MB/s

## 开发运行
```bash
swift run
```

## 一键打包（本地双击运行）
```bash
bash scripts/package_app.sh
```

打包后生成：
```
dist/NetPulse.app
```

## 仅生成图标
```bash
ICON_ONLY=1 bash scripts/package_app.sh
```

## 说明
- 进程数据来源：`nettop`
- 打包脚本会自动生成应用图标（AppIcon.icns）
- 统计范围“外网接口”会过滤掉非 external 的流量；如果发现 Chrome 等应用无流量，切到“全部接口”验证
