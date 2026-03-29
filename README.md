# NetPulse

菜单栏实时网速与进程 Top10 监控（macOS）。

## 功能
- 菜单栏实时显示总上传/下载速率
- 点击下拉查看进程 Top10（上行/下行）
- 下拉菜单显示倒计时刷新
- 进程列表按速率分级着色

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

## 说明
- 进程数据来源：`nettop`
- 打包脚本会自动生成应用图标（AppIcon.icns）
