import Foundation

final class ProcessNetworkMonitor {
    enum InterfaceType {
        case external
        case all
    }

    struct ProcessSample {
        let processes: [ProcessNetInfo]
        let totalIn: Double
        let totalOut: Double
    }

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

    /// 异步获取进程网速采样结果
    func fetchSample(interfaceType: InterfaceType, completion: @escaping (ProcessSample) -> Void) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/nettop")
        task.arguments = buildArguments(interfaceType: interfaceType)

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
            completion(ProcessSample(processes: [], totalIn: 0, totalOut: 0))
        }
    }

    /// 解析 nettop 输出为进程采样数据
    func parseNettop(_ output: String) -> ProcessSample {
        let lines = output.split(separator: "\n")
        var results: [ProcessNetInfo] = []
        var totalIn: Double = 0
        var totalOut: Double = 0

        for line in lines {
            let cols = splitCSVLine(String(line))
            guard cols.count >= 3 else { continue }

            let namePid = cols[0].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !namePid.isEmpty else { continue }
            guard let dotIndex = namePid.lastIndex(of: ".") else { continue }
            let name = String(namePid[..<dotIndex])
            let pidPart = String(namePid[namePid.index(after: dotIndex)...])
            guard let pid = Int(pidPart) else { continue }

            let bytesIn = parseNumber(cols[1])
            let bytesOut = parseNumber(cols[2])
            results.append(ProcessNetInfo(pid: pid, name: name, bytesIn: bytesIn, bytesOut: bytesOut))
            totalIn += bytesIn
            totalOut += bytesOut
        }

        return ProcessSample(processes: results, totalIn: totalIn, totalOut: totalOut)
    }

    /// 将 nettop CSV 行按逗号切分
    func splitCSVLine(_ line: String) -> [String] {
        line.split(separator: ",", omittingEmptySubsequences: false).map { String($0) }
    }

    /// 解析带分隔符的数字字符串
    func parseNumber(_ text: String) -> Double {
        let cleaned = text.replacingOccurrences(of: ",", with: "")
        return Double(cleaned) ?? 0
    }

    /// 构建 nettop 命令参数
    func buildArguments(interfaceType: InterfaceType) -> [String] {
        var args = ["-P", "-x", "-d", "-s", "1", "-L", "1", "-J", "bytes_in,bytes_out"]
        if interfaceType == .external {
            args.insert(contentsOf: ["-t", "external"], at: 3)
        }
        return args
    }
}
