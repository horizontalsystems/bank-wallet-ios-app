import CurrencyKit
import RxSwift
import RxRelay
import XRatesKit
import CoinKit

class FiatServiceNew {
    private var disposeBag = DisposeBag()
    private var marketInfoDisposeBag = DisposeBag()

    private let switchService: AmountTypeSwitchServiceNew
    private let currencyKit: ICurrencyKit
    private let rateManager: IRateManager

    private var coin: Coin?
    private var rate: Decimal? {
        didSet {
            toggleAvailableRelay.accept(rate != nil)
        }
    }

    private let coinAmountRelay = PublishRelay<Decimal>()
    private(set) var coinAmount: Decimal = 0 {
        didSet {
            coinAmountRelay.accept(coinAmount)
        }
    }

    private var currencyAmount: Decimal?

    private let primaryInfoRelay = PublishRelay<PrimaryInfo>()
    private(set) var primaryInfo: PrimaryInfo = .amount(amount: 0) {
        didSet {
            primaryInfoRelay.accept(primaryInfo)
        }
    }

    private let secondaryAmountInfoRelay = PublishRelay<AmountInfo?>()
    private(set) var secondaryAmountInfo: AmountInfo? {
        didSet {
            secondaryAmountInfoRelay.accept(secondaryAmountInfo)
        }
    }

    private var toggleAvailableRelay = BehaviorRelay<Bool>(value: false)

    var currency: Currency {
        currencyKit.baseCurrency
    }

    init(switchService: AmountTypeSwitchServiceNew, currencyKit: ICurrencyKit, rateManager: IRateManager) {
        self.switchService = switchService
        self.currencyKit = currencyKit
        self.rateManager = rateManager

        subscribe(disposeBag, switchService.amountTypeObservable) { [weak self] in self?.sync(amountType: $0) }

        sync()
    }

    private func sync(marketInfo: MarketInfo?) {
        if let marketInfo = marketInfo, !marketInfo.expired {
            rate = marketInfo.rate

            switch switchService.amountType {
            case .coin:
                syncCurrencyAmount()
            case .currency:
                syncCoinAmount()
            }
        } else {
            rate = nil
        }

        sync()
    }

    private func sync(amountType: AmountTypeSwitchServiceNew.AmountType) {
        sync()
    }

    private func sync() {
        if let coin = coin {
            let coinAmountInfo: AmountInfo = .coinValue(coinValue: CoinValue(coin: coin, value: coinAmount))
            let currencyAmountInfo: AmountInfo? = currencyAmount.map { .currencyValue(currencyValue: CurrencyValue(currency: currency, value: $0)) }

            switch switchService.amountType {
            case .coin:
                primaryInfo = .amountInfo(amountInfo: coinAmountInfo)
                secondaryAmountInfo = currencyAmountInfo
            case .currency:
                primaryInfo = .amountInfo(amountInfo: currencyAmountInfo)
                secondaryAmountInfo = coinAmountInfo
            }
        } else {
            primaryInfo = .amount(amount: coinAmount)
            secondaryAmountInfo = .currencyValue(currencyValue: .init(currency: currency, value: 0))
        }
    }

    private func syncCoinAmount() {
        if let currencyAmount = currencyAmount, let rate = rate {
            coinAmount = rate == 0 ? 0 : currencyAmount / rate
        } else {
            coinAmount = 0
        }
    }

    private func syncCurrencyAmount() {
        if let rate = rate {
            currencyAmount = coinAmount * rate
        } else {
            currencyAmount = nil
        }
    }

}

extension FiatServiceNew {

    var coinAmountObservable: Observable<Decimal> {
        coinAmountRelay.asObservable()
    }

    var primaryInfoObservable: Observable<PrimaryInfo> {
        primaryInfoRelay.asObservable()
    }

    var secondaryAmountInfoObservable: Observable<AmountInfo?> {
        secondaryAmountInfoRelay.asObservable()
    }

    var toggleAvailableObservable: Observable<Bool> {
        toggleAvailableRelay.asObservable()
    }

    func set(coin: Coin?) {
        self.coin = coin

        marketInfoDisposeBag = DisposeBag()

        if let coin = coin {
            sync(marketInfo: rateManager.marketInfo(coinType: coin.type, currencyCode: currency.code))

            rateManager.marketInfoObservable(coinType: coin.type, currencyCode: currency.code)
                    .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .utility))
                    .observeOn(ConcurrentDispatchQueueScheduler(qos: .utility))
                    .subscribe(onNext: { [weak self] marketInfo in
                        self?.sync(marketInfo: marketInfo)
                    })
                    .disposed(by: marketInfoDisposeBag)
        } else {
            rate = nil
            currencyAmount = nil
            sync()
        }
    }

    func set(amount: Decimal) {
        switch switchService.amountType {
        case .coin:
            coinAmount = amount
            syncCurrencyAmount()
        case .currency:
            currencyAmount = amount
            syncCoinAmount()
        }

        sync()
    }

    func set(coinAmount: Decimal) {
        self.coinAmount = coinAmount
        syncCurrencyAmount()
        sync()
    }

}

extension FiatServiceNew {

    enum PrimaryInfo {
        case amountInfo(amountInfo: AmountInfo?)
        case amount(amount: Decimal)
    }

}
