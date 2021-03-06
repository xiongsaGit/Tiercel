//
//  BaseViewController.swift
//  Example
//
//  Created by Daniels on 2018/3/20.
//  Copyright © 2018年 Daniels. All rights reserved.
//

import UIKit

class BaseViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var totalTasksLabel: UILabel!
    @IBOutlet weak var totalSpeedLabel: UILabel!
    @IBOutlet weak var timeRemainingLabel: UILabel!
    @IBOutlet weak var totalProgressLabel: UILabel!
    
    // 由于执行删除running的task，结果是异步回调的，所以最好是用downloadURLStrings作为数据源
    lazy var downloadURLStrings = [String]()

    var downloadManager: TRManager?

    var URLStrings: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        // tableView的设置
        automaticallyAdjustsScrollViewInsets = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableFooterView = UIView()
        tableView.register(UINib(nibName: "DownloadTaskCell", bundle: nil), forCellReuseIdentifier: "cell")
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 164

        // 检查磁盘空间
        let free = UIDevice.current.tr.freeDiskSpaceInBytes / 1024 / 1024
        print("手机剩余储存空间为： \(free)MB")

        TRManager.logLevel = .high
    }

    func updateUI() {
        guard let downloadManager = downloadManager else { return  }
        totalTasksLabel.text = "总任务：\(downloadManager.completedTasks.count)/\(downloadManager.tasks.count)"
        totalSpeedLabel.text = "总速度：\(downloadManager.speed.tr.convertSpeedToString())"
        timeRemainingLabel.text = "剩余时间： \(downloadManager.timeRemaining.tr.convertTimeToString())"
        let per = String(format: "%.2f", downloadManager.progress.fractionCompleted)
        totalProgressLabel.text = "总进度： \(per)"

    }


}

extension BaseViewController {
    @IBAction func totalStart(_ sender: Any) {
        downloadManager?.isStartDownloadImmediately = true
        downloadManager?.totalStart()
    }

    @IBAction func totalSuspend(_ sender: Any) {
        downloadManager?.totalSuspend()
    }

    @IBAction func totalCancel(_ sender: Any) {
        downloadManager?.totalCancel()
    }

    @IBAction func totalDelete(_ sender: Any) {
        downloadManager?.totalRemove(completely: false)
    }

    @IBAction func clearDisk(_ sender: Any) {
        guard let downloadManager = downloadManager else { return  }
        downloadManager.cache.clearDiskCache()
        updateUI()
    }

    @IBAction func taskLimit(_ sender: Any) {
        downloadManager?.maxConcurrentTasksLimit = 2
    }
    @IBAction func cancelTaskLimit(_ sender: Any) {
        downloadManager?.maxConcurrentTasksLimit = Int.max
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate
extension BaseViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return downloadURLStrings.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell") as! DownloadTaskCell

        let URLString = downloadURLStrings[indexPath.row]

        guard let downloadManager = downloadManager,
            let task = downloadManager.fetchTask(URLString)
            else { return cell }

        var image: UIImage = #imageLiteral(resourceName: "resume")
        switch task.status {
        case .running:
            image = #imageLiteral(resourceName: "resume")
        case .suspend, .completed:
            image = #imageLiteral(resourceName: "suspend")
        default: break
        }
        cell.controlButton.setImage(image, for: .normal)

        cell.titleLabel.text = task.fileName

        cell.updateProgress(task: task)


        // task的闭包引用了cell，所以这里的task要用weak
        cell.tapClosure = { [weak self, weak task] cell in
            guard let strongSelf = self,
                let task = task
                else { return }
            switch task.status {
            case .running:
                strongSelf.downloadManager?.suspend(URLString)
                cell.controlButton.setImage(#imageLiteral(resourceName: "suspend"), for: .normal)
            case .suspend:
                strongSelf.downloadManager?.start(URLString)
                cell.controlButton.setImage(#imageLiteral(resourceName: "resume"), for: .normal)
            default: break
            }
        }

        return cell
    }

    // 每个cell中的状态更新，应该在willDisplay中执行
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let URLString = downloadURLStrings.safeObjectAtIndex(indexPath.row),
            let task = downloadManager?.fetchTask(URLString)
            else { return }

        task.progress { [weak cell] (task) in
            guard let cell = cell as? DownloadTaskCell else { return }
            cell.updateProgress(task: task)
            }
            .success({ [weak cell] (task) in
                guard let cell = cell as? DownloadTaskCell else { return }
                cell.controlButton.setImage(#imageLiteral(resourceName: "suspend"), for: .normal)
            })
            .failure({ [weak cell] (task) in
                guard let cell = cell as? DownloadTaskCell else { return }
                cell.controlButton.setImage(#imageLiteral(resourceName: "suspend"), for: .normal)
            })
    }

    // 由于cell是循环利用的，不在可视范围内的cell，不应该去更新cell的状态
    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let URLString = downloadURLStrings.safeObjectAtIndex(indexPath.row),
            let task = downloadManager?.fetchTask(URLString)
            else { return }

        task.progress { _ in }.success({ _ in }).failure({ _ in})
    }

}
