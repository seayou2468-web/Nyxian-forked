/*
 SPDX-License-Identifier: AGPL-3.0-or-later
*/

import UIKit

class ProcessMonitorViewController: UIThemedTableViewController {
    var timer: Timer?

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
        return LDEProcessManager.shared().processes.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let allKeys = Array(LDEProcessManager.shared().processes.keys).sorted { $0.intValue < $1.intValue }
        let pidKey = allKeys[indexPath.row]
        let process = LDEProcessManager.shared().processes[pidKey]!

        let cell = tableView.dequeueReusableCell(withIdentifier: NXProjectTableCell.reuseIdentifier(), for: indexPath) as! NXProjectTableCell

        let status: String = process.isSuspended ? "Suspended" : "Running"

        cell.configure(withDisplayName: process.displayName ?? "Unknown",
                       withBundleIdentifier: "PID: \(process.pid) | \(status)",
                       withAppIcon: nil,
                       showAppIcon: false,
                       showBundleID: true,
                       showArrow: true)
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let allKeys = Array(LDEProcessManager.shared().processes.keys).sorted { $0.intValue < $1.intValue }
        let pidKey = allKeys[indexPath.row]
        let process = LDEProcessManager.shared().processes[pidKey]!

        let alert = UIAlertController(title: "Process: \(process.displayName ?? "Unknown")",
                                      message: "PID: \(process.pid)\\nBundle: \(process.bundleIdentifier ?? "N/A")",
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
