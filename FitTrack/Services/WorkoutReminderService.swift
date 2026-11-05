import Combine
import Foundation
import UserNotifications

@MainActor
final class WorkoutReminderService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = WorkoutReminderService()
    @Published private(set) var message = "Save reminder settings to enable notifications for scheduled workout days."
    @Published private(set) var permissionDenied = false
    private let center = UNUserNotificationCenter.current()
    private var generation = UUID()
    private var currentUserID: String?
    private static let prefix = "fittrack.workout."

    private override init() {
        super.init()
        center.delegate = self
    }

    struct SyncKey: Equatable {
        var userID: String
        var schedules: [ScheduledWorkout]
        var settings: ProfileSettings
        var permissionRequest: Int
        var activation: Int
    }

    func synchronize(_ key: SyncKey) async {
        let run = UUID()
        generation = run
        currentUserID = key.userID
        let pending = await center.pendingNotificationRequests()
        guard isCurrent(run) else { return }
        // Only cancel notifications owned by this feature, never unrelated app alerts.
        center.removePendingNotificationRequests(withIdentifiers: pending.filter { $0.identifier.hasPrefix(Self.prefix) }.map(\.identifier))
        permissionDenied = false
        guard key.settings.reminders == "On" else { message = "Workout reminders are off."; return }
        guard key.settings.notifications == "On" else { message = "Enable Notifications in App settings to receive reminders."; return }
        do {
            var status = await center.notificationSettings().authorizationStatus
            guard isCurrent(run) else { return }
            if status == .notDetermined && key.permissionRequest > 0 {
                _ = try await center.requestAuthorization(options: [.alert, .sound])
                status = await center.notificationSettings().authorizationStatus
            }
            guard isCurrent(run) else { return }
            if status == .denied {
                permissionDenied = true
                message = "Notifications are blocked. Allow notifications in iOS Settings to receive workout reminders."
                return
            }
            guard status == .authorized || status == .provisional || status == .ephemeral else {
                message = "Save reminder settings and allow notifications to enable workout reminders."
                return
            }
            let specs = WorkoutReminderPlan.make(schedules: key.schedules, hour: key.settings.reminderHour ?? 9,
                                                 minute: key.settings.reminderMinute ?? 0)
            // Reserve room for other app notifications and schedule nearest dates first.
            for spec in specs.prefix(60) {
                guard isCurrent(run) else { return }
                let content = UNMutableNotificationContent()
                content.title = "Time for your workout"
                content.body = "\(spec.title) is on your calendar today."
                content.sound = .default
                let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: spec.fireDate)
                let id = "\(Self.prefix)\(key.userID).\(spec.scheduleID).\(run)"
                let request = UNNotificationRequest(identifier: id, content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
                try await center.add(request)
                if !isCurrent(run) {
                    // Unique run IDs prevent a cancelled task from deleting a newer reminder.
                    center.removePendingNotificationRequests(withIdentifiers: [id])
                    return
                }
            }
            guard isCurrent(run) else { return }
            message = specs.isEmpty ? "No upcoming reminders. Schedule a workout for a day whose reminder time hasn't passed. Rest days are skipped."
                : "\(min(specs.count, 60)) workout reminder(s) scheduled. Rest days are skipped."
        } catch {
            guard isCurrent(run) else { return }
            message = "Could not schedule reminders: \(error.localizedDescription)"
        }
    }

    func cancel(userID: String) {
        if currentUserID == userID { generation = UUID(); currentUserID = nil }
        let prefix = "\(Self.prefix)\(userID)."
        Task {
            let pending = await center.pendingNotificationRequests()
            // A rapid re-login may already have refreshed this account's requests.
            guard currentUserID != userID else { return }
            center.removePendingNotificationRequests(withIdentifiers: pending.filter { $0.identifier.hasPrefix(prefix) }.map(\.identifier))
            let delivered = await center.deliveredNotifications()
            center.removeDeliveredNotifications(withIdentifiers: delivered.filter { $0.request.identifier.hasPrefix(prefix) }.map { $0.request.identifier })
        }
    }

    private func isCurrent(_ run: UUID) -> Bool { generation == run && !Task.isCancelled }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
        willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
