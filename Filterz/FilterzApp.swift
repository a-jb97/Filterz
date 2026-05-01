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

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        
        return true
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
