import UIKit
import CoinKit

class BalanceRouter {
    weak var viewController: UIViewController?
}

extension BalanceRouter: IBalanceRouter {

    func showReceive(wallet: Wallet) {
        guard let module = DepositRouter.module(wallet: wallet) else {
            return
        }

        viewController?.present(module, animated: true)
    }

    func openSend(wallet: Wallet) {
        if let module = SendRouter.module(wallet: wallet) {
            viewController?.present(module, animated: true)
        }
    }

    func openSwap(wallet: Wallet) {
        if let module = SwapModule.viewController(coinIn: wallet.coin) {
            viewController?.present(module, animated: true)
        }
    }

    func showChart(coin: Coin) {
        viewController?.navigationController?.pushViewController(CoinPageModule.viewController(launchMode: .coin(coin: coin)), animated: true)
    }

    func openManageWallets() {
        guard let module = ManageWalletsModuleNew.viewController() else {
            return
        }

        viewController?.present(module, animated: true)
    }

    func showBackupRequired(wallet: Wallet) {
        let text = "receive_alert.not_backed_up_description".localized(wallet.account.name, wallet.coin.title)
        let module = BackupRequiredViewController(account: wallet.account, text: text, sourceViewController: viewController).toBottomSheet
        viewController?.present(module, animated: true)
    }

    func showSortType() {
        viewController?.present(SortTypeRouter.module(), animated: true)
    }

    func showSyncError(error: Error, wallet: Wallet) {
        viewController?.present(BalanceErrorRouter.module(wallet: wallet, error: error, navigationController: viewController?.navigationController), animated: true)
    }

}

extension BalanceRouter {

    static func module() -> UIViewController {
        let router = BalanceRouter()
        let interactor = BalanceInteractor(walletManager: App.shared.walletManager, adapterManager: App.shared.adapterManager, currencyKit: App.shared.currencyKit, localStorage: App.shared.localStorage, sortTypeManager: App.shared.sortTypeManager, rateManager: App.shared.rateManager, rateAppManager: App.shared.rateAppManager, accountManager: App.shared.accountManager)
        let presenter = BalancePresenter(interactor: interactor, router: router, factory: BalanceViewItemFactory(), sorter: BalanceSorter())
        let viewController = BalanceViewController(viewDelegate: presenter)

        interactor.delegate = presenter
        presenter.view = viewController
        router.viewController = viewController

        return viewController
    }

}
