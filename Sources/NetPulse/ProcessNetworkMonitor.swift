import Foundation

final class ProcessNetworkMonitor {
    struct ProcessNetInfo {
        let pid: Int
        let name: String
        let bytesIn: Double
        let bytesOut: Double

        /// 计算进程的总流量
        func total() -> Double {
            bytesIn + bytesOut
        }
    }

    /// 异步获取进程网速 Top10
    func fetchTop10(completion: @escaping ([ProcessNetInfo]) -> Void) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/nettop")
        task.arguments = ["-P", "-x", "-s", "1", "-L", "1", "-J", "bytes_in,bytes_out"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        task.terminationHandler = { _ in
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            let results = self.parseNettop(output)
            completion(results)
        }

        do {
            try task.run()
        } catch {
            completion([])
        }
    }

    /// 解析 nettop 输出并按总流量排序取前十
    func parseNettop(_ output: String) -> [ProcessNetInfo] {
        let lines = output.split(separator: "\n")
        var results: [ProcessNetInfo] = []

        for line in lines {
            let cols = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard cols.count >= 3 else { continue }

            let namePid = String(cols[0])
            guard let dotIndex = namePid.lastIndex(of: ".") else { continue }
            let name = String(namePid[..<dotIndex])
            let pidPart = String(namePid[namePid.index(after: dotIndex)...])
            guard let pid = Int(pidPart) else { continue }

            let bytesIn = parseNumber(String(cols[1]))
            let bytesOut = parseNumber(String(cols[2]))
            results.append(ProcessNetInfo(pid: pid, name: name, bytesIn: bytesIn, bytesOut: bytesOut))
        }

        return results.sorted { $0.total() > $1.total() }.prefix(10).map { $0 }
    }

    /// 解析带分隔符的数字字符串
    func parseNumber(_ text: String) -> Double {
        let cleaned = text.replacingOccurrences(of: ",", with: "")
        return Double(cleaned) ?? 0
    }
}
