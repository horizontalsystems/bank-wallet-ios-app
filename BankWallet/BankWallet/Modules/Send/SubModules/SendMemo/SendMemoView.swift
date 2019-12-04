import UIKit
import SnapKit

class SendMemoView: UIView {
    private let delegate: ISendMemoViewDelegate
    private let inputFieldFont = UIFont.appSubhead1I

    private let holderView = UIView()
    private let memoInputField = UITextField()

    init(delegate: ISendMemoViewDelegate) {
        self.delegate = delegate

        super.init(frame: .zero)

        backgroundColor = .clear

        addSubview(holderView)
        holderView.addSubview(memoInputField)

        holderView.snp.makeConstraints { maker in
            maker.top.equalToSuperview().offset(CGFloat.margin3x)
            maker.leading.trailing.equalToSuperview().inset(CGFloat.margin4x)
            maker.bottom.equalToSuperview()
        }

        holderView.layer.cornerRadius = CGFloat.cornerRadius8
        holderView.layer.borderWidth = .heightOneDp
        holderView.layer.borderColor = UIColor.appSteel20.cgColor
        holderView.backgroundColor = .appLawrence

        memoInputField.snp.makeConstraints { maker in
            maker.top.bottom.equalToSuperview()
            maker.leading.trailing.equalToSuperview().offset(CGFloat.margin3x)
            maker.centerY.equalToSuperview()
            maker.height.equalTo(inputFieldFont.lineHeight + CGFloat.margin3x * 2)
        }

        memoInputField.textColor = .appOz
        memoInputField.font = inputFieldFont
        memoInputField.attributedPlaceholder = NSAttributedString(string: "send.confirmation.memo_placeholder".localized, attributes: [NSAttributedString.Key.foregroundColor: UIColor.appGray50])
        memoInputField.keyboardAppearance = App.theme.keyboardAppearance
        memoInputField.tintColor = .appJacob

        memoInputField.delegate = self
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("not implemented")
    }

}

extension SendMemoView: ISendMemoView {

    var memo: String? {
        memoInputField.text
    }

}

extension SendMemoView: UITextFieldDelegate {

    private func validate(text: String) -> Bool {
        if delegate.validate(memo: text) {
            return true
        } else {
            memoInputField.shakeView()
            return false
        }
    }

    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if let text = memoInputField.text, let textRange = Range(range, in: text) {
            let text = text.replacingCharacters(in: textRange, with: string)
            guard !text.isEmpty else {
                return true
            }
            return validate(text: text)
        }
        return validate(text: string)
    }

}
