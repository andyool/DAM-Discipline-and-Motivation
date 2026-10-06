import Foundation
import UserNotifications

/// Local notifications: morning lock-in, evening check-in, per-habit reminders and the focus timer.
@MainActor
enum Reminders {
    private static let prefix = "dam."
    private static let focusID = "dam.focus.end"

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func isAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    /// Rebuilds the schedule for the next 7 days from the current state.
    static func reschedule(_ model: AppModel) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let stale = pending.map(\.identifier).filter { $0.hasPrefix(prefix) && $0 != focusID }
        center.removePendingNotificationRequests(withIdentifiers: stale)

        guard model.profile.onboarded, await isAuthorized() else { return }
        let settings = model.settings
        let today = model.today
        let now = Date()
        var requests: [UNNotificationRequest] = []

        for offset in 0..<7 {
            let day = Day.add(offset, to: today)
            let tasks = model.tasks(for: day)
            guard !tasks.isEmpty else { continue }
            let programDay = model.snap.programDay.map { $0 + offset }

            if settings.morningReminder {
                let date = Day.date(day).addingTimeInterval(TimeInterval(settings.morningMinutes * 60))
                if date > now {
                    var body = "\(tasks.count) tasks on the board."
                    if let programDay, programDay <= 60 { body = "Day \(programDay) of 60. " + body }
                    body += " First one: \(tasks[0].title)."
                    requests.append(request("morning.\(day)", title: "Lock in.", body: body, at: date))
                }
            }

            if settings.eveningReminder {
                let date = Day.date(day).addingTimeInterval(TimeInterval(settings.eveningMinutes * 60))
                if date > now {
                    let body: String
                    if offset == 0 {
                        let left = tasks.filter { !$0.done }.count
                        if left == 0 { continue }
                        let streak = model.snap.streak
                        body = streak > 0
                            ? "\(left) task\(left == 1 ? "" : "s") left. Protect your \(streak)-day streak. You've got this."
                            : "\(left) task\(left == 1 ? "" : "s") left. There's still time to secure today."
                    } else {
                        body = "Evening check-in. Finish what you started and secure the day."
                    }
                    requests.append(request("evening.\(day)", title: "Secure the day.", body: body, at: date))
                }
            }
        }

        for habit in model.data.habits where !habit.deleted {
            guard let minutes = habit.reminder else { continue }
            let title = model.habitTitle(habit, day: today)
            if habit.isDaily {
                var comps = DateComponents()
                comps.hour = minutes / 60
                comps.minute = minutes % 60
                requests.append(repeating("habit.\(habit.id.uuidString)", title: title, body: "Time to get it done.", comps: comps))
            } else {
                for weekday in habit.weekdays {
                    var comps = DateComponents()
                    comps.weekday = weekday
                    comps.hour = minutes / 60
                    comps.minute = minutes % 60
                    requests.append(repeating("habit.\(habit.id.uuidString).\(weekday)", title: title, body: "Time to get it done.", comps: comps))
                }
            }
        }

        for r in requests.prefix(60) {
            try? await center.add(r)
        }
    }

    static func scheduleFocusEnd(at date: Date, label: String) {
        let content = UNMutableNotificationContent()
        content.title = "Session complete."
        content.body = label.isEmpty ? "You locked in. XP earned." : "\(label): done. XP earned."
        content.sound = .default
        let interval = max(date.timeIntervalSinceNow, 1)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: focusID, content: content, trigger: trigger))
    }

    static func cancelFocusEnd() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [focusID])
    }

    private static func request(_ id: String, title: String, body: String, at date: Date) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        return UNNotificationRequest(identifier: prefix + id, content: content, trigger: trigger)
    }

    private static func repeating(_ id: String, title: String, body: String, comps: DateComponents) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        return UNNotificationRequest(identifier: prefix + id, content: content, trigger: trigger)
    }
}
