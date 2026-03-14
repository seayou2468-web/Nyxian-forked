/*
 SPDX-License-Identifier: AGPL-3.0-or-later
*/

import UIKit

class ProcessMonitorViewController: UIThemedTableViewController {
    var processes: [LDEProcess] = []
    var timer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Process Monitor"
        self.tableView.register(NXProjectTableCell.self, forCellReuseIdentifier: NXProjectTableCell.reuseIdentifier())

        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(refreshProcesses))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshProcesses()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refreshProcesses()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer?.invalidate()
    }

    @objc func refreshProcesses() {
        let allProcesses = LDEProcessManager.shared().processes.values
        self.processes = Array(allProcesses).sorted { $0.pid < $1.pid }
        self.tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return processes.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let process = processes[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: NXProjectTableCell.reuseIdentifier(), for: indexPath) as! NXProjectTableCell

        let status: String
        if process.isSuspended {
            status = "Suspended"
        } else {
            status = "Running"
        }

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
        let process = processes[indexPath.row]

        let alert = UIAlertController(title: "Process: \(process.displayName ?? "Unknown")", message: "PID: \(process.pid)\\nBundle: \(process.bundleIdentifier ?? "N/A")", preferredStyle: .actionSheet)

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

        alert.addAction(UIAlertAction(title: "Terminate", style: .destructive) { _ in
            process.terminate()
            self.refreshProcesses()
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = tableView.cellForRow(at: indexPath)
            popover.sourceRect = tableView.cellForRow(at: indexPath)?.bounds ?? .zero
        }

        self.present(alert, animated: true)
    }
}
