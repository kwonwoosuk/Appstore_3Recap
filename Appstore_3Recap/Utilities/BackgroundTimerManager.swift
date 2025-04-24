//
//  BackgroundTimerManager.swift
//  Appstore_3Recap
//
//  Created by 권우석 on 4/25/25.
//

import Foundation
import UIKit
import Combine

class BackgroundTimerManager {
    static let shared = BackgroundTimerManager()
    
    // 실행 중인 타이머 목록
    private var timers: [String: TimerInfo] = [:]
    private var backgroundDate: Date?
    private var wasTerminated = false
    
    // UserDefaults 키
    private let timersKey = "backgroundTimers"
    private let backgroundDateKey = "backgroundDate"
    
    private var cancellables = Set<AnyCancellable>()
    
    struct TimerInfo: Codable {
        let id: String
        var startDate: Date
        let duration: TimeInterval
        var elapsedTime: TimeInterval
        var progress: Float
        
        var isComplete: Bool {
            return progress >= 1.0
        }
    }
    
    private init() {
        setupNotifications()
        loadState()
    }
    
    // MARK: - 타이머 관리
    
    func startTimer(id: String, duration: TimeInterval, elapsedTime: TimeInterval = 0) {
        let startDate = Date()
        let progress = Float(elapsedTime / duration)
        
        let timerInfo = TimerInfo(
            id: id,
            startDate: startDate,
            duration: duration,
            elapsedTime: elapsedTime,
            progress: progress
        )
        
        timers[id] = timerInfo
        saveState()
    }
    
    func stopTimer(id: String) {
        timers.removeValue(forKey: id)
        saveState()
    }
    
    func getProgress(for id: String) -> Float? {
        guard let timerInfo = timers[id] else { return nil }
        
        let elapsedTime = timerInfo.elapsedTime + Date().timeIntervalSince(timerInfo.startDate)
        let progress = Float(min(1.0, elapsedTime / timerInfo.duration))
        
        return progress
    }
    
    func isTimerComplete(id: String) -> Bool {
        guard let progress = getProgress(for: id) else { return false }
        return progress >= 1.0
    }
    
    func getAllCompletedTimers() -> [String] {
        return timers.compactMap { id, timerInfo in
            getProgress(for: id) ?? 0.0 >= 1.0 ? id : nil
        }
    }
    
    // MARK: - 백그라운드 처리
    
    private func setupNotifications() {
        // 앱이 백그라운드로 전환될 때
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.handleAppEnteringBackground()
            }
            .store(in: &cancellables)
        
        // 앱이 포그라운드로 돌아올 때
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.handleAppEnteringForeground()
            }
            .store(in: &cancellables)
        
        // 앱이 종료될 때
        NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)
            .sink { [weak self] _ in
                self?.handleAppTermination()
            }
            .store(in: &cancellables)
    }
    
    private func handleAppEnteringBackground() {
        // 현재 시간 저장
        backgroundDate = Date()
        
        // 현재 상태 업데이트 (진행 상황)
        for (id, var timerInfo) in timers {
            let elapsedTime = timerInfo.elapsedTime + Date().timeIntervalSince(timerInfo.startDate)
            timerInfo.progress = Float(min(1.0, elapsedTime / timerInfo.duration))
            timerInfo.elapsedTime = elapsedTime
            timers[id] = timerInfo
        }
        
        saveState()
    }
    
    private func handleAppEnteringForeground() {
        if let backgroundDate = backgroundDate {
            let elapsedTime = Date().timeIntervalSince(backgroundDate)
            processBackgroundTime(elapsedTime)
        }
        
        self.backgroundDate = nil
        saveState()
    }
    
    private func handleAppTermination() {
        backgroundDate = Date()
        wasTerminated = true
        saveState()
    }
    
    private func processBackgroundTime(_ elapsedTime: TimeInterval) {
        // 백그라운드에서 경과한 시간에 따라 타이머 업데이트
        for (id, var timerInfo) in timers {
            let newElapsedTime = timerInfo.elapsedTime + elapsedTime
            let newProgress = Float(min(1.0, newElapsedTime / timerInfo.duration))
            
            timerInfo.elapsedTime = newElapsedTime
            timerInfo.progress = newProgress
            timerInfo.startDate = Date() // 새로운 시작 시간
            
            timers[id] = timerInfo
        }
        
        saveState()
        
        // 완료된 타이머 알림
        let completedTimers = getAllCompletedTimers()
        if !completedTimers.isEmpty {
            NotificationCenter.default.post(name: .timersCompleted, object: completedTimers)
        }
    }
    
    // MARK: - 상태 저장 및 로드
    
    private func saveState() {
        do {
            let encodedTimers = try JSONEncoder().encode(timers)
            UserDefaults.standard.set(encodedTimers, forKey: timersKey)
            
            if let backgroundDate = backgroundDate {
                UserDefaults.standard.set(backgroundDate.timeIntervalSince1970, forKey: backgroundDateKey)
            } else {
                UserDefaults.standard.removeObject(forKey: backgroundDateKey)
            }
        } catch {
            print("Error saving timer state: \(error)")
        }
    }
    
    private func loadState() {
        if let encodedTimers = UserDefaults.standard.data(forKey: timersKey) {
            do {
                timers = try JSONDecoder().decode([String: TimerInfo].self, from: encodedTimers)
            } catch {
                print("Error loading timers: \(error)")
                timers = [:]
            }
        }
        
        if let timestamp = UserDefaults.standard.object(forKey: backgroundDateKey) as? TimeInterval {
            backgroundDate = Date(timeIntervalSince1970: timestamp)
            wasTerminated = true
        }
    }
}

// MARK: - 알림 확장
extension Notification.Name {
    static let timersCompleted = Notification.Name("timersCompleted")
}

// MARK: - 다운로드 매니저에서 BackgroundTimerManager 활용
extension AppDownloadManager {
    // BackgroundTimerManager와 통합하는 코드
    func initializeBackgroundTimers() {
        // 기존의 다운로드 정보를 BackgroundTimerManager로 이전
        for (appId, downloadInfo) in downloads {
            if case .downloading(let progress) = downloadInfo.state {
                let elapsedTime = downloadInfo.downloadElapsedTime
                let remainingTime = downloadDuration * (1.0 - Double(progress))
                
                BackgroundTimerManager.shared.startTimer(
                    id: appId,
                    duration: downloadDuration,
                    elapsedTime: elapsedTime
                )
            }
        }
        
        // 타이머 완료 알림 구독
        NotificationCenter.default.publisher(for: .timersCompleted)
            .sink { [weak self] notification in
                if let completedTimers = notification.object as? [String] {
                    self?.handleCompletedTimers(completedTimers)
                }
            }
            .store(in: &cancellables)
    }
    
}
