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
    
    // 필터링된 앱 목록을 계산 프로퍼티로 변경
    var filteredApps: [AppModel] {
        let query = searchQuery.lowercased()
        if query.isEmpty {
            return installedApps
        } else {
            return installedApps.filter {
                $0.name.lowercased().contains(query)
            }
        }
    }
    
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
                // filterApps() 호출 제거 - 계산 프로퍼티로 대체
            }
        
        // 초기 데이터 로드
        installedApps = downloadManager.installedApps
    }
    
    deinit {
        // 구독 해제
        cancellable?.cancel()
    }
    
    // MARK: - 앱 삭제
    func deleteApp(withId appId: String) {
        downloadManager.deleteApp(withId: appId)
        // 상태 변경은 AppDownloadManager의 Publisher를 통해 자동으로 반영됨
    }
    
    // MARK: - 검색 쿼리 업데이트
    func updateSearchQuery(_ query: String) {
        searchQuery = query
        
    }
}
