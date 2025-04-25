//
//  Appstore_3RecapApp.swift
//  Appstore_3Recap
//
//  Created by 권우석 on 4/24/25.
//

import SwiftUI

@main
struct Appstore_3RecapApp: App {
    // 앱이 시작될 때 NetworkMonitor 초기화
    init() {
        // 네트워크 모니터링 시작
        let _ = NetworkMonitor.shared //  앱딜리게이트 대신 역할을 하는 곳에서 관찰을 시작하도록 구현 
    }
    
    @StateObject private var downloadManager = AppDownloadManager.shared
        
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(downloadManager)
        }
    }
}
