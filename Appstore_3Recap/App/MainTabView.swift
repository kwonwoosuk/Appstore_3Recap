//
//  MainTabView.swift
//  Appstore_3Recap
//
//  Created by 권우석 on 4/25/25.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 4 // 검색 탭
    @StateObject private var downloadManager = AppDownloadManager.shared
    @StateObject private var networkAlertManager = NetworkAlertManager()
    
    // 초기 로드 추적용 상태 추가
    @State private var isInitialized = false
    
    var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $selectedTab) {
                TodayPlaceholderView()
                    .tabItem {
                        Label("투데이", systemImage: "doc.text.image")
                    }
                    .tag(0)
                
                GamesPlaceholderView()
                    .tabItem {
                        Label("게임", systemImage: "gamecontroller")
                    }
                    .tag(1)
                
                AsyncUserAppsView()
                    .tabItem {
                        Label("앱", systemImage: "square.stack.3d.up")
                    }
                    .tag(2)
                
                ArcadePlaceholderView()
                    .tabItem {
                        Label("아케이드", systemImage: "arcade.stick")
                    }
                    .tag(3)
                
                AsyncSearchView()
                    .tabItem {
                        Label("검색", systemImage: "magnifyingglass")
                    }
                    .tag(4)
            }
            .onAppear {
                // 다운로드 매니저 백그라운드 타이머 초기화
                AppDownloadManager.shared.initializeBackgroundTimers()
                
                // UI 애니메이션 설정
                UIView.appearance().tintColor = UIColor(Color.appStoreBlue)
                let appearance = UITabBarAppearance()
                appearance.configureWithDefaultBackground() // 기본 배경 설정
                appearance.backgroundEffect = UIBlurEffect(style: .prominent) // 블러 효과
                appearance.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.01)
                appearance.shadowImage = nil // 상단 구분선 제거
                
                UITabBar.appearance().standardAppearance = appearance
                UITabBar.appearance().scrollEdgeAppearance = appearance
                
                // 네트워크 모니터 시작
                _ = NetworkMonitor.shared
                
                // 앱 시작 시 모든 다운로드 타이머 초기화 및 상태 브로드캐스트
                if !isInitialized {
                    initializeAppDownloads()
                    isInitialized = true
                }
            }
            .task {
                // 앱 시작 시 타이머 초기화 및 알림 재전송 (UI 로드 후 수행)
                if !isInitialized {
                    // UI가 완전히 로드된 후 실행
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        initializeAppDownloads()
                        
                        // 현재 다운로드 중인 모든 앱에 대해 프로그레스 알림 즉시 전송
                        for (appId, downloadInfo) in downloadManager.downloads {
                            if case .downloading(let progress) = downloadInfo.state {
                                // 0.1초 간격으로 초기 프로그레스 알림 여러 번 전송 (UI 갱신 보장)
                                for i in 0..<3 {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1 * Double(i)) {
                                        NotificationCenter.default.post(
                                            name: .downloadProgressUpdated,
                                            object: nil,
                                            userInfo: ["appId": appId, "progress": progress]
                                        )
                                    }
                                }
                            }
                        }
                    }
                    isInitialized = true
                }
            }
            .environmentObject(downloadManager)
            
            // 네트워크 알림 오버레이
            if networkAlertManager.showNetworkAlert {
                VStack {
                    NetworkAlertView(
                        isDisconnected: networkAlertManager.isDisconnected,
                        message: networkAlertManager.alertMessage,
                        isPresented: $networkAlertManager.showNetworkAlert
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                    
                    Spacer()
                }
                .zIndex(100) // 항상 최상위에 표시
                .animation(.easeInOut(duration: 0.3), value: networkAlertManager.showNetworkAlert)
                .padding(.top, 8)
            }
        }
    }
    
    // 앱 다운로드 초기화 및 타이머 확인 함수
    private func initializeAppDownloads() {
        // 다운로드 매니저에서 모든 다운로드 상태 확인
        for (appId, downloadInfo) in downloadManager.downloads {
            if case .downloading = downloadInfo.state {
                // 다운로드 중인 앱은 타이머 강제 재시작
                DispatchQueue.global(qos: .userInitiated).async {
                    downloadManager.ensureTimerRunning(for: appId)
                }
            }
        }
        
        // 모든 상태 즉시 브로드캐스트
        downloadManager.broadcastInitialStates()
        
        // 전체 상태 변경 알림 발송
        NotificationCenter.default.post(name: .downloadStateChanged, object: nil)
    }
}


// 구현되지 않은 탭을 위한 임시 뷰들
struct TodayPlaceholderView: View {
    var body: some View {
        VStack {
            Image(systemName: "doc.text.image")
                .font(.system(size: 80))
                .foregroundColor(.gray.opacity(0.5))
                .padding(.bottom)
            
            Text("투데이 탭")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.bottom, 4)
            
            Text("투데이 탭은 이 과제에서 구현되지 않았습니다.")
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }
}

struct GamesPlaceholderView: View {
    var body: some View {
        VStack {
            Image(systemName: "gamecontroller")
                .font(.system(size: 80))
                .foregroundColor(.gray.opacity(0.5))
                .padding(.bottom)
            
            Text("게임 탭")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.bottom, 4)
            
            Text("게임 탭은 이 과제에서 구현되지 않았습니다.")
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }
}

struct ArcadePlaceholderView: View {
    var body: some View {
        VStack {
            Image(systemName: "arcade.stick")
                .font(.system(size: 80))
                .foregroundColor(.gray.opacity(0.5))
                .padding(.bottom)
            
            Text("아케이드 탭")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.bottom, 4)
            
            Text("아케이드 탭은 이 과제에서 구현되지 않았습니다.")
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }
}


