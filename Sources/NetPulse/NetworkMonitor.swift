import Foundation

final class NetworkMonitor {
    private var lastBytesIn: UInt64 = 0
    private var lastBytesOut: UInt64 = 0
    private var lastTime: Date = Date()

    /// 读取全网卡累计字节数
    func getCurrentBytes() -> (bytesIn: UInt64, bytesOut: UInt64) {
        var bytesIn: UInt64 = 0
        var bytesOut: UInt64 = 0

        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return (0, 0) }
        defer { freeifaddrs(ifaddr) }

        var ptr = ifaddr
        while ptr != nil {
            let addr = ptr!.pointee
            if addr.ifa_addr.pointee.sa_family == UInt8(AF_LINK) {
                let data = unsafeBitCast(addr.ifa_data, to: UnsafeMutablePointer<if_data>.self)
                bytesIn += UInt64(data.pointee.ifi_ibytes)
                bytesOut += UInt64(data.pointee.ifi_obytes)
            }
            ptr = addr.ifa_next
        }
        return (bytesIn, bytesOut)
    }

    /// 计算当前上传与下载速率（bytes/s）
    func getSpeed() -> (up: Double, down: Double) {
        let now = Date()
        let (curIn, curOut) = getCurrentBytes()
        let interval = now.timeIntervalSince(lastTime)
        let down = interval > 0 ? Double(curIn - lastBytesIn) / interval : 0
        let up = interval > 0 ? Double(curOut - lastBytesOut) / interval : 0
        lastBytesIn = curIn
        lastBytesOut = curOut
        lastTime = now
        return (up: up, down: down)
    }
}
