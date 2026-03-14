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

        static let read  = NXKernelVMFlags(rawValue: 0x01)
        static let write = NXKernelVMFlags(rawValue: 0x02)

        static let defaultWritePatch: NXKernelVMFlags = [.read, .write]
    }

    private struct ProcessSnapshot {
        let totalTimeNs: UInt64
        let residentBytes: UInt64
    }

    private struct ProcessStats {
        let cpuPercent: Double
        let residentBytes: UInt64
    }

    private var previousSnapshots: [Int32: ProcessSnapshot] = [:]
    private var statsByPid: [Int32: ProcessStats] = [:]
    private var displayedProcesses: [LDEProcess] = []
    private var lastRefreshUptimeNs: UInt64?
    private var cpuCoreCount: Int32 = 1
    private var isTopSortEnabled: Bool = true

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Process Monitor"
        self.tableView.register(NXProjectTableCell.self, forCellReuseIdentifier: NXProjectTableCell.reuseIdentifier())

        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .refresh,
                                                                  target: self,
                                                                  action: #selector(refreshProcesses))
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Top",
                                                                 style: .plain,
                                                                 target: self,
                                                                 action: #selector(toggleTopSort))

        self.cpuCoreCount = max(1, queryCPUCoreCountViaSysctl())
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.refreshProcesses()
        timer = Timer.scheduledTimer(timeInterval: 2.0,
                                     target: self,
                                     selector: #selector(reloadProcessTable),
                                     userInfo: nil,
                                     repeats: true)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer?.invalidate()
    }

    @objc func refreshProcesses() {
        refreshProcessStats()
        self.tableView.reloadData()
    }

    @objc private func reloadProcessTable() {
        refreshProcessStats()
        self.tableView.reloadData()
    }

    @objc private func toggleTopSort() {
        isTopSortEnabled.toggle()
        navigationItem.leftBarButtonItem?.title = isTopSortEnabled ? "Top" : "PID"
        recomputeDisplayedProcesses()
        self.tableView.reloadData()
    }

    private func sortedProcessList(from processes: [LDEProcess]) -> [LDEProcess] {
        if isTopSortEnabled {
            return processes.sorted {
                let lhsCPU = statsByPid[$0.pid]?.cpuPercent ?? 0
                let rhsCPU = statsByPid[$1.pid]?.cpuPercent ?? 0
                if lhsCPU == rhsCPU {
                    return $0.pid < $1.pid
                }
                return lhsCPU > rhsCPU
            }
        }

        return processes.sorted { $0.pid < $1.pid }
    }

    private func recomputeDisplayedProcesses() {
        let raw = Array(LDEProcessManager.shared().processes.values)
        displayedProcesses = sortedProcessList(from: raw)
    }

    private func refreshProcessStats() {
        let nowUptimeNs = monotonicUptimeNanoseconds()
        let elapsedNs: UInt64?

        if let last = lastRefreshUptimeNs, nowUptimeNs > last {
            elapsedNs = nowUptimeNs - last
        } else {
            elapsedNs = nil
        }

        var currentSnapshots: [Int32: ProcessSnapshot] = [:]
        var computedStats: [Int32: ProcessStats] = [:]

        for process in LDEProcessManager.shared().processes.values {
            guard let snapshot = readSnapshot(forPID: process.pid) else {
                continue
            }

            currentSnapshots[process.pid] = snapshot

            let cpuPercent: Double
            if let previous = previousSnapshots[process.pid],
               let elapsedNs,
               elapsedNs > 0,
               snapshot.totalTimeNs >= previous.totalTimeNs {
                let deltaTime = snapshot.totalTimeNs - previous.totalTimeNs
                let raw = (Double(deltaTime) / Double(elapsedNs)) * 100.0
                cpuPercent = min(999.0, raw)
            } else {
                cpuPercent = 0
            }

            computedStats[process.pid] = ProcessStats(cpuPercent: cpuPercent,
                                                      residentBytes: snapshot.residentBytes)
        }

        self.previousSnapshots = currentSnapshots
        self.statsByPid = computedStats
        self.lastRefreshUptimeNs = nowUptimeNs
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

        guard result == 0 else {
            return nil
        }

        let totalTimeNs = usage.ri_user_time + usage.ri_system_time
        return ProcessSnapshot(totalTimeNs: totalTimeNs,
                               residentBytes: usage.ri_resident_size)
    }

    private func monotonicUptimeNanoseconds() -> UInt64 {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)

        let now = mach_absolute_time()
        if info.denom == 0 {
            return now
        }

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

        if ret != 0 || cpuCount <= 0 {
            return 1
        }

        return cpuCount
    }

    private func formattedMemory(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return displayedProcesses.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard indexPath.row < displayedProcesses.count else {
            return UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        }

        let process = displayedProcesses[indexPath.row]

        let cell = tableView.dequeueReusableCell(withIdentifier: NXProjectTableCell.reuseIdentifier(),
                                                 for: indexPath) as! NXProjectTableCell

        let status: String = process.isSuspended ? "Suspended" : "Running"
        let stats = statsByPid[process.pid]
        let cpuText = String(format: "%.1f%%", stats?.cpuPercent ?? 0)
        let memText = formattedMemory(stats?.residentBytes ?? 0)

        cell.configure(withDisplayName: process.displayName ?? "Unknown",
                       withBundleIdentifier: "PID: \(process.pid) | \(status) | CPU: \(cpuText) | MEM: \(memText) | Cores: \(cpuCoreCount)",
                       withAppIcon: nil,
                       showAppIcon: false,
                       showBundleID: true,
                       showArrow: true)
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard indexPath.row < displayedProcesses.count else {
            return
        }

        let process = displayedProcesses[indexPath.row]

        let alert = UIAlertController(title: "Process: \(process.displayName ?? "Unknown")",
                                      message: "PID: \(process.pid)\nBundle: \(process.bundleIdentifier ?? "N/A")",
                                      preferredStyle: .actionSheet)

        if process.isSuspended {
            alert.addAction(UIAlertAction(title: "Resume", style: .default) { _ in
                process.resume()
                self.refreshProcesses()
            })
        } else {
            alert.addAction(UIAlertAction(title: "Suspend", style: .default) { _ in
                process.suspend()
                self.refreshProcesses()
            })
        }

        alert.addAction(UIAlertAction(title: "Read Memory", style: .default) { _ in
            self.presentMemoryReadPrompt(for: process)
        })

        alert.addAction(UIAlertAction(title: "Edit Memory", style: .default) { _ in
            self.presentMemoryEditPrompt(for: process)
        })

        alert.addAction(UIAlertAction(title: "Terminate", style: .destructive) { _ in
            process.terminate()
            self.refreshProcesses()
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            let sourceCell = tableView.cellForRow(at: indexPath)
            popover.sourceView = sourceCell ?? tableView
            popover.sourceRect = sourceCell?.bounds ?? CGRect(x: tableView.bounds.midX, y: tableView.bounds.midY, width: 1, height: 1)
        }

        self.present(alert, animated: true)
    }

    private func presentMemoryReadPrompt(for process: LDEProcess) {
        let prompt = UIAlertController(title: "Read Memory",
                                       message: "Address: hex (0x...) / Length: decimal or 0x...",
                                       preferredStyle: .alert)

        prompt.addTextField { textField in
            textField.placeholder = "Address (hex)"
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
        }

        prompt.addTextField { textField in
            textField.placeholder = "Length (e.g. 64 or 0x40)"
            textField.keyboardType = .numbersAndPunctuation
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
        }

        prompt.addAction(UIAlertAction(title: "Read", style: .default) { _ in
            let addressText = prompt.textFields?[0].text ?? ""
            let lengthText = prompt.textFields?[1].text ?? ""

            do {
                let address = try self.parseHexAddress(addressText)
                let length = try self.parseLength(lengthText)
                let bytes = try self.readMemory(pid: process.pid, address: address, length: length)
                self.presentHexDump(bytes: bytes,
                                    address: address,
                                    process: process)
            } catch {
                NotificationServer.NotifyUser(level: .error,
                                              notification: "Memory read failed: \(error.localizedDescription)")
            }
        })

        prompt.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        self.present(prompt, animated: true)
    }

    private func presentHexDump(bytes: [UInt8], address: UInt64, process: LDEProcess) {
        let capped = Array(bytes.prefix(512))
        let hex = capped.enumerated().map { idx, byte -> String in
            if idx % 16 == 0 {
                return String(format: "\n0x%08llx: %02X", address + UInt64(idx), byte)
            }
            return String(format: " %02X", byte)
        }.joined()

        let suffix = bytes.count > capped.count ? "\n\n(truncated to \(capped.count) bytes)" : ""

        let dump = UIAlertController(title: "Read \(bytes.count) bytes from pid \(process.pid)",
                                     message: (hex.isEmpty ? "(empty)" : hex) + suffix,
                                     preferredStyle: .alert)
        dump.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(dump, animated: true)
    }

    private func presentMemoryEditPrompt(for process: LDEProcess) {
        let prompt = UIAlertController(title: "Edit Memory",
                                       message: "Address: hex (example 0x100000000)\nValue: hex bytes (example DE AD BE EF)",
                                       preferredStyle: .alert)

        prompt.addTextField { textField in
            textField.placeholder = "Address (hex)"
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
        }

        prompt.addTextField { textField in
            textField.placeholder = "Bytes (hex)"
            textField.autocapitalizationType = .allCharacters
            textField.autocorrectionType = .no
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
        self.present(prompt, animated: true)
    }

    private enum MemoryEditError: LocalizedError {
        case invalidAddress
        case invalidBytes
        case emptyBytes
        case invalidLength
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

        guard !normalized.isEmpty else {
            throw MemoryEditError.emptyBytes
        }

        guard normalized.count % 2 == 0 else {
            throw MemoryEditError.invalidBytes
        }

        var result: [UInt8] = []
        result.reserveCapacity(normalized.count / 2)

        var idx = normalized.startIndex
        while idx < normalized.endIndex {
            let next = normalized.index(idx, offsetBy: 2)
            let pair = String(normalized[idx..<next])
            guard let byte = UInt8(pair, radix: 16) else {
                throw MemoryEditError.invalidBytes
            }
            result.append(byte)
            idx = next
        }

        return result
    }

    private func taskPort(for pid: Int32) throws -> mach_port_name_t {
        var task: mach_port_name_t = 0
        let tkr = task_for_pid(mach_task_self_, pid, &task)
        guard tkr == KERN_SUCCESS else {
            throw MemoryEditError.taskForPidFailed(tkr)
        }
        return task
    }

    private func readMemory(pid: Int32, address: UInt64, length: Int) throws -> [UInt8] {
        let task = try taskPort(for: pid)

        var local = [UInt8](repeating: 0, count: length)
        var outSize: mach_vm_size_t = 0

        let kr: kern_return_t = local.withUnsafeMutableBytes { rawBuffer in
            guard let base = rawBuffer.baseAddress else {
                return KERN_INVALID_ARGUMENT
            }

            return mach_vm_read_overwrite(task,
                                          mach_vm_address_t(address),
                                          mach_vm_size_t(length),
                                          mach_vm_address_t(UInt(bitPattern: base)),
                                          &outSize)
        }

        guard kr == KERN_SUCCESS else {
            throw MemoryEditError.vmReadFailed(kr)
        }

        return Array(local.prefix(Int(outSize)))
    }

    private func writeMemory(pid: Int32,
                             address: UInt64,
                             bytes: [UInt8],
                             flags: NXKernelVMFlags) throws {
        let task = try taskPort(for: pid)

        // Best effort: protect may fail on unaligned/immutable mappings; try write anyway.
        let protectKR = mach_vm_protect(task,
                                        mach_vm_address_t(address),
                                        mach_vm_size_t(bytes.count),
                                        0,
                                        vm_prot_t(flags.rawValue))

        var mutableBytes = bytes
        let writeKR: kern_return_t = mutableBytes.withUnsafeMutableBytes { rawBuffer in
            guard let base = rawBuffer.baseAddress else {
                return KERN_INVALID_ARGUMENT
            }

            return mach_vm_write(task,
                                 mach_vm_address_t(address),
                                 vm_offset_t(UInt(bitPattern: base)),
                                 mach_msg_type_number_t(bytes.count))
        }

        if writeKR == KERN_SUCCESS {
            return
        }

        if protectKR != KERN_SUCCESS {
            throw MemoryEditError.vmProtectFailed(protectKR)
        }

        throw MemoryEditError.vmWriteFailed(writeKR)
    }
}
