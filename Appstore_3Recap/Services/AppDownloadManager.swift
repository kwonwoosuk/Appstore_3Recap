//
//  AppDownloadManager.swift
//  Appstore_3Recap
//
//  Created by 권우석 on 4/25/25.
//

import Foundation
import Combine
import SwiftUI
import BackgroundTasks

class AppDownloadManager: ObservableObject {
    static let shared = AppDownloadManager()
    
    // 다운로드 정보 관리
    @Published private(set) var downloads: [String: AppDownloadInfo] = [:]
    
    // 설치된 앱 목록
    @Published private(set) var installedApps: [AppModel] = []
    
    // 다운로드 타이머
    private var timers: [String: Timer] = [:]
    let downloadDuration: TimeInterval = 30.0
    
    // 백그라운드 시간 추적
    private var lastBackgroundDate: Date?
    private var wasAppTerminated = false
    
    // UserDefaults 키
    private let installedAppsKey = "installedApps"
    private let downloadsKey = "downloads"
    private let lastBackgroundDateKey = "lastBackgroundDate"
    
    var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupNotifications()
        loadState()
        setupNetworkMonitoring()
    }
    
    // MARK: - 네트워크 모니터링 설정
    private func setupNetworkMonitoring() {
        // 네트워크 연결 끊김 감지
        NotificationCenter.default.publisher(for: .networkDisconnected)
            .sink { [weak self] _ in
                self?.handleNetworkDisconnection()
            }
            .store(in: &cancellables)
        
        // 네트워크 연결 복구 감지
        NotificationCenter.default.publisher(for: .networkConnected)
            .sink { [weak self] _ in
                self?.handleNetworkReconnection()
            }
            .store(in: &cancellables)
    }
    
    // 네트워크 연결 끊김 처리
    private func handleNetworkDisconnection() {
        // 현재 다운로드 중인 모든 앱을 일시 중지 상태로 변경
        for (appId, downloadInfo) in downloads {
            if case .downloading(let progress) = downloadInfo.state {
                pauseDownload(for: appId)
            }
        }
        
        // 상태 변경 알림
        NotificationCenter.default.post(name: Notification.Name("downloadStateChanged"), object: nil)
    }
    
    // 네트워크 연결 복구 처리
    private func handleNetworkReconnection() {
        // 일시 중지된 다운로드가 있으면 알림만 보내고 자동 재개는 하지 않음
        let hasPausedDownloads = downloads.values.contains { downloadInfo in
            if case .paused = downloadInfo.state {
                return true
            }
            return false
        }
        
        if hasPausedDownloads {
            // 상태 변경 알림
            NotificationCenter.default.post(name: Notification.Name("downloadStateChanged"), object: nil)
        }
    }
    
    // MARK: - 앱 다운로드 상태 관리
    
    // AppDownloadManager.swift에 추가
    private let backgroundQueue = DispatchQueue(label: "com.appstore.download.background", qos: .background)

    // startDownload 함수 수정
    func startDownload(for app: AppModel) {
        // 이미 다운로드 중이면 무시
        guard downloads[app.id]?.state.isDownloading != true else { return }
        
        backgroundQueue.async { [weak self] in
            guard let self = self else { return }
            
            var downloadInfo = self.downloads[app.id] ?? AppDownloadInfo(id: app.id)
            
            switch downloadInfo.state {
            case .notDownloaded, .redownload:
                // 새 다운로드 시작
                downloadInfo.state = .downloading(0.0)
                downloadInfo.progress = 0.0
                downloadInfo.downloadStartTime = Date()
                downloadInfo.downloadElapsedTime = 0.0
                
            case .paused(let progress):
                // 일시 중지된 다운로드 재개
                downloadInfo.state = .downloading(progress)
                downloadInfo.downloadStartTime = Date()
                
            case .downloading, .downloaded:
                // 이미 다운로드 중이거나 완료된 경우 무시
                return
            }
            
            DispatchQueue.main.async {
                self.downloads[app.id] = downloadInfo
                self.saveState()
                self.startTimer(for: app.id)
                NotificationCenter.default.post(name: Notification.Name("downloadStateChanged"), object: nil)
            }
        }
            
        
    }
    
    // 다운로드 일시 중지
    func pauseDownload(for appId: String) {
        guard var downloadInfo = downloads[appId],
              case .downloading(let progress) = downloadInfo.state else { return }
        
        stopTimer(for: appId)
        
        downloadInfo.state = .paused(progress)
        downloadInfo.downloadElapsedTime += Date().timeIntervalSince(downloadInfo.downloadStartTime ?? Date())
        downloads[appId] = downloadInfo
        saveState()
        
        // 상태 변경 알림
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name("downloadStateChanged"), object: nil)
        }
    }
    
    // 앱 삭제
    func deleteApp(withId appId: String) {
        stopTimer(for: appId)
        
        // 설치된 앱에서 제거
        installedApps.removeAll { $0.id == appId }
        
        // 상태를 '다시받기'로 변경
        if var downloadInfo = downloads[appId] {
            downloadInfo.state = .redownload
            downloads[appId] = downloadInfo
        }
        
        // 상태 저장
        saveState()
        
        // 모든 뷰에 알림
        objectWillChange.send()
        
        // 상태 변경 알림
        NotificationCenter.default.post(name: Notification.Name("downloadStateChanged"), object: nil)
    }
    
    // MARK: - 타이머 관리
    private func startTimer(for appId: String) {
        // 기존 타이머 중지
        stopTimer(for: appId)
        
        guard var downloadInfo = downloads[appId],
              case .downloading(let progress) = downloadInfo.state else { return }
        
        // 업데이트 간격을 1초로 늘려 CPU 부하 감소 (0.2초 → 1초)
        let updateInterval = 1.0
        
        // 마지막 UI 업데이트 시간과 UserDefaults 저장 시간 추적
        var lastUIUpdateTime = Date()
        var lastSaveTime = Date()
        
        timers[appId] = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            // 백그라운드 큐에서 계산 작업 수행
            self.backgroundQueue.async {
                guard var downloadInfo = self.downloads[appId],
                      case .downloading(var progress) = downloadInfo.state else {
                    DispatchQueue.main.async {
                        timer.invalidate()
                        self.timers[appId] = nil
                    }
                    return
                }
                
                // 네트워크 연결 확인
                if !NetworkMonitor.shared.isConnected {
                    DispatchQueue.main.async {
                        self.pauseDownload(for: appId)
                    }
                    return
                }
                
                // 경과 시간 계산
                let elapsedTime = downloadInfo.downloadElapsedTime + Date().timeIntervalSince(downloadInfo.downloadStartTime ?? Date())
                
                // 진행 상황 업데이트 - 최소 5% 이상 변화가 있을 때만 UI 업데이트
                let newProgress = Float(min(1.0, elapsedTime / self.downloadDuration))
                let progressChanged = abs(newProgress - progress) > 0.05 // 5% 이상 변화가 있을 때만 처리
                
                progress = newProgress
                downloadInfo.progress = progress
                downloadInfo.state = .downloading(progress)
                
                // 완료 상태 확인
                let isCompleted = progress >= 1.0
                
                // UI 업데이트는 메인 스레드에서 수행
                DispatchQueue.main.async {
                    // 다운로드 완료 처리
                    if isCompleted {
                        downloadInfo.state = .downloaded
                        downloadInfo.progress = 1.0
                        self.stopTimer(for: appId)
                        
                        // 설치된 앱 목록에 추가
                        if !self.installedApps.contains(where: { $0.id == appId }) {
                            if let app = NetworkService.shared.cachedApps.first(where: { $0.id == appId }) {
                                self.installedApps.append(app)
                            }
                        }
                    }
                    
                    // 상태 변화가 있거나 완료된 경우에만 업데이트
                    if (progressChanged || isCompleted) {
                        self.downloads[appId] = downloadInfo
                        
                        // 5초에 한 번만 또는 완료 시에만 저장 (성능 최적화 - 3초에서 5초로 늘림)
                        let currentTime = Date()
                        if isCompleted || currentTime.timeIntervalSince(lastSaveTime) >= 5.0 {
                            self.saveState()
                            lastSaveTime = currentTime
                        }
                        
                        // UI 업데이트 알림 - 특정 버튼에만 알림을 보내기 위한 최적화
                        // 전체 UI 업데이트는 1.5초에 한 번만 수행
                        if isCompleted || currentTime.timeIntervalSince(lastUIUpdateTime) >= 1.5 {
                            self.objectWillChange.send()
                            lastUIUpdateTime = currentTime
                            
                            // 전체 UI 업데이트 대신 특정 다운로드 버튼만 업데이트하는 알림 전송
                            self.sendButtonStateChangeNotification(for: appId)
                        }
                    }
                }
            }
        }
        
        // 타이머가 백그라운드에서도 동작하도록 설정
        RunLoop.current.add(timers[appId]!, forMode: .common)
    }
    
    private func stopTimer(for appId: String) {
        timers[appId]?.invalidate()
        timers[appId] = nil
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
        
        // 네트워크 연결 끊김 알림 구독
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
    }
    
    private func handleNetworkDisconnected() {
        // 다운로드 중인 모든 앱을 일시정지 상태로 변경
        var pausedAppIds: [String] = []
        
        for (appId, downloadInfo) in downloads {
            if case .downloading = downloadInfo.state {
                pauseDownload(for: appId)
                pausedAppIds.append(appId)
            }
        }
        
        // 일시정지된 앱이 있을 경우 알림 전송
        if !pausedAppIds.isEmpty {
            NotificationCenter.default.post(
                name: .downloadsPausedDueToNetwork,
                object: pausedAppIds
            )
        }
    }
    private func handleNetworkConnected() {
        // 네트워크 연결이 복구되었음을 알림
        NotificationCenter.default.post(
            name: .networkReconnected,
            object: nil
        )
        
    
    }
    
    private func handleAppEnteringBackground() {
        lastBackgroundDate = Date()
        saveState()
    }
    
    private func handleAppEnteringForeground() {
        if let lastBackgroundDate = lastBackgroundDate {
            let elapsedTime = Date().timeIntervalSince(lastBackgroundDate)
            processBackgroundTime(elapsedTime)
        }
        
        // 앱 종료 후 다시 실행된 경우
        if wasAppTerminated {
            handleAppRelaunch()
            wasAppTerminated = false
        }
        
        self.lastBackgroundDate = nil
        saveState()
        
        // 상태 변경 알림
        NotificationCenter.default.post(name: Notification.Name("downloadStateChanged"), object: nil)
    }
    
    private func handleAppTermination() {
        saveState()
    }
    
    func handleCompletedTimers(_ timerIds: [String]) {
        for appId in timerIds {
            if var downloadInfo = downloads[appId],
               case .downloading = downloadInfo.state {
                // 다운로드 완료 처리
                downloadInfo.state = .downloaded
                downloadInfo.progress = 1.0
                downloads[appId] = downloadInfo  // private(set) 변수에 직접 할당 가능 (클래스 내부이므로)
                
                // 설치된 앱 목록에 추가
                if !installedApps.contains(where: { $0.id == appId }) {
                    if let app = NetworkService.shared.cachedApps.first(where: { $0.id == appId }) {
                        installedApps.append(app)  // private(set) 변수에 직접 할당 가능 (클래스 내부이므로)
                    }
                }
                
                // 타이머 중지
                BackgroundTimerManager.shared.stopTimer(id: appId)
            }
        }
        
        saveState()
        objectWillChange.send()
        
        // 상태 변경 알림
        NotificationCenter.default.post(name: Notification.Name("downloadStateChanged"), object: nil)
    }
    
    private func handleAppRelaunch() {
        // 다운로드 중이던 앱들을 재개 상태로 변경
        for (appId, var downloadInfo) in downloads {
            if case .downloading(let progress) = downloadInfo.state {
                downloadInfo.state = .paused(progress)
                downloads[appId] = downloadInfo
            }
        }
        saveState()
        
        // 상태 변경 알림
        NotificationCenter.default.post(name: Notification.Name("downloadStateChanged"), object: nil)
    }
    
    private func processBackgroundTime(_ elapsedTime: TimeInterval) {
        // 백그라운드에서 경과한 시간에 따라 다운로드 진행 상황 업데이트
        for (appId, var downloadInfo) in downloads {
            if case .downloading(let progress) = downloadInfo.state {
                let newElapsedTime = downloadInfo.downloadElapsedTime + elapsedTime
                let newProgress = Float(min(1.0, newElapsedTime / downloadDuration))
                
                if newProgress >= 1.0 {
                    // 다운로드 완료
                    downloadInfo.state = .downloaded
                    downloadInfo.progress = 1.0
                    
                    // 설치된 앱 목록에 추가
                    if !installedApps.contains(where: { $0.id == appId }) {
                        if let app = NetworkService.shared.cachedApps.first(where: { $0.id == appId }) {
                            installedApps.append(app)
                        }
                    }
                    
                    stopTimer(for: appId)
                } else {
                    // 다운로드 진행 중
                    downloadInfo.progress = newProgress
                    downloadInfo.state = .downloading(newProgress)
                    downloadInfo.downloadElapsedTime = newElapsedTime
                    downloadInfo.downloadStartTime = Date()
                    
                    // 네트워크 연결 확인
                    if NetworkMonitor.shared.isConnected {
                        // 타이머 재시작
                        startTimer(for: appId)
                    } else {
                        // 네트워크 연결이 없으면 일시 중지 상태로 변경
                        downloadInfo.state = .paused(newProgress)
                    }
                }
                
                downloads[appId] = downloadInfo
            }
        }
        
        saveState()
        objectWillChange.send()
        
        // 상태 변경 알림
        NotificationCenter.default.post(name: Notification.Name("downloadStateChanged"), object: nil)
    }
    
    // MARK: - 상태 저장 및 로드
    
    func saveState() {
        // 설치된 앱 목록 저장
        do {
            let encodedInstalledApps = try JSONEncoder().encode(installedApps)
            UserDefaults.standard.set(encodedInstalledApps, forKey: installedAppsKey)
        } catch {
            print("Error saving installed apps: \(error)")
        }
        
        // 다운로드 정보 저장
        do {
            let encodedDownloads = try JSONEncoder().encode(downloads)
            UserDefaults.standard.set(encodedDownloads, forKey: downloadsKey)
        } catch {
            print("Error saving downloads: \(error)")
        }
        
        // 백그라운드 날짜 저장
        if let lastBackgroundDate = lastBackgroundDate {
            UserDefaults.standard.set(lastBackgroundDate.timeIntervalSince1970, forKey: lastBackgroundDateKey)
        } else {
            UserDefaults.standard.removeObject(forKey: lastBackgroundDateKey)
        }
    }
    
    private func loadState() {
        loadInstalledApps()
        loadDownloads()
        loadLastBackgroundDate()
    }
    
    private func loadInstalledApps() {
        if let encodedInstalledApps = UserDefaults.standard.data(forKey: installedAppsKey) {
            do {
                installedApps = try JSONDecoder().decode([AppModel].self, from: encodedInstalledApps)
            } catch {
                print("Error loading installed apps: \(error)")
                installedApps = []
            }
        }
    }
    
    private func loadDownloads() {
        if let encodedDownloads = UserDefaults.standard.data(forKey: downloadsKey) {
            do {
                downloads = try JSONDecoder().decode([String: AppDownloadInfo].self, from: encodedDownloads)
            } catch {
                print("Error loading downloads: \(error)")
                downloads = [:]
            }
        }
    }
    
    private func loadLastBackgroundDate() {
        if let timestamp = UserDefaults.standard.object(forKey: lastBackgroundDateKey) as? TimeInterval {
            lastBackgroundDate = Date(timeIntervalSince1970: timestamp)
            wasAppTerminated = true
        }
    }
}
extension AppDownloadManager {
    
    func sendButtonStateChangeNotification(for appId: String) {
        DispatchQueue.main.async{
            NotificationCenter.default.post(
                name: .downloadButtonStateChanged,
                object: nil,
                userInfo: ["appId": appId]
            )
        }
    }
    
    // 다운로드 시작 함수 수정 (기존 코드 유지하고 마지막에 추가)
    func startDownload_modified(for app: AppModel) {
        // 기존 코드는 그대로 유지
        startDownload(for: app)
        
        // 버튼 상태 변경 알림만 전송
        sendButtonStateChangeNotification(for: app.id)
    }
    
    // 다운로드 일시 중지 함수 수정 (기존 코드 유지하고 마지막에 추가)
    func pauseDownload_modified(for appId: String) {
        // 기존 코드는 그대로 유지
        pauseDownload(for: appId)
        
        // 버튼 상태 변경 알림만 전송
        sendButtonStateChangeNotification(for: appId)
    }
}

// MARK: - NotificationCenter 확장
extension Notification.Name {
    static let downloadStateChanged = Notification.Name("downloadStateChanged")
}
extension Notification.Name {
    // 다운로드 버튼 상태 변경만을 위한 별도 알림
    static let downloadButtonStateChanged = Notification.Name("downloadButtonStateChanged")
}
