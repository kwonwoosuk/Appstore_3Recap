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
    private var currentPage = 0  // 페이지 번호를 0부터 시작하도록 변경
    private let itemsPerPage = 20
    private var lastSearchTask: Task<Void, Never>? = nil
    private var loadedAppIds = Set<String>() // 이미 로드된 앱 ID를 추적
    private var noMoreResults = false // 더 이상 결과가 없음을 표시
    private var totalSearchCount = 0 // 검색된 총 아이템 수를 추적
    
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
        currentPage = 0  // 페이지 번호 초기화 (0부터 시작)
        loadedAppIds.removeAll() // 앱 ID 추적 초기화
        noMoreResults = false // 결과 없음 플래그 초기화
        totalSearchCount = 0 // 검색 결과 카운트 초기화
        
        lastSearchTask = Task { @MainActor in
            do {
                // offset 0으로 첫 페이지 요청
                let offset = currentPage * itemsPerPage
                let apps = try await networkService.searchApps(query: searchQuery, offset: offset)
                
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
                totalSearchCount += uniqueApps.count
                
                // 가져온 결과가 요청한 항목 수보다 적으면 더 이상 결과가 없음
                hasMoreResults = uniqueApps.count >= itemsPerPage
                noMoreResults = uniqueApps.isEmpty // 결과가 없으면 더 로드하지 않음
                isLoading = false
                
                print("초기 검색 완료: \(uniqueApps.count)개 항목 로드됨, 더 불러올 결과: \(hasMoreResults)")
            } catch is CancellationError {
                // 작업이 취소된 경우 아무것도 하지 않음
            } catch let error as APIError {
                errorMessage = error.message
                isLoading = false
                print("검색 오류: \(error.message)")
            } catch {
                errorMessage = "알 수 없는 오류가 발생했습니다."
                isLoading = false
                print("알 수 없는 검색 오류: \(error)")
            }
        }
    }
    
    func loadMoreResults() {
        guard !isLoading, hasMoreResults, !searchQuery.isEmpty, !noMoreResults else {
            print("추가 로드 조건 실패: isLoading=\(isLoading), hasMoreResults=\(hasMoreResults), emptyQuery=\(searchQuery.isEmpty), noMoreResults=\(noMoreResults)")
            return
        }
        
        currentPage += 1
        isLoading = true
        
        let offset = currentPage * itemsPerPage
        print("페이지 \(currentPage) 로드 시작, offset: \(offset)")
        
        lastSearchTask = Task { @MainActor in
            do {
                let newApps = try await networkService.searchApps(query: searchQuery, offset: offset)
                
                // Task가 취소되었는지 확인
                try Task.checkCancellation()
                
                print("페이지 \(currentPage) 로드 완료: \(newApps.count)개 항목 반환됨")
                
                // 중복 제거
                let uniqueApps = newApps.filter { app in
                    !loadedAppIds.contains(app.id)
                }
                
                print("중복 제거 후 \(uniqueApps.count)개 항목")
                
                // 새로운 결과가 없으면 더 이상 로드하지 않음
                if uniqueApps.isEmpty {
                    hasMoreResults = false
                    noMoreResults = true
                    isLoading = false
                    print("더 이상 고유한 결과가 없습니다. 페이지네이션 중단")
                    return
                }
                
                // 앱 ID 추적에 추가
                uniqueApps.forEach { app in
                    loadedAppIds.insert(app.id)
                }
                
                searchResults.append(contentsOf: uniqueApps)
                totalSearchCount += uniqueApps.count
                
                // 가져온 결과가 요청한 항목 수보다 적으면 더 이상 결과가 없음
                hasMoreResults = uniqueApps.count >= itemsPerPage
                isLoading = false
                
                print("현재까지 총 \(totalSearchCount)개 항목 로드됨, 더 불러올 결과: \(hasMoreResults)")
            } catch is CancellationError {
                // 작업이 취소된 경우 아무것도 하지 않음
            } catch {
                currentPage -= 1 // 로드 실패 시 페이지 번호 롤백
                isLoading = false
                print("추가 페이지 로드 오류: \(error)")
            }
        }
    }
    
    // MARK: - 검색 초기화
    func resetSearch() {
        // 검색 취소 시 모든 결과와 에러 초기화
        searchResults = []
        errorMessage = nil
        hasMoreResults = false
        currentPage = 0
        hasSearched = false  // 검색 실행 여부 리셋
        loadedAppIds.removeAll() // 앱 ID 추적 초기화
        noMoreResults = false // 결과 없음 플래그 초기화
        totalSearchCount = 0 // 검색 결과 카운트 초기화
        
        // 진행중인 검색 작업 취소
        lastSearchTask?.cancel()
        lastSearchTask = nil
        isLoading = false
    }
    
    func refreshResults() {
        currentPage = 0
        loadedAppIds.removeAll() // 앱 ID 추적 초기화
        noMoreResults = false // 결과 없음 플래그 초기화
        totalSearchCount = 0 // 검색 결과 카운트 초기화
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
