import Foundation

final class ProcessNetworkMonitor {
    struct ProcessSample {
        let top: [ProcessNetInfo]
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

    /// 异步获取进程网速 Top10
    func fetchTop10(completion: @escaping (ProcessSample) -> Void) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/nettop")
        task.arguments = ["-P", "-x", "-d", "-s", "1", "-L", "1", "-J", "bytes_in,bytes_out"]

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
            completion(ProcessSample(top: [], totalIn: 0, totalOut: 0))
        }
    }

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

        let top = results.sorted { $0.total() > $1.total() }.prefix(10).map { $0 }
        return ProcessSample(top: top, totalIn: totalIn, totalOut: totalOut)
    }

    func splitCSVLine(_ line: String) -> [String] {
        line.split(separator: ",", omittingEmptySubsequences: false).map { String($0) }
    }

    func parseNumber(_ text: String) -> Double {
        let cleaned = text.replacingOccurrences(of: ",", with: "")
        return Double(cleaned) ?? 0
    }
}
