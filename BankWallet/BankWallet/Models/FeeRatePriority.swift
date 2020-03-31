import Foundation

enum FeeRatePriority: Equatable {
    case low
    case medium
    case high
    case custom(value: Int, range: ClosedRange<Int>)

    var title: String {
        switch self {
        case .low: return "send.tx_speed_low".localized
        case .medium: return "send.tx_speed_medium".localized
        case .high: return "send.tx_speed_high".localized
        case .custom: return "send.tx_speed_custom".localized
        }
    }

    static func ==(lhs: FeeRatePriority, rhs: FeeRatePriority) -> Bool {
        switch (lhs, rhs) {
        case (.low, .low): return true
        case (.medium, .medium): return true
        case (.high, .high): return true
        case (.custom(_), .custom(_)): return true
        default: return false
        }
    }

}
