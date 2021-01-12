import CurrencyKit
import XRatesKit
import Foundation
import RxSwift
import RxRelay

class MarketListService {
    private let disposeBag = DisposeBag()
    private var topItemsDisposable: Disposable?

    private let currencyKit: ICurrencyKit
    private let dataSource: IMarketListDataSource

    private let stateRelay = BehaviorRelay<State>(value: .loading)
    private(set) var items = [Item]()

    public var period: MarketListDataSource.Period = .day {
        didSet {
            fetch()
        }
    }

    init(currencyKit: ICurrencyKit, dataSource: IMarketListDataSource) {
        self.currencyKit = currencyKit
        self.dataSource = dataSource

        fetch()
    }

    private func convertItem(rank: Int, topMarket: TopMarket) -> Item {
        Item(
            rank: rank,
            coinCode: topMarket.coin.code,
            coinName: topMarket.coin.title,
            marketCap: topMarket.marketInfo.marketCap,
            price: topMarket.marketInfo.rate,
            diff: topMarket.marketInfo.rateDiffPeriod,
            volume: topMarket.marketInfo.volume)
    }

    private func fetch() {
        topItemsDisposable?.dispose()
        topItemsDisposable = nil

        stateRelay.accept(.loading)

        topItemsDisposable = dataSource.itemsSingle(currencyCode: currency.code, period: period)
                .subscribe(onSuccess: { [weak self] in self?.sync(items: $0) })

        topItemsDisposable?.disposed(by: disposeBag)
    }

    private func sync(items: [TopMarket]) {
        self.items = items.enumerated().map { (index, topMarket) in
            convertItem(rank: index + 1, topMarket: topMarket)
        }

        stateRelay.accept(.loaded)
    }

}

extension MarketListService {

    public var currency: Currency {
        currencyKit.baseCurrency
    }

    public var periods: [MarketListDataSource.Period] {
        dataSource.periods
    }

    public var sortingFields: [MarketListDataSource.SortingField] {
        dataSource.sortingFields
    }

    public var stateObservable: Observable<State> {
        stateRelay.asObservable()
    }

    public func refresh() {
        fetch()
    }

}

extension MarketListService {

    enum State {
        case loaded
        case loading
        case error(error: Error)
    }

    struct Item {
        let rank: Int
        let coinCode: String
        let coinName: String
        let marketCap: Decimal
        let price: Decimal
        let diff: Decimal
        let volume: Decimal
    }

}