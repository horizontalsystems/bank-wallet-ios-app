import ThemeKit

struct RestoreModule {

    static func start(mode: StartMode, predefinedAccountType: PredefinedAccountType? = nil, selectCoins: Bool = true, onComplete: (() -> ())? = nil) {
        let service = RestoreService(predefinedAccountType: predefinedAccountType, walletManager: App.shared.walletManager, accountCreator: App.shared.accountCreator, accountManager: App.shared.accountManager)
        let viewModel = RestoreViewModel(service: service, selectCoins: selectCoins)
        let view = RestoreView(viewModel: viewModel, onComplete: onComplete)

        view.start(mode: mode)
    }

}

extension RestoreModule {

    enum StartMode {
        case push(navigationController: UINavigationController?)
        case present(viewController: UIViewController?)
    }

}
