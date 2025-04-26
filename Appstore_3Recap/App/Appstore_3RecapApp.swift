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
        
        // 앱 시작 시 다운로드 매니저 설정 추가
        AppDownloadManager.shared.setupOnAppLaunch()
    }
    
    @StateObject private var downloadManager = AppDownloadManager.shared
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(downloadManager)
                .onAppear {
                    // 앱이 시작될 때 UI 갱신을 위한 상태 브로드캐스트
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        downloadManager.broadcastInitialStates()
                    }
                }
        }
    }
}
