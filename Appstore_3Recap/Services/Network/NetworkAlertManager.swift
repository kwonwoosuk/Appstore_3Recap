//
//  NetworkAlertManager.swift
//  Appstore_3Recap
//
//  Created by 권우석 on 4/25/25.
//

import SwiftUI
import Combine

@Observable
class NetworkAlertManager: ObservableObject {
    var showNetworkAlert = false
    var isDisconnected = false
    var alertMessage = ""
    var pausedAppIds: [String] = []
    
    // 이전 네트워크 상태를 추적하는 변수 추가
    private var wasConnectedBefore = true
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupNotifications()
        
        // 초기 네트워크 상태 확인
        wasConnectedBefore = NetworkMonitor.shared.isConnected
    }
    
    private func setupNotifications() {
        // 네트워크 연결 해제 알림 구독
        NotificationCenter.default.publisher(for: .networkDisconnected)
            .sink { [weak self] _ in
                self?.handleNetworkDisconnected()
            }
            .store(in: &cancellables)
        
        // 네트워크 연결 복구 알림 구독
        NotificationCenter.default.publisher(for: .networkConnected)
            .sink { [weak self] _ in
                self?.handleNetworkConnected()
            }
            .store(in: &cancellables)
        
        // 다운로드 일시정지 알림 구독
        NotificationCenter.default.publisher(for: .downloadsPausedDueToNetwork)
            .sink { [weak self] notification in
                if let appIds = notification.object as? [String] {
                    self?.handleDownloadsPaused(appIds: appIds)
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleNetworkDisconnected() {
        DispatchQueue.main.async {
            // 이전에 연결되어 있었을 때만 알림 표시 (앱 시작 시에는 불필요한 알림 방지)
            if self.wasConnectedBefore {
                self.isDisconnected = true
                self.alertMessage = "네트워크 연결이 끊어졌습니다."
                self.showNetworkAlert = true
                
                // 5초 후 알림 자동 닫기
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    withAnimation {
                        self.showNetworkAlert = false
                    }
                }
            }
            
            // 상태 업데이트
            self.wasConnectedBefore = false
        }
    }
    
    private func handleNetworkConnected() {
        DispatchQueue.main.async {
            // 이전에 연결이 끊겼던 경우에만 복구 알림 표시
            if !self.wasConnectedBefore {
                self.isDisconnected = false
                self.alertMessage = "네트워크 연결이 복구되었습니다."
                self.showNetworkAlert = true
                
                // 5초 후 알림 자동 닫기
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    withAnimation {
                        self.showNetworkAlert = false
                    }
                }
            }
            
            // 상태 업데이트
            self.wasConnectedBefore = true
        }
    }
    
    private func handleDownloadsPaused(appIds: [String]) {
        DispatchQueue.main.async {
            // 다운로드가 일시정지된 경우 항상 알림 표시
            if !appIds.isEmpty {
                self.pausedAppIds = appIds
                self.alertMessage = "네트워크 연결이 끊겨 \(appIds.count)개의 다운로드가 일시정지되었습니다."
                self.showNetworkAlert = true
                
                // 5초 후 알림 자동 닫기
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    withAnimation {
                        self.showNetworkAlert = false
                    }
                }
            }
        }
    }
}
