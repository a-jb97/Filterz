//
//  FilterzApp.swift
//  Filterz
//
//  Created by 전민돌 on 4/22/26.
//

import SwiftUI
import SwiftData
import ComposableArchitecture
import KakaoSDKCommon
import KakaoSDKAuth
import FirebaseCore
import FirebaseMessaging
import UserNotifications

struct ChatPushPayload: Equatable, Sendable {
    let roomId: String
    let unreadCount: Int
    let chatId: String?
    let senderId: String?

    init?(userInfo: [AnyHashable: Any]) {
        guard let roomId = userInfo["room_id"] as? String, !roomId.isEmpty else {
            return nil
        }

        self.roomId = roomId
        self.unreadCount = Self.intValue(from: userInfo["unread_count"]) ?? 0
        self.chatId = userInfo["chat_id"] as? String
        self.senderId = userInfo["sender_id"] as? String
    }

    private static func intValue(from value: Any?) -> Int? {
        if let int = value as? Int { return int }
        if let string = value as? String { return Int(string) }
        if let number = value as? NSNumber { return number.intValue }
        return nil
    }
}

enum PushNotificationBridge {
    static let receivedNotification = Notification.Name("Filterz.chatPush.received")
    static let tappedNotification = Notification.Name("Filterz.chatPush.tapped")
    static let payloadKey = "payload"
    private static let fcmTokenKey = "fcmToken"

    @MainActor static var currentChatRoomId: String?
    @MainActor private static var pendingTappedPayload: ChatPushPayload?

    static var fcmToken: String? {
        get { KeychainHelper.load(forKey: fcmTokenKey) }
        set {
            if let newValue, !newValue.isEmpty {
                KeychainHelper.save(newValue, forKey: fcmTokenKey)
            } else {
                KeychainHelper.delete(forKey: fcmTokenKey)
            }
        }
    }

    static func post(_ name: Notification.Name, payload: ChatPushPayload) {
        NotificationCenter.default.post(
            name: name,
            object: nil,
            userInfo: [payloadKey: payload]
        )
    }

    @MainActor static func storePendingTappedPayload(_ payload: ChatPushPayload) {
        pendingTappedPayload = payload
    }

    @MainActor static func consumePendingTappedPayload() -> ChatPushPayload? {
        defer { pendingTappedPayload = nil }
        return pendingTappedPayload
    }

    @MainActor static func clearPendingTappedPayload(_ payload: ChatPushPayload) {
        if pendingTappedPayload == payload {
            pendingTappedPayload = nil
        }
    }

    @MainActor static func setApplicationBadge(_ count: Int) {
        UIApplication.shared.applicationIconBadgeNumber = max(0, count)
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        requestNotificationAuthorization(application)
        
        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
#if DEBUG
        print("APNs token registered: \(deviceToken.map { String(format: "%02.2hhx", $0) }.joined())")
#endif
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
#if DEBUG
        print("APNs token registration failed: \(error.localizedDescription)")
#endif
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        PushNotificationBridge.fcmToken = fcmToken
#if DEBUG
        print("FCM registration token: \(fcmToken ?? "nil")")
#endif
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        guard let payload = ChatPushPayload(userInfo: notification.request.content.userInfo) else {
            return [.banner, .sound, .badge]
        }

        PushNotificationBridge.post(PushNotificationBridge.receivedNotification, payload: payload)
        await PushNotificationBridge.setApplicationBadge(payload.unreadCount)

        let currentChatRoomId = await PushNotificationBridge.currentChatRoomId
        if currentChatRoomId == payload.roomId {
            return [.badge]
        }
        return [.banner, .sound, .badge]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        guard let payload = ChatPushPayload(userInfo: response.notification.request.content.userInfo) else {
            return
        }

        await PushNotificationBridge.storePendingTappedPayload(payload)
        PushNotificationBridge.post(PushNotificationBridge.tappedNotification, payload: payload)
        await PushNotificationBridge.setApplicationBadge(payload.unreadCount)
    }

    private func requestNotificationAuthorization(_ application: UIApplication) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
#if DEBUG
            print("Notification authorization status before request: \(settings.authorizationStatus.rawValue)")
#endif
            switch settings.authorizationStatus {
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
#if DEBUG
                    print("Notification authorization granted: \(granted)")
                    if let error {
                        print("Notification authorization failed: \(error.localizedDescription)")
                    }
#endif
                    guard granted else { return }
                    DispatchQueue.main.async {
#if DEBUG
                        print("Registering for remote notifications after authorization grant.")
#endif
                        application.registerForRemoteNotifications()
                    }
                }
            case .authorized, .provisional, .ephemeral:
                DispatchQueue.main.async {
#if DEBUG
                    print("Registering for remote notifications. isRegistered: \(application.isRegisteredForRemoteNotifications)")
#endif
                    application.registerForRemoteNotifications()
                }
            case .denied:
#if DEBUG
                print("Notification authorization denied. Enable notifications in Settings for Filterz.")
#endif
            @unknown default:
                DispatchQueue.main.async {
#if DEBUG
                    print("Registering for remote notifications from unknown authorization status.")
#endif
                    application.registerForRemoteNotifications()
                }
            }
        }
    }
}

@main
struct FilterzApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    let store = Store(initialState: AppFeature.State()) {
        AppFeature()
    }
    
    init() {
        let appKey = Bundle.main.object(forInfoDictionaryKey: "KAKAO_NATIVE_APP_KEY") as! String
        KakaoSDK.initSDK(appKey: appKey)
    }
    
    var body: some Scene {
        WindowGroup {
            AppView(store: store)
                .modelContainer(ChatModelContainer.shared)
                .onOpenURL { url in
                    if AuthApi.isKakaoTalkLoginUrl(url) {
                        _ = AuthController.handleOpenUrl(url: url)
                    }
                }
        }
    }
}
