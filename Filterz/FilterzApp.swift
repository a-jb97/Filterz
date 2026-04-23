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

    var body: some Scene {
        WindowGroup {
            AppView(store: store)
        }
    }
}
