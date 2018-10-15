import RxSwift

class MainSettingsInteractor {
    private let disposeBag = DisposeBag()

    weak var delegate: IMainSettingsInteractorDelegate?

    private let localStorage: ILocalStorage
    private let wordsManager: WordsManager
    private let languageManager: ILanguageManager

    init(localStorage: ILocalStorage, wordsManager: WordsManager, languageManager: ILanguageManager) {
        self.localStorage = localStorage
        self.wordsManager = wordsManager
        self.languageManager = languageManager

        wordsManager.backedUpSubject
                .subscribe(onNext: { [weak self] isBackedUp in
                    self?.onUpdate(isBackedUp: isBackedUp)
                })
                .disposed(by: disposeBag)
    }

    private func onUpdate(isBackedUp: Bool) {
        if isBackedUp {
            delegate?.didBackup()
        }
    }

}

extension MainSettingsInteractor: IMainSettingsInteractor {

    var isBackedUp: Bool {
        return wordsManager.isBackedUp
    }

    var currentLanguage: String {
        return languageManager.displayNameForCurrentLanguage
    }

    var baseCurrency: String {
        return ""
    }

    var lightMode: Bool {
        return localStorage.lightMode
    }

    func set(lightMode: Bool) {
        localStorage.lightMode = lightMode
        delegate?.didUpdateLightMode()
    }

}
