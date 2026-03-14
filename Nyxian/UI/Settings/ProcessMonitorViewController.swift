/*
 SPDX-License-Identifier: AGPL-3.0-or-later
*/

import UIKit

class ProcessMonitorViewController: UIThemedTableViewController {
    var timer: Timer?

    private func sortedProcesses() -> [LDEProcess] {
        let manager = LDEProcessManager.shared()
        let keys = manager.processes.allKeys
            .compactMap { $0 as? NSNumber }
            .sorted { $0.int32Value < $1.int32Value }

        return keys.compactMap { key in
            manager.processes.object(forKey: key) as? LDEProcess
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Process Monitor"
        self.tableView.register(NXProjectTableCell.self, forCellReuseIdentifier: NXProjectTableCell.reuseIdentifier())

        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(refreshProcesses))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tableView.reloadData()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.tableView.reloadData()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer?.invalidate()
    }

    @objc func refreshProcesses() {
        self.tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sortedProcesses().count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let process = sortedProcesses()[indexPath.row]

        let cell = tableView.dequeueReusableCell(withIdentifier: NXProjectTableCell.reuseIdentifier(), for: indexPath) as! NXProjectTableCell

        let status: String = process.isSuspended ? "Suspended" : "Running"
        let displayName = (process.displayName as String?) ?? "Unknown"

        cell.configure(withDisplayName: displayName,
                       withBundleIdentifier: "PID: \(process.pid) | \(status)",
                       withAppIcon: nil,
                       showAppIcon: false,
                       showBundleID: true,
                       showArrow: true)
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let process = sortedProcesses()[indexPath.row]
        let displayName = (process.displayName as String?) ?? "Unknown"
        let bundleIdentifier = (process.bundleIdentifier as String?) ?? "N/A"

        let alert = UIAlertController(title: "Process: \(displayName)",
                                      message: "PID: \(process.pid)\\nBundle: \(bundleIdentifier)",
                                      preferredStyle: .actionSheet)

        if process.isSuspended {
            alert.addAction(UIAlertAction(title: "Resume", style: .default) { _ in
                process.resume()
                self.tableView.reloadData()
            })
        } else {
            alert.addAction(UIAlertAction(title: "Suspend", style: .default) { _ in
                process.suspend()
                self.tableView.reloadData()
            })
        }

        alert.addAction(UIAlertAction(title: "Terminate", style: .destructive) { _ in
            process.terminate()
            self.tableView.reloadData()
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = tableView.cellForRow(at: indexPath)
            popover.sourceRect = tableView.cellForRow(at: indexPath)?.bounds ?? .zero
        }

        self.present(alert, animated: true)
    }
}
