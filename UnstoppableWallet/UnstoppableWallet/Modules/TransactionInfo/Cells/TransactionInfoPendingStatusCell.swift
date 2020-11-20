import UIKit
import ThemeKit

class TransactionInfoPendingStatusCell: BaseThemeCell {
    private let leftView = LeftCView()
    private let rightView = UIView()

    private let statusLabel = UILabel()
    private let barsProgressView = BarsProgressView(barWidth: 4, color: .themeGray50, inactiveColor: .themeSteel20)

    override init(style: CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        layout(leftView: leftView, leftInset: 0, rightView: rightView)

        rightView.addSubview(statusLabel)
        statusLabel.snp.makeConstraints { maker in
            maker.leading.equalToSuperview()
            maker.centerY.equalToSuperview()
        }

        statusLabel.font = .subhead1
        statusLabel.textColor = .themeLeah

        rightView.addSubview(barsProgressView)
        barsProgressView.snp.makeConstraints { maker in
            maker.leading.equalTo(statusLabel.snp.trailing).offset(CGFloat.margin2x)
            maker.trailing.equalToSuperview()
            maker.centerY.equalToSuperview()
            maker.height.equalTo(18)
        }

        barsProgressView.set(barsCount: BarsProgressView.progressStepsCount)

        leftView.text = "status".localized
        leftView.image = UIImage(named: "info_20")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(progress: Double, incoming: Bool, iconAction: (() -> ())?) {
        statusLabel.text = incoming ? "transactions.receiving".localized : "transactions.pending".localized
        leftView.imageAction = iconAction

        barsProgressView.set(filledColor: incoming ? .themeGreenD : .themeYellowD)
        barsProgressView.set(progress: progress)
        barsProgressView.startAnimating()
    }

}
