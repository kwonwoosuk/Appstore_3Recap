//
//  UserAppsViewModel.swift
//  Appstore_3Recap
//
//  Created by 권우석 on 4/25/25.
//

import Foundation
import SwiftUI
import Combine

@Observable
class UserAppsViewModel {
    // MARK: - 입력
    var searchQuery = ""
    
    // MARK: - 출력
    var installedApps: [AppModel] = []
    var filteredApps: [AppModel] = []
    
    // MARK: - 프로퍼티
    private let downloadManager: AppDownloadManager
    private var cancellable: AnyCancellable?
    
    // MARK: - 초기화
    init(downloadManager: AppDownloadManager = .shared) {
        self.downloadManager = downloadManager
        
        // 앱 목록 업데이트 구독
        cancellable = downloadManager.$installedApps
            .sink { [weak self] apps in
                guard let self = self else { return }
                self.installedApps = apps
                self.filterApps()
            }
        
        // 초기 데이터 로드
        installedApps = downloadManager.installedApps
        filterApps()
    }
    
    // MARK: - 앱 필터링
    func filterApps() {
        let query = searchQuery.lowercased()
        
        if query.isEmpty {
            filteredApps = installedApps
        } else {
            filteredApps = installedApps.filter {
                $0.name.lowercased().contains(query)
            }
        }
    }
    
    // MARK: - 앱 삭제
    func deleteApp(withId appId: String) {
        downloadManager.deleteApp(withId: appId)
        // filterApps()는 필요하지 않음 - Publisher가 자동으로 업데이트됨
    }
    
    // MARK: - 검색 쿼리 업데이트
    func updateSearchQuery(_ query: String) {
        searchQuery = query
        filterApps()
    }
}
