import Foundation
import XRatesKit

struct ChartData {
    var coinCode: CoinCode
    var marketCap: Decimal?
    var stats: [ChartType: [ChartPoint]]
    var diffs: [ChartType: Decimal]
}
