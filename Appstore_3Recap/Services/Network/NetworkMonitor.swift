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
            self?.isConnected = path.status == .satisfied
            self?.getConnectionType(path)
            
            // 연결 상태 변경 알림 전송
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: self?.isConnected == true ? .networkConnected : .networkDisconnected,
                    object: nil
                )
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

// MARK: - 알림 확장
extension Notification.Name {
    static let networkConnected = Notification.Name("networkConnected")
    static let networkDisconnected = Notification.Name("networkDisconnected")
}
