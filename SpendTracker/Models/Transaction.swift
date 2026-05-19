import SwiftData
import Foundation

@Model
final class Transaction {
    var id: UUID
    var amount: Double
    var merchant: String
    var category: Category
    var date: Date
    var rawNotificationText: String
    var source: NotificationSource

    init(
        amount: Double,
        merchant: String,
        category: Category = .uncategorized,
        date: Date = .now,
        rawNotificationText: String,
        source: NotificationSource
    ) {
        self.id = UUID()
        self.amount = amount
        self.merchant = merchant
        self.category = category
        self.date = date
        self.rawNotificationText = rawNotificationText
        self.source = source
    }
}

enum Category: String, Codable, CaseIterable {
    case food = "Food & Dining"
    case transport = "Transport"
    case shopping = "Shopping"
    case utilities = "Utilities"
    case entertainment = "Entertainment"
    case health = "Health"
    case travel = "Travel"
    case uncategorized = "Uncategorized"

    var icon: String {
        switch self {
        case .food: return "fork.knife"
        case .transport: return "car.fill"
        case .shopping: return "bag.fill"
        case .utilities: return "bolt.fill"
        case .entertainment: return "tv.fill"
        case .health: return "heart.fill"
        case .travel: return "airplane"
        case .uncategorized: return "questionmark.circle"
        }
    }

    var color: String {
        switch self {
        case .food: return "orange"
        case .transport: return "blue"
        case .shopping: return "purple"
        case .utilities: return "yellow"
        case .entertainment: return "pink"
        case .health: return "red"
        case .travel: return "teal"
        case .uncategorized: return "gray"
        }
    }
}

enum NotificationSource: String, Codable {
    case bankPush = "Bank App"
    case sms = "SMS"
}
