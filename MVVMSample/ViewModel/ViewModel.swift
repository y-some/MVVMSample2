//
//  ViewModel.swift
//  MVVMSample
//
//  Created by Yasuyuki Someya on 2020/10/17.
//

import Foundation

/// データの取得状態
enum State {
    case loading
    case loaded
    case error(String)
}

/// ViewとModelの間の情報の伝達と、Viewのための状態を保持する役割
class ViewModel {
    // Viewに提供する表示用データオブジェクト
    struct ViewItem: Hashable {
        let title: String
        let link: String
        let source: String
        let pubDate: String?
    }
    private(set) var viewItems = [ViewItem]()

    // 取得状態を扱うオブジェクト
    @Published private(set) var state: State?
    // フィルターのタイトルを画面側で監視するためのオブジェクト
    @Published private(set) var title: String? = FilterType.none.title

    // 現在のフィルター状態を保持
    private var filterType: FilterType = .none {
        didSet {
            title = filterType.title
        }
    }

    // テストのためにModelクラスをDIする
    private let model: ModelProtocol
    init(model: ModelProtocol = Model()) {
        self.model = model
    }

    /// データ取得
    func load(for filterType: FilterType) async {
        self.filterType = filterType
        state = .loading
        
        do {
            let articles = try await model.retrieveItems(for: filterType)
            viewItems = articles.map({ (article) -> ViewItem in
                return ViewItem(title: article.title,
                                link: article.link,
                                source: article.source,
                                pubDate: format(for: article.pubDate))
            })
            state = .loaded
        } catch {
            state = .error(error.localizedDescription)
        }
    }
    
    /// リロード
    func reload() async {
        await load(for: filterType)
    }
}

// MARK: - ユーティリティ関数
extension ViewModel {
    /// Dateから表示用文字列を編集する
    func format(for date: Date?) -> String? {
        guard let date = date else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }
}
