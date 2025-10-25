
import Foundation
import Combine

class AppSettings: ObservableObject {
    @Published var startOfDayHour: Int {
        didSet {
            UserDefaults.standard.set(startOfDayHour, forKey: "startOfDayHour")
        }
    }
    @Published var startOfDayMinute: Int {
        didSet {
            UserDefaults.standard.set(startOfDayMinute, forKey: "startOfDayMinute")
        }
    }

    init() {
        self.startOfDayHour = UserDefaults.standard.object(forKey: "startOfDayHour") as? Int ?? 7
        self.startOfDayMinute = UserDefaults.standard.object(forKey: "startOfDayMinute") as? Int ?? 0
    }
}
