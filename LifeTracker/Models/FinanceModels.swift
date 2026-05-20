import Foundation
import SwiftData

@Model
final class Transaction {
    var id: UUID
    var date: Date
    var desc: String // description is a reserved keyword in some contexts, using desc
    var amount: Double
    var isIncome: Bool
    var category: TransactionCategory?
    var paymentMethod: String
    var note: String
    var tags: [String]
    
    init(id: UUID = UUID(), date: Date = Date(), desc: String = "", amount: Double = 0.0, isIncome: Bool = false, category: TransactionCategory? = nil, paymentMethod: String = "", note: String = "", tags: [String] = []) {
        self.id = id
        self.date = date
        self.desc = desc
        self.amount = amount
        self.isIncome = isIncome
        self.category = category
        self.paymentMethod = paymentMethod
        self.note = note
        self.tags = tags
    }
}

@Model
final class TransactionCategory {
    var id: UUID
    var name: String
    var icon: String
    var colorHex: String
    
    @Relationship(inverse: \Transaction.category)
    var transactions: [Transaction]? = []
    
    init(id: UUID = UUID(), name: String, icon: String, colorHex: String) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
    }
}

@Model
final class Budget {
    var id: UUID
    var categoryName: String
    var limitAmount: Double
    var period: String // e.g., "Monthly"
    
    init(id: UUID = UUID(), categoryName: String, limitAmount: Double, period: String = "Monthly") {
        self.id = id
        self.categoryName = categoryName
        self.limitAmount = limitAmount
        self.period = period
    }
}
