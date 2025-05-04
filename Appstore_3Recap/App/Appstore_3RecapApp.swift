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
        let _ = NetworkMonitor.shared 
        // 앱 시작 시 다운로드 매니저 설정 추가
        AppDownloadManager.shared.setupOnAppLaunch()
    }
    
    @StateObject private var downloadManager = AppDownloadManager.shared
    @State private var isShowingSplash = true
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if isShowingSplash {
                    SplashScreenView()
                        .transition(.opacity)
                        .zIndex(1)
                } else {
                    MainTabView()
                        .environmentObject(downloadManager)
                }
            }
            .onAppear {
                // 1초 후에 스플래시 화면 숨기기
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation {
                        isShowingSplash = false
                    }
                    
                    // 앱이 시작될 때 UI 갱신을 위한 상태 브로드캐스트
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        downloadManager.broadcastInitialStates()
                    }
                }
            }
            .preferredColorScheme(.light)
        }
    }
}

struct SplashScreenView: View {
    var body: some View {
        ZStack {
            Color.white.edgesIgnoringSafeArea(.all)
            
            Text("권우석")
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(.black)
        }
    }
}
