import Foundation
import UserNotifications

/// Manages scheduling and authorization of local daily-reminder notifications.
@MainActor
final class NotificationService: ObservableObject {

    static let shared = NotificationService()

    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private init() {
        Task { await refreshStatus() }
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            await refreshStatus()
            return granted
        } catch {
            return false
        }
    }

    func refreshStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    // MARK: - Scheduling

    /// Cancels all pending reminders and reschedules from the current profile settings.
    func reschedule(profile: UserProfile) async {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        guard profile.notificationsEnabled, !profile.notificationTimes.isEmpty else { return }

        await refreshStatus()
        guard authorizationStatus == .authorized else { return }

        let messages = remindersMessages(for: profile)

        for time in profile.notificationTimes {
            let (hour, minute) = hourMinute(for: time)

            for dayIndex in 0..<7 {
                let message = messages[dayIndex % messages.count]

                var components = DateComponents()
                components.hour = hour
                components.minute = minute
                components.weekday = dayIndex + 1   // 1 = Sunday … 7 = Saturday

                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: components, repeats: true)

                let content = UNMutableNotificationContent()
                content.title = "Welcome Back 💛"
                content.body  = message
                content.sound = .default

                let id = "wb-\(time.rawValue)-day\(dayIndex)"
                let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
                try? await UNUserNotificationCenter.current().add(req)
            }
        }
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    // MARK: - Private helpers

    private func hourMinute(for time: NotificationTime) -> (Int, Int) {
        switch time {
        case .morning:   return (9, 0)
        case .noon:      return (12, 0)
        case .afternoon: return (15, 0)
        case .evening:   return (18, 0)
        }
    }

    private func remindersMessages(for profile: UserProfile) -> [String] {
        let name = profile.name.isEmpty ? "friend" : profile.name
        var msgs: [String] = [
            "Hello \(name)! Your family loves you. Tap to hear a story. 💛",
            "Time to remember something wonderful today.",
            "Your memories are waiting. Tap the mic to start.",
            "Someone who loves you wants to share a story.",
            "Good to see you, \(name). Let's look at your memories.",
            "Remember who you are and all the love around you.",
            "A message from your family is waiting for you. 💛",
        ]
        if let first = profile.familyMembers.first {
            msgs.append("\(first.name) is thinking of you today.")
        }
        return msgs
    }
}
