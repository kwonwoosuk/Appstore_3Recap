//
//  AppDetailViewModel.swift
//  Appstore_3Recap
//
//  Created by 권우석 on 4/25/25.
//

import Foundation
import SwiftUI

@Observable
class AppDetailViewModel {
    // MARK: - 출력
    var app: AppModel? = nil
    var isLoading = false
    var errorMessage: String? = nil
    var isDescriptionExpanded = false
    var selectedScreenshotIndex: Int? = nil
    
    // MARK: - 프로퍼티
    private let networkService: NetworkService
    private let downloadManager: AppDownloadManager
    private var detailTask: Task<Void, Never>? = nil
    
    // MARK: - 초기화
    init(app: AppModel? = nil,
         networkService: NetworkService = .shared,
         downloadManager: AppDownloadManager = .shared) {
        self.networkService = networkService
        self.downloadManager = downloadManager
        self.app = app
    }
    
    // MARK: - 앱 상세 정보 로드
    func loadAppDetail(appId: String) {
        // 이전 작업 취소
        detailTask?.cancel()
        
        isLoading = true
        errorMessage = nil
        
        detailTask = Task { @MainActor in
            do {
                let loadedApp = try await networkService.fetchAppDetail(id: appId)
                
                // Task가 취소되었는지 확인
                try Task.checkCancellation()
                
                self.app = loadedApp
                isLoading = false
            } catch is CancellationError {
                // 작업이 취소된 경우 아무것도 하지 않음
            } catch let error as APIError {
                errorMessage = error.message
                isLoading = false
            } catch {
                errorMessage = "알 수 없는 오류가 발생했습니다."
                isLoading = false
            }
        }
    }
    
    // MARK: - UI 상호작용
    func toggleDescription() {
        isDescriptionExpanded.toggle()
    }
    
    func selectScreenshot(at index: Int) {
        selectedScreenshotIndex = index
    }
    
    // MARK: - 다운로드 관련
    func getDownloadState() -> AppDownloadState {
        guard let app = app else { return .notDownloaded }
        return downloadManager.downloads[app.id]?.state ?? .notDownloaded
    }
    
    func startDownload() {
        guard let app = app else { return }
        downloadManager.startDownload(for: app)
    }
    
    func pauseDownload() {
        guard let app = app else { return }
        downloadManager.pauseDownload(for: app.id)
    }
    
    deinit {
        detailTask?.cancel()
    }
}
