//
//  AppDetailView.swift
//  Appstore_3Recap
//
//  Created by 권우석 on 4/25/25.
//

import SwiftUI

struct AsyncAppDetailView: View {
    @State var viewModel: AppDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var downloadManager: AppDownloadManager
    
    @State private var showingScreenshotViewer = false
    // 프로그레스 업데이트를 위한 로컬 상태 추가
    @State private var localProgress: Float = 0
    @State private var downloadState: AppDownloadState = .notDownloaded
    // View 관련 최적화를 위한 변수
    @State private var isInitialized = false
    
    var body: some View {
        ScrollView {
            if let app = viewModel.app {
                VStack(alignment: .leading, spacing: 16) {
                    // 상단 정보 섹션 - 최적화된 버전 사용
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
                            
                            // 최적화된 다운로드 버튼
                            Button(action: handleDownloadAction) {
                                switch downloadState {
                                case .notDownloaded:
                                    // 받기 버튼
                                    Text(downloadState.buttonText)
                                        .fontWeight(.medium)
                                        .foregroundColor(.appStoreBlue)
                                        .frame(height: 28)
                                        .frame(minWidth: 70)
                                        .background(Color.secondaryBackground)
                                        .cornerRadius(14)
                                
                                case .downloading(let progress):
                                    // 다운로드 중 - 프로그레스 표시
                                    ZStack {
                                        Circle()
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                                            .frame(width: 28, height: 28)
                                        
                                        // 프로그레스 서클 - 애니메이션 없이 즉시 업데이트
                                        Circle()
                                            .trim(from: 0, to: CGFloat(localProgress))
                                            .stroke(Color.appStoreBlue, lineWidth: 2)
                                            .frame(width: 28, height: 28)
                                            .rotationEffect(.degrees(-90))
                                        
                                        Image(systemName: "pause.fill")
                                            .foregroundColor(.appStoreBlue)
                                            .font(.system(size: 10, weight: .bold))
                                    }
                                    .frame(width: 28, height: 28)
                                
                                case .paused(let progress):
                                    // 재개 버튼
                                    HStack(spacing: 4) {
                                        Image(systemName: "icloud.and.arrow.down")
                                            .font(.system(size: 12))
                                        Text(downloadState.buttonText)
                                    }
                                    .fontWeight(.medium)
                                    .foregroundColor(.appStoreBlue)
                                    .frame(height: 28)
                                    .frame(minWidth: 70)
                                    .background(Color.secondaryBackground)
                                    .cornerRadius(14)
                                
                                case .downloaded:
                                    // 열기 버튼
                                    Text(downloadState.buttonText)
                                        .fontWeight(.medium)
                                        .foregroundColor(.appStoreBlue)
                                        .frame(height: 28)
                                        .frame(minWidth: 70)
                                        .background(Color.secondaryBackground)
                                        .cornerRadius(14)
                                    
                                case .redownload:
                                    // 다시받기 버튼
                                    Image(systemName: "icloud.and.arrow.down")
                                        .font(.system(size: 16))
                                        .foregroundColor(.appStoreBlue)
                                        .frame(width: 28, height: 28)
                                        .background(Color.secondaryBackground)
                                        .clipShape(Circle())
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            .frame(height: 32)
                        }
                    }
                    .frame(height: 120)
                    .padding(.top)
                    .padding(.horizontal)
                    
                    // 나머지 뷰 내용 (변경 없음)
                    Divider()
                    
                    AppInfoSection(app: app)
                        .padding(.horizontal)
                    
                    Divider()
                    
                    if !app.releaseNotes.isEmpty {
                        ReleaseNotesSection(
                            releaseNotes: app.releaseNotes,
                            isExpanded: viewModel.isDescriptionExpanded,
                            onToggle: {
                                viewModel.toggleDescription()
                            }
                        )
                        .padding(.horizontal)
                        
                        Divider()
                    }
                    
                    ScreenshotSection(
                        screenshotURLs: app.effectiveScreenshotURLs,
                        onScreenshotTap: { index in
                            viewModel.selectScreenshot(at: index)
                            showingScreenshotViewer = true
                        }
                    )
                    .padding(.horizontal)
                    
                    Divider()
                    
                    AppDescriptionSection(
                        description: app.description,
                        isExpanded: viewModel.isDescriptionExpanded,
                        onToggle: {
                            viewModel.toggleDescription()
                        }
                    )
                    .padding(.horizontal)
                    
                    Spacer(minLength: 40)
                }
            } else if viewModel.isLoading {
                LoadingIndicator()
            } else if let errorMessage = viewModel.errorMessage {
                NetworkErrorView(
                    error: APIError.networkError(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: errorMessage])),
                    retryAction: {
                        if let app = viewModel.app {
                            viewModel.loadAppDetail(appId: app.id)
                        }
                    }
                )
            }
        }
        .background(Color.appBackground)
        .sheet(isPresented: $showingScreenshotViewer) {
            if let app = viewModel.app,
               let selectedIndex = viewModel.selectedScreenshotIndex {
                ScreenshotViewer(
                    screenshotURLs: app.effectiveScreenshotURLs,
                    initialIndex: selectedIndex
                )
                .edgesIgnoringSafeArea(.all)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
            }
        }
        // 초기화 및 프로그레스 설정
        .task {
            if !isInitialized {
                updateDownloadState()
                isInitialized = true
                
                // 다운로드 중인 경우 즉시 타이머 확인
                if case .downloading = downloadState, let appId = viewModel.app?.id {
                    DispatchQueue.global(qos: .userInitiated).async {
                        downloadManager.ensureTimerRunning(for: appId)
                    }
                }
            }
        }
        // 프로그레스 업데이트 알림 수신 - 높은 빈도로 수신
        .onReceive(
            NotificationCenter.default.publisher(for: .downloadProgressUpdated)
                .filter { ($0.userInfo?["appId"] as? String) == viewModel.app?.id }
        ) { notification in
            if let newProgress = notification.userInfo?["progress"] as? Float {
                // 애니메이션 없이 값만 즉시 변경 (UI 프리징 방지)
                self.localProgress = newProgress
            }
        }
        // 버튼 상태 변경 알림 수신
        .onReceive(
            NotificationCenter.default.publisher(for: .downloadButtonStateChanged)
                .filter { ($0.userInfo?["appId"] as? String) == viewModel.app?.id }
        ) { _ in
            updateDownloadState()
        }
        // 앱이 활성화될 때 상태 갱신
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                updateDownloadState()
                
                // 다운로드 진행 중인 경우 타이머 재확인
                if case .downloading = downloadState, let appId = viewModel.app?.id {
                    downloadManager.ensureTimerRunning(for: appId)
                }
            }
        }
    }
    
    // 다운로드 상태 업데이트 (최적화)
    private func updateDownloadState() {
        guard let app = viewModel.app else { return }
        
        if let downloadInfo = downloadManager.downloads[app.id] {
            // 상태 업데이트
            let newState = downloadInfo.state
            
            // 상태가 변경된 경우에만 UI 업데이트
            if downloadState != newState || abs(localProgress - newState.progress) > 0.01 {
                downloadState = newState
                localProgress = newState.progress
            }
        } else {
            downloadState = .notDownloaded
            localProgress = 0.0
        }
    }
    
    private func handleDownloadAction() {
        guard let app = viewModel.app else { return }
        
        // 현재 상태에 따라 분기
        switch downloadState {
        case .notDownloaded, .redownload:
            // 즉시 로컬 상태 업데이트 (애니메이션 없이)
            downloadState = .downloading(0.0)
            localProgress = 0.0
            
            // 백그라운드에서 다운로드 시작
            DispatchQueue.global(qos: .userInitiated).async {
                downloadManager.startDownload_modified(for: app)
            }
            
        case .downloading:
            // 즉시 로컬 상태 업데이트 (애니메이션 없이)
            let currentProgress = localProgress
            downloadState = .paused(currentProgress)
            
            // 백그라운드에서 일시정지
            DispatchQueue.global(qos: .userInitiated).async {
                downloadManager.pauseDownload_modified(for: app.id)
            }
            
        case .paused:
            // 즉시 로컬 상태 업데이트 (애니메이션 없이)
            let currentProgress = localProgress
            downloadState = .downloading(currentProgress)
            
            // 백그라운드에서 재개
            DispatchQueue.global(qos: .userInitiated).async {
                downloadManager.startDownload_modified(for: app)
            }
            
        case .downloaded:
            // 이미 설치된 앱은 별도의 동작 없음
            break
        }
    }
}

// 실시간 업데이트에 최적화된 앱 헤더 섹션
struct EnhancedAppHeaderSection: View {
    let app: AppModel
    let downloadState: AppDownloadState
    let progress: Float
    let onDownloadAction: () -> Void
    
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
                
                // 최적화된 다운로드 버튼
                EnhancedDownloadButton(app: app, state: currentState, action: onDownloadAction)
                    .frame(height: 32)
            }
        }
        .frame(height: 120)
    }
}

// 실시간 업데이트에 최적화된 다운로드 버튼
struct EnhancedDownloadButton: View {
    let app: AppModel
    let state: AppDownloadState
    let action: () -> Void
    
    // 프로그레스 애니메이션 추적
    @State private var animatedProgress: Float = 0
    
    var body: some View {
        Button(action: action) {
            switch state {
            case .notDownloaded:
                // 받기 버튼
                Text(state.buttonText)
                    .fontWeight(.medium)
                    .foregroundColor(.appStoreBlue)
                    .frame(height: 28)
                    .frame(minWidth: 70)
                    .background(Color.secondaryBackground)
                    .cornerRadius(14)
            
            case .downloading(let progress):
                // 다운로드 중 - 프로그레스 표시
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 28, height: 28)
                    
                    // 부드러운 프로그레스 애니메이션
                    Circle()
                        .trim(from: 0, to: CGFloat(animatedProgress))
                        .stroke(Color.appStoreBlue, lineWidth: 2)
                        .frame(width: 28, height: 28)
                        .rotationEffect(.degrees(-90))
                    
                    Image(systemName: "pause.fill")
                        .foregroundColor(.appStoreBlue)
                        .font(.system(size: 10, weight: .bold))
                }
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
            
            case .paused(let progress):
                // 재개 버튼
                HStack(spacing: 4) {
                    Image(systemName: "icloud.and.arrow.down")
                        .font(.system(size: 12))
                    Text(state.buttonText)
                }
                .fontWeight(.medium)
                .foregroundColor(.appStoreBlue)
                .frame(height: 28)
                .frame(minWidth: 70)
                .background(Color.secondaryBackground)
                .cornerRadius(14)
            
            case .downloaded:
                // 열기 버튼
                Text(state.buttonText)
                    .fontWeight(.medium)
                    .foregroundColor(.appStoreBlue)
                    .frame(height: 28)
                    .frame(minWidth: 70)
                    .background(Color.secondaryBackground)
                    .cornerRadius(14)
                
            case .redownload:
                // 다시받기 버튼
                Image(systemName: "icloud.and.arrow.down")
                    .font(.system(size: 16))
                    .foregroundColor(.appStoreBlue)
                    .frame(width: 28, height: 28)
                    .background(Color.secondaryBackground)
                    .clipShape(Circle())
            }
        }
        .buttonStyle(PlainButtonStyle())
        // 고유 ID 부여로 상태 변경 시 강제 리렌더링 방지
        .id("download-btn-\(app.id)")
        .onChange(of: state) { _, newState in
            // 프로그레스 값 변경 시 애니메이션 적용
            if case .downloading(let progress) = newState {
                // 짧은 애니메이션으로 부드럽게 전환 (UI 프리징 방지)
                withAnimation(.linear(duration: 0.15)) {
                    animatedProgress = progress
                }
            } else if case .paused(let progress) = newState {
                // 일시정지 상태는 애니메이션 없이 즉시 반영
                animatedProgress = progress
            }
        }
        // 뷰가 나타날 때 초기 값 설정
        .onAppear {
            // 초기값 설정 (애니메이션 없이)
            if case .downloading(let progress) = state {
                animatedProgress = progress
            } else if case .paused(let progress) = state {
                animatedProgress = progress
            } else {
                animatedProgress = state.progress
            }
        }
    }
}

final class ImageCache {
    static let shared = ImageCache()
    private var cache = NSCache<NSString, UIImage>()
    
    private init() {
        cache.countLimit = 100 // 캐시 항목 최대 개수
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB 제한
    }
    
    func set(_ image: UIImage, for key: String) {
        // 이미지 크기에 비례하여 비용 계산
        let cost = Int(image.size.width * image.size.height * 4) // RGBA 4바이트
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }
    
    func get(for key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }
    
    func clear() {
        cache.removeAllObjects()
    }
}
