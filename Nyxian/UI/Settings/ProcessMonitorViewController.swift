/*
 SPDX-License-Identifier: AGPL-3.0-or-later
*/

import UIKit
import Darwin

class ProcessMonitorViewController: UIThemedTableViewController {
    var timer: Timer?

    private enum NXSysctl {
        static let ctlHW: Int32 = 6
        static let hwNCPU: Int32 = 3
    }

    private struct NXKernelVMFlags: OptionSet {
        let rawValue: Int32

        static let read = NXKernelVMFlags(rawValue: 0x01)
        static let write = NXKernelVMFlags(rawValue: 0x02)

        static let defaultWritePatch: NXKernelVMFlags = [.read, .write]
    }

    private enum SortMode: Int, CaseIterable {
        case topCPU = 0
        case topMemory = 1
        case pid = 2

        var title: String {
            switch self {
            case .topCPU: return "CPU"
            case .topMemory: return "MEM"
            case .pid: return "PID"
            }
        }
    }

    private struct ProcessSnapshot {
        let totalTimeNs: UInt64
        let residentBytes: UInt64
    }

    private struct ProcessStats {
        let cpuPercent: Double
        let residentBytes: UInt64
    }

    private struct FreezeEntry {
        let pid: Int32
        let address: UInt64
        let bytes: [UInt8]
    }

    private var previousSnapshots: [Int32: ProcessSnapshot] = [:]
    private var statsByPid: [Int32: ProcessStats] = [:]
    private var displayedProcesses: [LDEProcess] = []
    private var lastRefreshUptimeNs: UInt64?
    private var cpuCoreCount: Int32 = 1
    private var sortMode: SortMode = .topCPU
    private var freezeEntries: [FreezeEntry] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Process Monitor"

        tableView.register(NXProjectTableCell.self,
                           forCellReuseIdentifier: NXProjectTableCell.reuseIdentifier())

        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .refresh,
                            target: self,
                            action: #selector(refreshProcesses)),
            UIBarButtonItem(title: "Tasks",
                            style: .plain,
                            target: self,
                            action: #selector(presentTaskManagerActions))
        ]

        navigationItem.leftBarButtonItem = UIBarButtonItem(title: sortMode.title,
                                                           style: .plain,
                                                           target: self,
                                                           action: #selector(cycleSortMode))

        cpuCoreCount = max(1, queryCPUCoreCountViaSysctl())
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshProcesses()
        timer = Timer.scheduledTimer(timeInterval: 2.0,
                                     target: self,
                                     selector: #selector(reloadProcessTable),
                                     userInfo: nil,
                                     repeats: true)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer?.invalidate()
        timer = nil
    }

    @objc private func cycleSortMode() {
        let next = (sortMode.rawValue + 1) % SortMode.allCases.count
        sortMode = SortMode(rawValue: next) ?? .topCPU
        navigationItem.leftBarButtonItem?.title = sortMode.title
        recomputeDisplayedProcesses()
        tableView.reloadData()
    }

    @objc private func presentTaskManagerActions() {
        let alert = UIAlertController(title: "Task Manager",
                                      message: "Bulk actions",
                                      preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "Refresh Now", style: .default) { _ in
            self.refreshProcesses()
        })

        alert.addAction(UIAlertAction(title: "Suspend All Running", style: .default) { _ in
            let targets = self.displayedProcesses.filter { !$0.isSuspended }
            targets.forEach { _ = $0.suspend() }
            self.refreshProcesses()
            NotificationServer.NotifyUser(level: .success,
                                          notification: "Suspended \(targets.count) process(es)")
        })

        alert.addAction(UIAlertAction(title: "Resume All Suspended", style: .default) { _ in
            let targets = self.displayedProcesses.filter { $0.isSuspended }
            targets.forEach { _ = $0.resume() }
            self.refreshProcesses()
            NotificationServer.NotifyUser(level: .success,
                                          notification: "Resumed \(targets.count) process(es)")
        })

        alert.addAction(UIAlertAction(title: "Terminate Suspended", style: .destructive) { _ in
            let targets = self.displayedProcesses.filter { $0.isSuspended }
            targets.forEach { _ = $0.terminate() }
            self.refreshProcesses()
            NotificationServer.NotifyUser(level: .success,
                                          notification: "Terminated \(targets.count) suspended process(es)")
        })

        alert.addAction(UIAlertAction(title: "Terminate Top CPU Process", style: .destructive) { _ in
            guard let target = self.displayedProcesses.max(by: {
                (self.statsByPid[$0.pid]?.cpuPercent ?? 0) < (self.statsByPid[$1.pid]?.cpuPercent ?? 0)
            }) else { return }
            _ = target.terminate()
            self.refreshProcesses()
        })

        alert.addAction(UIAlertAction(title: "Show Freeze List", style: .default) { _ in
            let lines = self.freezeEntries.map { e in
                "pid=\(e.pid) addr=0x\(String(e.address, radix: 16)) len=\(e.bytes.count)"
            }
            let message = lines.isEmpty ? "No active freeze entries" : lines.joined(separator: "\n")
            let info = UIAlertController(title: "Freeze List", message: message, preferredStyle: .alert)
            info.addAction(UIAlertAction(title: "Clear", style: .destructive) { _ in
                self.freezeEntries.removeAll()
            })
            info.addAction(UIAlertAction(title: "OK", style: .cancel))
            self.present(info, animated: true)
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItems?.last
        }

        present(alert, animated: true)
    }

    @objc func refreshProcesses() {
        refreshProcessStats()
        tableView.reloadData()
    }

    @objc private func reloadProcessTable() {
        applyFreezeEntries()
        refreshProcessStats()
        tableView.reloadData()
    }

    private func sortedProcessList(from processes: [LDEProcess]) -> [LDEProcess] {
        switch sortMode {
        case .topCPU:
            return processes.sorted {
                let l = statsByPid[$0.pid]?.cpuPercent ?? 0
                let r = statsByPid[$1.pid]?.cpuPercent ?? 0
                if l == r { return $0.pid < $1.pid }
                return l > r
            }
        case .topMemory:
            return processes.sorted {
                let l = statsByPid[$0.pid]?.residentBytes ?? 0
                let r = statsByPid[$1.pid]?.residentBytes ?? 0
                if l == r { return $0.pid < $1.pid }
                return l > r
            }
        case .pid:
            return processes.sorted { $0.pid < $1.pid }
        }
    }

    private func recomputeDisplayedProcesses() {
        displayedProcesses = sortedProcessList(from: Array(LDEProcessManager.shared().processes.values))
    }

    private func refreshProcessStats() {
        let nowUptimeNs = monotonicUptimeNanoseconds()
        let elapsedNs: UInt64? = {
            guard let last = lastRefreshUptimeNs, nowUptimeNs > last else { return nil }
            return nowUptimeNs - last
        }()

        var currentSnapshots: [Int32: ProcessSnapshot] = [:]
        var computedStats: [Int32: ProcessStats] = [:]

        for process in LDEProcessManager.shared().processes.values {
            guard let snapshot = readSnapshot(forPID: process.pid) else { continue }

            currentSnapshots[process.pid] = snapshot
            let cpuPercent: Double

            if let previous = previousSnapshots[process.pid],
               let elapsedNs,
               elapsedNs > 0,
               snapshot.totalTimeNs >= previous.totalTimeNs {
                let deltaTime = snapshot.totalTimeNs - previous.totalTimeNs
                cpuPercent = min(999.0, (Double(deltaTime) / Double(elapsedNs)) * 100.0)
            } else {
                cpuPercent = 0
            }

            computedStats[process.pid] = ProcessStats(cpuPercent: cpuPercent,
                                                      residentBytes: snapshot.residentBytes)
        }

        previousSnapshots = currentSnapshots
        statsByPid = computedStats
        lastRefreshUptimeNs = nowUptimeNs
        recomputeDisplayedProcesses()
    }

    private func readSnapshot(forPID pid: Int32) -> ProcessSnapshot? {
        var usage = rusage_info_v2()
        let result = withUnsafeMutablePointer(to: &usage) { pointer in
            pointer.withMemoryRebound(to: UInt8.self,
                                      capacity: MemoryLayout<rusage_info_v2>.size) { bytePointer in
                proc_pid_rusage(pid, RUSAGE_INFO_V2, bytePointer)
            }
        }

        guard result == 0 else { return nil }
        return ProcessSnapshot(totalTimeNs: usage.ri_user_time + usage.ri_system_time,
                               residentBytes: usage.ri_resident_size)
    }

    private func monotonicUptimeNanoseconds() -> UInt64 {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)

        let now = mach_absolute_time()
        guard info.denom != 0 else { return now }
        return now * UInt64(info.numer) / UInt64(info.denom)
    }

    private func queryCPUCoreCountViaSysctl() -> Int32 {
        var mib: [Int32] = [NXSysctl.ctlHW, NXSysctl.hwNCPU]
        var cpuCount: Int32 = 1
        var size = MemoryLayout<Int32>.size

        let ret = mib.withUnsafeMutableBufferPointer { buffer -> Int32 in
            guard let base = buffer.baseAddress else { return -1 }
            return sysctl(base, u_int(mib.count), &cpuCount, &size, nil, 0)
        }

        if ret != 0 || cpuCount <= 0 { return 1 }
        return cpuCount
    }

    private func formattedMemory(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        displayedProcesses.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard indexPath.row < displayedProcesses.count else {
            return UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        }

        let process = displayedProcesses[indexPath.row]
        let stats = statsByPid[process.pid]
        let status = process.isSuspended ? "Suspended" : "Running"

        let cell = tableView.dequeueReusableCell(withIdentifier: NXProjectTableCell.reuseIdentifier(),
                                                 for: indexPath) as! NXProjectTableCell
        cell.configure(withDisplayName: process.displayName ?? "Unknown",
                       withBundleIdentifier: "PID: \(process.pid) | \(status) | CPU: \(String(format: "%.1f%%", stats?.cpuPercent ?? 0)) | MEM: \(formattedMemory(stats?.residentBytes ?? 0)) | Cores: \(cpuCoreCount)",
                       withAppIcon: nil,
                       showAppIcon: false,
                       showBundleID: true,
                       showArrow: true)
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.row < displayedProcesses.count else { return }

        let process = displayedProcesses[indexPath.row]
        let alert = UIAlertController(title: "Process: \(process.displayName ?? "Unknown")",
                                      message: "PID: \(process.pid)\nBundle: \(process.bundleIdentifier ?? "N/A")",
                                      preferredStyle: .actionSheet)

        if process.isSuspended {
            alert.addAction(UIAlertAction(title: "Resume", style: .default) { _ in
                _ = process.resume()
                self.refreshProcesses()
            })
        } else {
            alert.addAction(UIAlertAction(title: "Suspend", style: .default) { _ in
                _ = process.suspend()
                self.refreshProcesses()
            })
        }

        alert.addAction(UIAlertAction(title: "Read Memory", style: .default) { _ in
            self.presentMemoryReadPrompt(for: process)
        })

        alert.addAction(UIAlertAction(title: "Edit Memory (Hex)", style: .default) { _ in
            self.presentMemoryEditPrompt(for: process)
        })

        alert.addAction(UIAlertAction(title: "Write Typed Value", style: .default) { _ in
            self.presentTypedWritePrompt(for: process)
        })

        alert.addAction(UIAlertAction(title: "Freeze Hex Value", style: .default) { _ in
            self.presentFreezePrompt(for: process)
        })

        alert.addAction(UIAlertAction(title: "Launch New Window Clone", style: .default) { _ in
            guard let bid = process.bundleIdentifier, !bid.isEmpty else {
                NotificationServer.NotifyUser(level: .error, notification: "No bundle identifier for selected process")
                return
            }
            let newPID = LDEProcessManager.shared().spawnProcess(withBundleIdentifier: bid,
                                                                 withKernelSurfaceProcess: kernel_proc(),
                                                                 doRestartIfRunning: false,
                                                                 outPipe: nil,
                                                                 in: nil,
                                                                 enableDebugging: true,
                                                                 forceNewInstance: true)
            if newPID > 0 {
                NotificationServer.NotifyUser(level: .success, notification: "Launched cloned window pid \(newPID)")
            } else {
                NotificationServer.NotifyUser(level: .error, notification: "Failed to launch cloned window")
            }
            self.refreshProcesses()
        })

        alert.addAction(UIAlertAction(title: "Terminate", style: .destructive) { _ in
            _ = process.terminate()
            self.refreshProcesses()
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            let sourceCell = tableView.cellForRow(at: indexPath)
            popover.sourceView = sourceCell ?? tableView
            popover.sourceRect = sourceCell?.bounds ?? CGRect(x: tableView.bounds.midX,
                                                               y: tableView.bounds.midY,
                                                               width: 1,
                                                               height: 1)
        }

        present(alert, animated: true)
    }

    private func presentMemoryReadPrompt(for process: LDEProcess) {
        let prompt = UIAlertController(title: "Read Memory",
                                       message: "Address: hex (0x...) / Length: decimal or 0x...",
                                       preferredStyle: .alert)

        prompt.addTextField {
            $0.placeholder = "Address (hex)"
            $0.autocapitalizationType = .none
            $0.autocorrectionType = .no
        }

        prompt.addTextField {
            $0.placeholder = "Length (e.g. 64 or 0x40)"
            $0.keyboardType = .numbersAndPunctuation
            $0.autocapitalizationType = .none
            $0.autocorrectionType = .no
        }

        prompt.addAction(UIAlertAction(title: "Read", style: .default) { _ in
            let addressText = prompt.textFields?[0].text ?? ""
            let lengthText = prompt.textFields?[1].text ?? ""

            do {
                let address = try self.parseHexAddress(addressText)
                let length = try self.parseLength(lengthText)
                let bytes = try self.readMemory(pid: process.pid, address: address, length: length)
                self.presentHexDump(bytes: bytes, address: address, process: process)
            } catch {
                NotificationServer.NotifyUser(level: .error,
                                              notification: "Memory read failed: \(error.localizedDescription)")
            }
        })

        prompt.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(prompt, animated: true)
    }

    private func presentHexDump(bytes: [UInt8], address: UInt64, process: LDEProcess) {
        let capped = Array(bytes.prefix(512))
        let hex = capped.enumerated().map { idx, byte -> String in
            if idx % 16 == 0 {
                return String(format: "\n0x%08llx: %02X", address + UInt64(idx), byte)
            }
            return String(format: " %02X", byte)
        }.joined()

        let ascii = capped.map { b in
            (32...126).contains(Int(b)) ? String(UnicodeScalar(Int(b))!) : "."
        }.joined()

        let suffix = bytes.count > capped.count ? "\n\n(truncated to \(capped.count) bytes)" : ""

        let dump = UIAlertController(title: "Read \(bytes.count) bytes from pid \(process.pid)",
                                     message: (hex.isEmpty ? "(empty)" : hex) + "\n\nASCII:\n" + ascii + suffix,
                                     preferredStyle: .alert)
        dump.addAction(UIAlertAction(title: "OK", style: .default))
        present(dump, animated: true)
    }

    private func presentMemoryEditPrompt(for process: LDEProcess) {
        let prompt = UIAlertController(title: "Edit Memory (Hex)",
                                       message: "Address: hex (example 0x100000000)\nValue: hex bytes (example DE AD BE EF)",
                                       preferredStyle: .alert)

        prompt.addTextField {
            $0.placeholder = "Address (hex)"
            $0.autocapitalizationType = .none
            $0.autocorrectionType = .no
        }

        prompt.addTextField {
            $0.placeholder = "Bytes (hex)"
            $0.autocapitalizationType = .allCharacters
            $0.autocorrectionType = .no
        }

        prompt.addAction(UIAlertAction(title: "Write", style: .destructive) { _ in
            let addressText = prompt.textFields?[0].text ?? ""
            let bytesText = prompt.textFields?[1].text ?? ""

            do {
                let address = try self.parseHexAddress(addressText)
                let bytes = try self.parseHexBytes(bytesText)
                try self.writeMemory(pid: process.pid,
                                     address: address,
                                     bytes: bytes,
                                     flags: .defaultWritePatch)
                NotificationServer.NotifyUser(level: .success,
                                              notification: "Wrote \(bytes.count) bytes to pid \(process.pid) @ 0x\(String(address, radix: 16))")
            } catch {
                NotificationServer.NotifyUser(level: .error,
                                              notification: "Memory write failed: \(error.localizedDescription)")
            }
        })

        prompt.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(prompt, animated: true)
    }

    private func presentTypedWritePrompt(for process: LDEProcess) {
        let typeSelector = UIAlertController(title: "Write Typed Value",
                                             message: "Choose type",
                                             preferredStyle: .actionSheet)

        let items: [(String, TypedValueKind)] = [
            ("UInt8", .u8), ("UInt16", .u16), ("UInt32", .u32), ("UInt64", .u64),
            ("Int32", .i32), ("Int64", .i64), ("Float32", .f32), ("Float64", .f64)
        ]

        for (title, kind) in items {
            typeSelector.addAction(UIAlertAction(title: title, style: .default) { _ in
                self.presentTypedWriteInput(for: process, kind: kind)
            })
        }

        typeSelector.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = typeSelector.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        }

        present(typeSelector, animated: true)
    }

    private enum TypedValueKind {
        case u8, u16, u32, u64, i32, i64, f32, f64
    }

    private func presentTypedWriteInput(for process: LDEProcess, kind: TypedValueKind) {
        let prompt = UIAlertController(title: "Write \(kind)",
                                       message: "Address: hex / Value: decimal",
                                       preferredStyle: .alert)

        prompt.addTextField { $0.placeholder = "Address (hex)" }
        prompt.addTextField { $0.placeholder = "Value" }

        prompt.addAction(UIAlertAction(title: "Write", style: .destructive) { _ in
            let addressText = prompt.textFields?[0].text ?? ""
            let valueText = prompt.textFields?[1].text ?? ""

            do {
                let address = try self.parseHexAddress(addressText)
                let bytes = try self.serializeTypedValue(kind: kind, raw: valueText)
                try self.writeMemory(pid: process.pid,
                                     address: address,
                                     bytes: bytes,
                                     flags: .defaultWritePatch)
                NotificationServer.NotifyUser(level: .success,
                                              notification: "Wrote \(bytes.count) typed bytes to pid \(process.pid)")
            } catch {
                NotificationServer.NotifyUser(level: .error,
                                              notification: "Typed write failed: \(error.localizedDescription)")
            }
        })

        prompt.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(prompt, animated: true)
    }


    private func presentFreezePrompt(for process: LDEProcess) {
        let prompt = UIAlertController(title: "Freeze Hex Value",
                                       message: "Address + hex bytes will be rewritten every refresh",
                                       preferredStyle: .alert)
        prompt.addTextField { $0.placeholder = "Address (hex)" }
        prompt.addTextField { $0.placeholder = "Bytes (hex)" }

        prompt.addAction(UIAlertAction(title: "Add", style: .default) { _ in
            do {
                let address = try self.parseHexAddress(prompt.textFields?[0].text ?? "")
                let bytes = try self.parseHexBytes(prompt.textFields?[1].text ?? "")
                self.freezeEntries.append(FreezeEntry(pid: process.pid, address: address, bytes: bytes))
                NotificationServer.NotifyUser(level: .success,
                                              notification: "Freeze entry added (pid \(process.pid))")
            } catch {
                NotificationServer.NotifyUser(level: .error,
                                              notification: "Freeze entry failed: \(error.localizedDescription)")
            }
        })
        prompt.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(prompt, animated: true)
    }

    private func applyFreezeEntries() {
        if freezeEntries.isEmpty { return }

        freezeEntries = freezeEntries.filter { entry in
            do {
                try self.writeMemory(pid: entry.pid,
                                     address: entry.address,
                                     bytes: entry.bytes,
                                     flags: .defaultWritePatch)
                return true
            } catch {
                return false
            }
        }
    }

    private enum MemoryEditError: LocalizedError {
        case invalidAddress
        case invalidBytes
        case emptyBytes
        case invalidLength
        case invalidTypedValue
        case taskForPidFailed(kern_return_t)
        case vmReadFailed(kern_return_t)
        case vmProtectFailed(kern_return_t)
        case vmWriteFailed(kern_return_t)

        var errorDescription: String? {
            switch self {
            case .invalidAddress:
                return "Invalid address hex string."
            case .invalidBytes:
                return "Invalid bytes hex string."
            case .emptyBytes:
                return "No bytes were provided."
            case .invalidLength:
                return "Invalid length value."
            case .invalidTypedValue:
                return "Invalid typed value."
            case .taskForPidFailed(let kr):
                return "task_for_pid failed (\(kr))."
            case .vmReadFailed(let kr):
                return "mach_vm_read_overwrite failed (\(kr))."
            case .vmProtectFailed(let kr):
                return "mach_vm_protect failed (\(kr))."
            case .vmWriteFailed(let kr):
                return "mach_vm_write failed (\(kr))."
            }
        }
    }

    private func parseHexAddress(_ raw: String) throws -> UInt64 {
        let normalized = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "0x", with: "")

        guard !normalized.isEmpty, let value = UInt64(normalized, radix: 16) else {
            throw MemoryEditError.invalidAddress
        }
        return value
    }

    private func parseLength(_ raw: String) throws -> Int {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.hasPrefix("0x") {
            let hex = String(normalized.dropFirst(2))
            guard let value = Int(hex, radix: 16), value > 0, value <= 4096 else {
                throw MemoryEditError.invalidLength
            }
            return value
        }

        guard let value = Int(normalized), value > 0, value <= 4096 else {
            throw MemoryEditError.invalidLength
        }
        return value
    }

    private func parseHexBytes(_ raw: String) throws -> [UInt8] {
        let normalized = raw
            .replacingOccurrences(of: "0x", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else { throw MemoryEditError.emptyBytes }
        guard normalized.count % 2 == 0 else { throw MemoryEditError.invalidBytes }

        var result: [UInt8] = []
        result.reserveCapacity(normalized.count / 2)

        var idx = normalized.startIndex
        while idx < normalized.endIndex {
            let next = normalized.index(idx, offsetBy: 2)
            let pair = String(normalized[idx..<next])
            guard let byte = UInt8(pair, radix: 16) else { throw MemoryEditError.invalidBytes }
            result.append(byte)
            idx = next
        }

        return result
    }

    private func serializeTypedValue(kind: TypedValueKind, raw: String) throws -> [UInt8] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        func toLE<T>(_ value: T) -> [UInt8] {
            withUnsafeBytes(of: value) { Array($0) }
        }

        switch kind {
        case .u8:
            guard let v = UInt8(trimmed) else { throw MemoryEditError.invalidTypedValue }
            return [v]
        case .u16:
            guard let v = UInt16(trimmed) else { throw MemoryEditError.invalidTypedValue }
            return toLE(v.littleEndian)
        case .u32:
            guard let v = UInt32(trimmed) else { throw MemoryEditError.invalidTypedValue }
            return toLE(v.littleEndian)
        case .u64:
            guard let v = UInt64(trimmed) else { throw MemoryEditError.invalidTypedValue }
            return toLE(v.littleEndian)
        case .i32:
            guard let v = Int32(trimmed) else { throw MemoryEditError.invalidTypedValue }
            return toLE(v.littleEndian)
        case .i64:
            guard let v = Int64(trimmed) else { throw MemoryEditError.invalidTypedValue }
            return toLE(v.littleEndian)
        case .f32:
            guard let v = Float(trimmed) else { throw MemoryEditError.invalidTypedValue }
            return toLE(v.bitPattern.littleEndian)
        case .f64:
            guard let v = Double(trimmed) else { throw MemoryEditError.invalidTypedValue }
            return toLE(v.bitPattern.littleEndian)
        }
    }

    private func taskPort(for pid: Int32) throws -> mach_port_name_t {
        var task: mach_port_name_t = 0
        let tkr = task_for_pid(mach_task_self_, pid, &task)
        guard tkr == KERN_SUCCESS else { throw MemoryEditError.taskForPidFailed(tkr) }
        return task
    }

    private func readMemory(pid: Int32, address: UInt64, length: Int) throws -> [UInt8] {
        let task = try taskPort(for: pid)

        var local = [UInt8](repeating: 0, count: length)
        var outSize: mach_vm_size_t = 0

        let kr: kern_return_t = local.withUnsafeMutableBytes { rawBuffer in
            guard let base = rawBuffer.baseAddress else { return KERN_INVALID_ARGUMENT }
            return mach_vm_read_overwrite(task,
                                          mach_vm_address_t(address),
                                          mach_vm_size_t(length),
                                          mach_vm_address_t(UInt(bitPattern: base)),
                                          &outSize)
        }

        guard kr == KERN_SUCCESS else { throw MemoryEditError.vmReadFailed(kr) }
        return Array(local.prefix(Int(outSize)))
    }

    private func writeMemory(pid: Int32,
                             address: UInt64,
                             bytes: [UInt8],
                             flags: NXKernelVMFlags) throws {
        let task = try taskPort(for: pid)

        let protectKR = mach_vm_protect(task,
                                        mach_vm_address_t(address),
                                        mach_vm_size_t(bytes.count),
                                        0,
                                        vm_prot_t(flags.rawValue))

        var mutableBytes = bytes
        let writeKR: kern_return_t = mutableBytes.withUnsafeMutableBytes { rawBuffer in
            guard let base = rawBuffer.baseAddress else { return KERN_INVALID_ARGUMENT }
            return mach_vm_write(task,
                                 mach_vm_address_t(address),
                                 vm_offset_t(UInt(bitPattern: base)),
                                 mach_msg_type_number_t(bytes.count))
        }

        if writeKR == KERN_SUCCESS { return }
        if protectKR != KERN_SUCCESS { throw MemoryEditError.vmProtectFailed(protectKR) }
        throw MemoryEditError.vmWriteFailed(writeKR)
    }
}
