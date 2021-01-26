import CurrencyKit
import RxSwift
import RxRelay
import RxCocoa

class MarketOverviewViewModel {
    private let disposeBag = DisposeBag()

    public let service: MarketListService

    private let viewItemsRelay = BehaviorRelay<[Section]>(value: [])
    private let isLoadingRelay = BehaviorRelay<Bool>(value: false)
    private let errorRelay = BehaviorRelay<String?>(value: nil)

    init(service: MarketListService) {
        self.service = service

        subscribe(disposeBag, service.stateObservable) { [weak self] in self?.sync(state: $0) }
    }

    private func sync(state: MarketListService.State) {
        if case .loaded = state {
            syncViewItems()
        }

        if case .loading = state {
            isLoadingRelay.accept(true)
        } else {
            isLoadingRelay.accept(false)
        }

        if case let .error(error: error) = state {
            errorRelay.accept(error.smartDescription)
        } else {
            errorRelay.accept(nil)
        }
    }

    private func sort(items: [MarketListService.Item], by sortingField: MarketListDataSource.SortingField) -> [MarketListService.Item] {
        items.sorted { item, item2 in
            switch sortingField {
            case .highestLiquidity: return (item.liquidity ?? 0) > (item2.liquidity ?? 0)
            case .lowestLiquidity: return (item.liquidity ?? 0) < (item2.liquidity ?? 0)
            case .highestCap: return item.marketCap > item2.marketCap
            case .lowestCap: return item.marketCap < item2.marketCap
            case .highestVolume: return item.volume > item2.volume
            case .lowestVolume: return item.volume < item2.volume
            case .highestPrice: return item.price > item2.price
            case .lowestPrice: return item.price < item2.price
            case .topGainers: return item.diff > item2.diff
            case .topLoosers: return item.diff < item2.diff
            }
        }
    }

    private func sectionItems(by sectionType: SectionType, count: Int = 3) -> Section {
        let sortingField: MarketListDataSource.SortingField
        switch sectionType {
        case .topGainers: sortingField = .topGainers
        case .topLoosers: sortingField = .topLoosers
        case .topVolume: sortingField = .highestVolume
        }

        let viewItems: [MarketModule.MarketViewItem] = Array(sort(items: service.items, by: sortingField).map {
            let rateValue = CurrencyValue(currency: service.currency, value: $0.price)

            let marketDataValue: MarketModule.MarketDataValue
            switch sectionType {
            case .topVolume:
                marketDataValue = .volume(CurrencyCompactFormatter.instance.format(currency: service.currency, value: $0.volume) ?? "n/a".localized)
            default:
                marketDataValue = .diff($0.diff)
            }

            let rate = ValueFormatter.instance.format(currencyValue: rateValue) ?? "n/a".localized

            return MarketModule.MarketViewItem(
                    rank: .index($0.rank.description),
                    coinName: $0.coinName,
                    coinCode: $0.coinCode,
                    coinType: $0.coinType,
                    rate: rate,
                    marketDataValue: marketDataValue
            )
        }.prefix(count))

        return Section(type: sectionType, viewItems: viewItems)
    }

    private func syncViewItems() {
        let sections = [
            sectionItems(by: .topGainers),
            sectionItems(by: .topLoosers),
            sectionItems(by: .topVolume)
        ]

        viewItemsRelay.accept(sections)
    }

}

extension MarketOverviewViewModel {

    public var viewItemsDriver: Driver<[Section]> {
        viewItemsRelay.asDriver()
    }

    public var isLoadingDriver: Driver<Bool> {
        isLoadingRelay.asDriver()
    }

    public var errorDriver: Driver<String?> {
        errorRelay.asDriver()
    }

    public func refresh() {
        service.refresh()
    }

}

extension MarketOverviewViewModel {

    enum SectionType: String {
        case topGainers
        case topLoosers
        case topVolume
    }


    struct Section {
        let type: SectionType
        let viewItems: [MarketModule.MarketViewItem]
    }

}
