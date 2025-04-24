//
//  SearchViewModel.swift
//  Appstore_3Recap
//
//  Created by 권우석 on 4/25/25.
//

import Foundation
import Combine
import SwiftUI

@Observable
class SearchViewModel {
    // MARK: - Input
    var searchQuery = ""
    
    // MARK: - Output
    var searchResults: [AppModel] = []
    var isLoading = false
    var errorMessage: String? = nil
    var selectedApp: AppModel? = nil
    var hasMoreResults = false
    var hasSearched = false  // 검색 실행 여부를 추적하는 플래그
    
    // MARK: - Properties
    private var currentPage = 1
    private let itemsPerPage = 20
    private var lastSearchTask: Task<Void, Never>? = nil
    private var loadedAppIds = Set<String>() // 이미 로드된 앱 ID를 추적
    private var noMoreResults = false // 더 이상 결과가 없음을 표시
    
    private let networkService: NetworkService
    private let downloadManager: AppDownloadManager
    
    // MARK: - Initialization
    init(networkService: NetworkService = .shared,
         downloadManager: AppDownloadManager = .shared) {
        self.networkService = networkService
        self.downloadManager = downloadManager
    }
    
    // MARK: - 검색 작업
    func searchApps() {
        // 이전 검색 작업 취소
        lastSearchTask?.cancel()
        
        guard !searchQuery.isEmpty && searchQuery.count > 1 else {
            hasSearched = false  // 검색어가 충분하지 않으면 검색 실행 안함
            return
        }
        
        // 검색 플래그 활성화 (리턴키로 검색 실행 시)
        hasSearched = true
        isLoading = true
        errorMessage = nil
        currentPage = 1
        loadedAppIds.removeAll() // 앱 ID 추적 초기화
        noMoreResults = false // 결과 없음 플래그 초기화
        
        lastSearchTask = Task { @MainActor in
            do {
                let apps = try await networkService.searchApps(query: searchQuery)
                
                // Task가 취소되었는지 확인
                try Task.checkCancellation()
                
                // 중복 제거
                let uniqueApps = apps.filter { app in
                    !loadedAppIds.contains(app.id)
                }
                
                // 앱 ID 추적에 추가
                uniqueApps.forEach { app in
                    loadedAppIds.insert(app.id)
                }
                
                searchResults = uniqueApps
                hasMoreResults = uniqueApps.count >= itemsPerPage
                noMoreResults = uniqueApps.isEmpty // 결과가 없으면 더 로드하지 않음
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
    
    func loadMoreResults() {
        guard !isLoading, hasMoreResults, !searchQuery.isEmpty, !noMoreResults else { return }
        
        currentPage += 1
        isLoading = true
        
        lastSearchTask = Task { @MainActor in
            do {
                let newApps = try await networkService.searchApps(query: searchQuery)
                
                // Task가 취소되었는지 확인
                try Task.checkCancellation()
                
                // 중복 제거
                let uniqueApps = newApps.filter { app in
                    !loadedAppIds.contains(app.id)
                }
                
                // 새로운 결과가 없으면 더 이상 로드하지 않음
                if uniqueApps.isEmpty {
                    hasMoreResults = false
                    noMoreResults = true
                    isLoading = false
                    return
                }
                
                // 앱 ID 추적에 추가
                uniqueApps.forEach { app in
                    loadedAppIds.insert(app.id)
                }
                
                searchResults.append(contentsOf: uniqueApps)
                hasMoreResults = uniqueApps.count >= itemsPerPage
                isLoading = false
            } catch is CancellationError {
                // 작업이 취소된 경우 아무것도 하지 않음
            } catch {
                currentPage -= 1 // 로드 실패 시 페이지 번호 롤백
                isLoading = false
            }
        }
    }
    
    // MARK: - 검색 초기화
    func resetSearch() {
        // 검색 취소 시 모든 결과와 에러 초기화
        searchResults = []
        errorMessage = nil
        hasMoreResults = false
        currentPage = 1
        hasSearched = false  // 검색 실행 여부 리셋
        loadedAppIds.removeAll() // 앱 ID 추적 초기화
        noMoreResults = false // 결과 없음 플래그 초기화
        
        // 진행중인 검색 작업 취소
        lastSearchTask?.cancel()
        lastSearchTask = nil
        isLoading = false
    }
    
    func refreshResults() {
        currentPage = 1
        loadedAppIds.removeAll() // 앱 ID 추적 초기화
        noMoreResults = false // 결과 없음 플래그 초기화
        searchApps()
    }
    
    func selectApp(_ app: AppModel) {
        selectedApp = app
    }
    
    // MARK: - 다운로드 관련 메서드
    func getDownloadState(for appId: String) -> AppDownloadState {
        return downloadManager.downloads[appId]?.state ?? .notDownloaded
    }
    
    func startDownload(for app: AppModel) {
        downloadManager.startDownload(for: app)
    }
    
    func pauseDownload(for appId: String) {
        downloadManager.pauseDownload(for: appId)
    }
    
    deinit {
        lastSearchTask?.cancel()
    }
}
