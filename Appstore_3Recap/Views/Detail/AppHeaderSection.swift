//
//  AppHeaderSection.swift
//  Appstore_3Recap
//
//  Created by 권우석 on 4/25/25.
//

import SwiftUI
struct AppHeaderSection: View {
    let app: AppModel
    @State private var downloadState: AppDownloadState
    @State private var progress: Float = 0.0
    // 로딩 완료 추적을 위한 상태 추가
    @State private var isSetup = false
    
    let onDownloadAction: () -> Void
    
    // 초기화 시 다운로드 상태 설정
    init(app: AppModel, downloadState: AppDownloadState, onDownloadAction: @escaping () -> Void) {
        self.app = app
        self._downloadState = State(initialValue: downloadState)
        self._progress = State(initialValue: downloadState.progress)
        self.onDownloadAction = onDownloadAction
    }
    
    // 현재 다운로드 상태 계산 프로퍼티
    private var currentState: AppDownloadState {
        if case .downloading = downloadState {
            return .downloading(progress)
        } else {
            return downloadState
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // 앱 아이콘
            AsyncImageView(url: app.iconURL, placeholderImageName: "app.fill", cornerRadius: 16)
                .frame(width: 120, height: 120)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(app.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .lineLimit(2)
                
                Text(app.developerName)
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                
                Spacer()
                
                // 다운로드 버튼 - 현재 상태 기반으로 생성
                AppDownloadButton(app: app, state: currentState, action: onDownloadAction)
                    .frame(height: 32)
            }
        }
        .frame(height: 120)
        // 다운로드 프로그레스 업데이트 알림 수신
        .onReceive(
            NotificationCenter.default.publisher(for: .downloadProgressUpdated)
                .filter { ($0.userInfo?["appId"] as? String) == app.id }
        ) { notification in
            if let newProgress = notification.userInfo?["progress"] as? Float {
                withAnimation(.linear(duration: 0.1)) {
                    self.progress = newProgress
                }
            }
        }
        // 다운로드 상태 변경 알림 수신
        .onReceive(
            NotificationCenter.default.publisher(for: .downloadButtonStateChanged)
                .filter { ($0.userInfo?["appId"] as? String) == app.id }
        ) { _ in
            if let downloadInfo = AppDownloadManager.shared.downloads[app.id] {
                withAnimation {
                    self.downloadState = downloadInfo.state
                    self.progress = downloadInfo.state.progress
                }
            }
        }
        // 뷰가 처음 나타날 때와 매번 업데이트될 때마다 최신 상태 확인
        .onAppear {
            // 상태 즉시 갱신
            updateCurrentState()
            
            // 다운로드 중이면 즉시 업데이트 트리거
            if case .downloading = downloadState {
                // 즉시 프로그레스 업데이트 알림 발송
                NotificationCenter.default.post(
                    name: .downloadProgressUpdated,
                    object: nil,
                    userInfo: ["appId": app.id, "progress": progress]
                )
            }
        }
        // 최초 진입 시 추가 작업 트리거
        .task {
            if !isSetup {
                // 다운로드 중인 경우 타이머가 동작 중인지 확인하고
                // 동작하지 않으면 재시작
                if case .downloading = downloadState,
                   let downloadInfo = AppDownloadManager.shared.downloads[app.id] {
                    // 강제로 타이머 재시작 트리거
                    DispatchQueue.global(qos: .userInitiated).async {
                        AppDownloadManager.shared.ensureTimerRunning(for: app.id)
                    }
                }
                isSetup = true
            }
        }
    }
    
    // 현재 다운로드 매니저에서 최신 상태 가져오기
    private func updateCurrentState() {
        if let downloadInfo = AppDownloadManager.shared.downloads[app.id] {
            self.downloadState = downloadInfo.state
            self.progress = downloadInfo.state.progress
        }
    }
}
