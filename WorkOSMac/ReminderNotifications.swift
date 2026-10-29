import AppKit
import Foundation
import UserNotifications

extension Notification.Name {
    static let workosReminderOpened = Notification.Name("WorkOSReminderOpened")
}

// A system notification is a local reminder, not an external scheduling or cloud service.
// The note/task title is hidden from lock-screen notifications unless the user opts in.
final class WorkOSNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void) {
        if let itemID = response.notification.request.content.userInfo["workosScheduleID"] as? String {
            UserDefaults.standard.set(itemID, forKey: "workos.reminder.pendingOpenID")
            DispatchQueue.main.async {
                NSApplication.shared.activate(ignoringOtherApps: true)
                NotificationCenter.default.post(name: .workosReminderOpened, object: nil, userInfo: ["itemID": itemID])
                completionHandler()
            }
        } else {
            completionHandler()
        }
    }
}

final class WorkOSAppDelegate: NSObject, NSApplicationDelegate {
    private let localNotifications = WorkOSNotificationDelegate()
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = localNotifications
    }
}

@MainActor
final class WorkOSReminderService {
    static let shared = WorkOSReminderService()
    private let center = UNUserNotificationCenter.current()
    private var generation = 0
    private init() {}

    func queryPermission(_ completion: @escaping (String, Bool) -> Void) {
        center.getNotificationSettings { settings in
            let authorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
            let label: String
            switch settings.authorizationStatus {
            case .authorized: label = "Mac 알림 허용됨"
            case .provisional: label = "Mac 알림 임시 허용"
            case .denied: label = "Mac 알림 차단됨 · 시스템 설정에서 변경"
            case .notDetermined: label = "Mac 알림 미설정 · 사용자가 허용해야 발송"
            @unknown default: label = "Mac 알림 권한 확인 필요"
            }
            DispatchQueue.main.async { completion(label, authorized) }
        }
    }

    func requestPermission(_ completion: @escaping (String) -> Void) {
        center.requestAuthorization(options: [.alert, .sound]) { _, error in
            Task { @MainActor in
                self.queryPermission { label, _ in
                    completion(error.map { label + " · " + $0.localizedDescription } ?? label)
                }
            }
        }
    }

    func synchronize(items: [WorkScheduleItem], revealDetails: Bool) {
        generation += 1
        let requestNumber = generation
        // Do not remove other notification features that might be added to this app later.
        center.getPendingNotificationRequests { [weak self] requests in
            Task { @MainActor in
                guard let self, self.generation == requestNumber else { return }
                let prior = requests.map(\.identifier).filter { $0.hasPrefix("workos.schedule.") }
                self.center.removePendingNotificationRequests(withIdentifiers: prior)
                self.center.getNotificationSettings { [weak self] settings in
                    Task { @MainActor in
                        guard let self, self.generation == requestNumber,
                              settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
                        for event in ScheduleDates.upcomingReminders(items) {
                            let content = UNMutableNotificationContent()
                            content.title = revealDetails ? event.heading : "MemoWeaver 일정 알림"
                            content.body = revealDetails ? event.message : "마감 예정인 일정이 있습니다. MemoWeaver에서 확인하세요."
                            content.sound = .default
                            content.userInfo = ["workosScheduleID": event.scheduleID]
                            let components = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute], from: event.fireAt)
                            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                            let request = UNNotificationRequest(identifier: event.identifier, content: content, trigger: trigger)
                            self.center.add(request) { error in
                                if let error { NSLog("[MemoWeaver] Local reminder registration failed: %@", error.localizedDescription) }
                            }
                        }
                    }
                }
            }
        }
    }
}
