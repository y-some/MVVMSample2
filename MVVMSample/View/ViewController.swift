//
//  ViewController.swift
//  MVVMSample
//
//  Created by Yasuyuki Someya on 2020/10/17.
//

import UIKit
import Combine
import SafariServices

class ViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!

    private var cancellables = Set<AnyCancellable>()
    private let viewModel = ViewModel()
    private typealias Snapshot = NSDiffableDataSourceSnapshot<Int, ViewModel.ViewItem>
    private typealias DataSource = UITableViewDiffableDataSource<Int, ViewModel.ViewItem>
    private var dataSource: DataSource?

    // MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.delegate = self
        tableView.tableFooterView = UIView(frame: .zero)
        tableView.rowHeight = UITableView.automaticDimension
        // 引っ張って更新
        tableView.refreshControl = UIRefreshControl()
        tableView.refreshControl?.addTarget(self, action: #selector(refresh(sender:)), for: .valueChanged)

        // 状態監視
        viewModel.$state
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let state else { return }
                switch state {
                case .loading:
                    self?.beginRefreshing()
                case .loaded:
                    self?.tableView.refreshControl?.endRefreshing()
                    self?.apply()
                case .error(let message):
                    self?.tableView.refreshControl?.endRefreshing()
                    self?.showErrorAlert(with: message)
                }
            }
            .store(in: &cancellables)
        
        // 初回ロード
        title = viewModel.filterType.title
        Task {
            await viewModel.load(for: .none)
        }
    }
}

// MARK: - UITableViewの処理群
extension ViewController: UITableViewDelegate {
    ///　cellの選択時
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.row < viewModel.viewItems.count,
              let url = URL(string: viewModel.viewItems[indexPath.row].link) else {
            return
        }
        let safariVC = SFSafariViewController.init(url: url)
        safariVC.dismissButtonStyle = .close
        self.present(safariVC, animated: true, completion: nil)
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - Custom Method
extension ViewController {
    /// TableViewへのデータ投入
    private func apply() {
        var snapshot = Snapshot()
        snapshot.appendSections([0])
        snapshot.appendItems(viewModel.viewItems, toSection: 0)
        dataSource?.defaultRowAnimation = .fade
        if let dataSource {
            dataSource.apply(snapshot, animatingDifferences: true)
        } else {
            dataSource = DataSource(
                tableView: tableView,
                cellProvider: { [weak self] tableView, indexPath, item in
                    self?.getCell(tableView, at: indexPath, item: item)
                }
            )
            dataSource?.applySnapshotUsingReloadData(snapshot)
        }
    }
    
    ///　cellを返す
    private func getCell(_ tableView: UITableView, at indexPath: IndexPath, item: ViewModel.ViewItem) -> UITableViewCell {
        let identifier = "TableViewCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath)
        let item = viewModel.viewItems[indexPath.row]
        cell.textLabel?.text = item.title
        cell.detailTextLabel?.text = "[\(item.source)] \(item.pubDate ?? "")"
        return cell
    }
    
    /// フィルタボタンtap
    @IBAction private func tappedFilterButton(_ sender: Any) {
        showActionSheet()
    }

    /// ActionSheet生成
    private func showActionSheet() {
        let actionSheet = UIAlertController(title: "トピック", message: nil, preferredStyle: UIAlertController.Style.actionSheet)
        for filterType in FilterType.allCases {
            let action = UIAlertAction(title: filterType.title, style: UIAlertAction.Style.default) { [weak self] _ in
                self?.title = self?.viewModel.filterType.title
                Task {
                    await self?.viewModel.load(for: filterType)
                }
            }
            actionSheet.addAction(action)
        }
        let close = UIAlertAction(title: "閉じる", style: UIAlertAction.Style.destructive) { _ in }
        actionSheet.addAction(close)
        present(actionSheet, animated: true, completion: nil)
    }
    
    /// UITableViewを引っ張って更新
    @objc private func refresh(sender: UIRefreshControl) {
        Task {
            await viewModel.reload()
        }
    }
    
    /// refreshControlを表示する
    private func beginRefreshing() {
        guard let refreshControl = tableView.refreshControl else { return }
        tableView.setContentOffset(CGPoint(x: 0, y: tableView.contentOffset.y - refreshControl.frame.height), animated: true)
        refreshControl.beginRefreshing()
    }
    
    /// エラーアラート表示
    private func showErrorAlert(with message: String) {
        let alertVC = UIAlertController(title: "エラー", message: message, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: "閉じる", style: .default))
        present(alertVC, animated: true)
    }
}
