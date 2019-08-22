import UIKit

class ChartScaleHelper {
    static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()

    private let valueScaleLines: Int
    private let valueOffsetPercent: Decimal
    private let masScale: Int
    private let textFont: UIFont
    private let textVerticalMargin: CGFloat
    private let textLeftMargin: CGFloat
    private let textRightMargin: CGFloat

    init(valueScaleLines: Int = 5, valueOffsetPercent: Decimal = 0.05, maxScale: Int = 4, textFont: UIFont, textVerticalMargin: CGFloat = 4, textLeftMargin: CGFloat = 4, textRightMargin: CGFloat = 16) {
        self.valueScaleLines = valueScaleLines
        self.valueOffsetPercent = valueOffsetPercent
        self.masScale = maxScale
        self.textFont = textFont
        self.textVerticalMargin = textVerticalMargin
        self.textLeftMargin = textLeftMargin
        self.textRightMargin = textRightMargin
    }

    public func scaleSize(min: Decimal, max: Decimal) -> CGSize {
        let count = scale(min: min, max: max)
        let holderSize = textHolderSize(max: max, scale: count)

        return holderSize
    }

    public func scale(minValue: Decimal, maxValue: Decimal) -> (topValue: Decimal, delta: Decimal, decimal: Int) {
        var valueDelta = maxValue - minValue
        if valueDelta == 0 {
            valueDelta = maxValue
        }

        let max = maxValue + valueDelta * valueOffsetPercent
        let min = minValue - valueDelta * valueOffsetPercent

        let decimalCount = scale(min: min, max: max)
        let topValue = ceilValue(max: max, scale: decimalCount)
        let delta = deltaScaleValue(topValue: topValue, min: min, decimal: decimalCount)

        return (topValue: topValue, delta: delta, decimal: decimalCount)
    }

    private func scale(min: Decimal, max: Decimal) -> Int {
        var min = min, max = max
        var count = 0
        while count < masScale {
            if Int(truncating: (max - min) as NSNumber) >= valueScaleLines {
                return count + (count == 0 && max < 10 ? 1 : 0)
            } else {
                count += 1
                min *= 10
                max *= 10
            }
        }
        return masScale
    }

    private func ceilValue(max: Decimal, scale: Int) -> Decimal {
        let multipliedValue = max * pow(10, scale)
        var multipliedIntegerValue = Decimal(Int(truncating: multipliedValue as NSNumber))

        if (multipliedValue - multipliedIntegerValue) > 0 {
            multipliedIntegerValue += 1
        }

        return multipliedIntegerValue / pow(10, scale)
    }

    private func deltaScaleValue(topValue: Decimal, min: Decimal, decimal: Int) -> Decimal {
        let x = (topValue - min) / (Decimal(valueScaleLines)  - 1)

        return ceilValue(max: x, scale: decimal)
    }


    private func textHolderSize(max: Decimal, scale: Int) -> CGSize {
        let formatter = ChartScaleHelper.formatter
        formatter.maximumFractionDigits = scale
        formatter.minimumFractionDigits = scale

        let formattedString: String
        if let formatted = formatter.string(from: max as NSNumber) {
            formattedString = formatted
        } else {
            let integerCount = String("\(Int(truncating: max as NSNumber))").count
            var patternString = String(repeating: "9", count: integerCount)
            if scale != 0 {
                patternString.append(".")
                patternString.append(contentsOf: String(repeating: "9", count: scale))
            }
            formattedString = patternString
        }
        let horizontalMargins = textLeftMargin + textRightMargin
        let verticalMargins = textVerticalMargin * 2

        let textSize = (formattedString as NSString).size(withAttributes: [NSAttributedString.Key.font: textFont])
        return CGSize(width: textSize.width + horizontalMargins, height: textSize.height + verticalMargins)
    }

}
