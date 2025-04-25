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
    
    var body: some View {
        ScrollView {
            if let app = viewModel.app {
                VStack(alignment: .leading, spacing: 16) {
                    // 상단 정보 섹션
                    AppHeaderSection(
                        app: app,
                        downloadState: downloadManager.downloads[app.id]?.state ?? .notDownloaded,
                        onDownloadAction: handleDownloadAction
                    )
                    .padding(.top)
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // 앱 정보 섹션 (상단으로 이동)
                    AppInfoSection(app: app)
                        .padding(.horizontal)
                    
                    Divider()
                    
                    // 새로운 소식 (릴리즈 노트) 섹션
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
                    
                    // 스크린샷 섹션 (앱이 열기 상태가 아닌 경우에만 표시)
                    
                        ScreenshotSection(
                            screenshotURLs: app.effectiveScreenshotURLs,
                            onScreenshotTap: { index in
                                viewModel.selectScreenshot(at: index)
                                showingScreenshotViewer = true
                            }
                        )
                        .padding(.horizontal)
                        
                        Divider()
                    
                    
                    // 앱 설명 섹션
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
                .presentationDetents([.large]) // 전체 화면으로 표시
                .presentationDragIndicator(.hidden) // 드래그 인디케이터 숨김
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // 앱이 활성화될 때마다 다운로드 상태 갱신
            if newPhase == .active {
                // 상태 변경 알림
                NotificationCenter.default.post(name: Notification.Name("downloadStateChanged"), object: nil)
            }
        }
        // 다운로드 매니저의 상태가 변경될 때마다 UI 업데이트
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("downloadStateChanged"))) { _ in
            // 뷰 갱신 (UI 업데이트 트리거)
            if let app = viewModel.app {
                let currentApp = app
                viewModel.app = nil
                viewModel.app = currentApp
            }
        }
    }
    
    private func handleDownloadAction() {
        guard let app = viewModel.app else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            switch self.downloadManager.downloads[app.id]?.state ?? .notDownloaded {
            case .notDownloaded, .redownload:
                self.downloadManager.startDownload_modified(for: app)
            case .downloading:
                self.downloadManager.pauseDownload_modified(for: app.id)
            case .paused:
                self.downloadManager.startDownload_modified(for: app)
            case .downloaded:
                
                break
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
