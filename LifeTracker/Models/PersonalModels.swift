import Foundation
import SwiftData

@Model
final class Habit {
    var id: UUID
    var title: String
    var isCompletedToday: Bool
    var streak: Int
    
    init(id: UUID = UUID(), title: String, isCompletedToday: Bool = false, streak: Int = 0) {
        self.id = id
        self.title = title
        self.isCompletedToday = isCompletedToday
        self.streak = streak
    }
}

@Model
final class MoodEntry {
    var id: UUID
    var date: Date
    var rating: Int // 1-5 scale (e.g., 1 sad, 5 excellent)
    var note: String
    
    init(id: UUID = UUID(), date: Date = Date(), rating: Int, note: String = "") {
        self.id = id
        self.date = date
        self.rating = rating
        self.note = note
    }
}

@Model
final class PersonalGoal {
    var id: UUID
    var title: String
    var targetCount: Int
    var currentCount: Int
    var period: String
    
    init(id: UUID = UUID(), title: String, targetCount: Int, currentCount: Int = 0, period: String = "Weekly") {
        self.id = id
        self.title = title
        self.targetCount = targetCount
        self.currentCount = currentCount
        self.period = period
    }
}
