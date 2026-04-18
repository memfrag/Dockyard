//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import Foundation

extension Date {
    func weekdayDayMonth() -> String {

        let locale = Locale(identifier: "en_US_POSIX")
        let weekday = formatted(
            .dateTime
            .weekday(.wide)
            .locale(locale)
        )

        let dayMonth = formatted(
            .dateTime
            .day()
            .month(.wide)
            .locale(locale)
        )

        return "\(weekday), \(dayMonth)"
    }
}
