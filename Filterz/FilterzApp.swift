//
//  FilterzApp.swift
//  Filterz
//
//  Created by 전민돌 on 4/22/26.
//

import SwiftUI
import ComposableArchitecture

@main
struct FilterzApp: App {
    let store = Store(initialState: AppFeature.State()) {
        AppFeature()
    }
    
    // 키체인 세션 초기화
    init() {
        KeychainHelper.delete(forKey: "accessToken")
        KeychainHelper.delete(forKey: "refreshToken")
        KeychainHelper.delete(forKey: "userId")
    }

    var body: some Scene {
        WindowGroup {
            AppView(store: store)
        }
    }
}
