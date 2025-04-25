//
//  NetworkMonitor.swift
//  Appstore_3Recap
//
//  Created by 권우석 on 4/25/25.
//

import Foundation
import Network

// 네트워크 연결 상태 모니터링 클래스
class NetworkMonitor {
    static let shared = NetworkMonitor()
    
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    private(set) var isConnected: Bool = true
    private(set) var connectionType: ConnectionType = .unknown
    
    // 최초 상태 변경 여부를 추적
    private var isFirstUpdate = true
    
    // 연결 유형
    enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
    }
    
    private init() {
        monitor = NWPathMonitor()
        startMonitoring()
    }
    
    // 모니터링 시작
    private func startMonitoring() {
        monitor.start(queue: queue)
        
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            let newConnectionStatus = path.status == .satisfied
            
            // 현재 상태가 변경되었을 때만 알림 전송 (첫 상태 업데이트는 제외)
            if !self.isFirstUpdate && self.isConnected != newConnectionStatus {
                self.isConnected = newConnectionStatus
                self.getConnectionType(path)
                
                // 연결 상태 변경 알림 전송
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: self.isConnected ? .networkConnected : .networkDisconnected,
                        object: nil
                    )
                }
            } else {
                // 첫 상태 업데이트 또는 상태가 동일한 경우 - 알림 없이 상태만 업데이트
                self.isConnected = newConnectionStatus
                self.getConnectionType(path)
            }
            
            // 첫 업데이트 후 플래그 해제
            if self.isFirstUpdate {
                self.isFirstUpdate = false
            }
        }
    }
    
    // 연결 유형 확인
    private func getConnectionType(_ path: NWPath) {
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .ethernet
        } else {
            connectionType = .unknown
        }
    }
    
    // 모니터링 중지
    func stopMonitoring() {
        monitor.cancel()
    }
}
