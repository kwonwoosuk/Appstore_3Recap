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
                self.optimizedStartTimer(for: app.id)
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
    private func stopTimer(for appId: String) {
        timers[appId]?.invalidate()
        timers[appId] = nil
    }
    
    // 프로그레스 알림 전송 함수 최적화 - 0.1초 간격으로 변경
    func sendProgressUpdateNotification(for appId: String, progress: Float) {
        // 마지막 알림 시간 추적을 위한 정적 변수
        struct Static {
            static var lastNotificationTimes: [String: Date] = [:]
        }
        
        // 현재 시간
        let currentTime = Date()
        
        // 마지막 알림과의 시간 간격 계산 (기본값 0으로 시작)
        let timeSinceLastNotification = currentTime.timeIntervalSince(
            Static.lastNotificationTimes[appId] ?? Date(timeIntervalSince1970: 0)
        )
        
        // 0.1초마다 알림 전송 (이전 0.2초에서 개선)
        if timeSinceLastNotification >= 0.1 {
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .downloadProgressUpdated,
                    object: nil,
                    userInfo: ["appId": appId, "progress": progress]
                )
            }
            
            // 마지막 알림 시간 업데이트
            Static.lastNotificationTimes[appId] = currentTime
        }
    }
    
    // 최적화된 타이머 시작 함수
    private func optimizedStartTimer(for appId: String) {
        // 기존 타이머 중지
        stopTimer(for: appId)
        
        guard var downloadInfo = downloads[appId],
              case .downloading(let progress) = downloadInfo.state else { return }
        
        // 프로그레스 초기 전송 (타이머 시작 직후)
        sendDetailViewProgressUpdateNotification(for: appId, progress: progress)
        
        // 업데이트 간격을 0.1초로 단축
        let updateInterval = 0.1
        
        // 마지막 UI 업데이트 시간과 UserDefaults 저장 시간 추적
        var lastUIUpdateTime = Date()
        var lastSaveTime = Date()
        
        timers[appId] = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            // 메인 스레드에서 직접 처리 (백그라운드 큐 사용하지 않음)
            guard var downloadInfo = self.downloads[appId],
                  case .downloading(var progress) = downloadInfo.state else {
                timer.invalidate()
                self.timers[appId] = nil
                return
            }
            
            // 네트워크 연결 확인
            if !NetworkMonitor.shared.isConnected {
                self.pauseDownload(for: appId)
                return
            }
            
            // 경과 시간 계산
            let elapsedTime = downloadInfo.downloadElapsedTime + Date().timeIntervalSince(downloadInfo.downloadStartTime ?? Date())
            
            // 진행 상황 업데이트
            let newProgress = Float(min(1.0, elapsedTime / self.downloadDuration))
            
            // 프로그레스 변경 여부 확인 (미세한 변화도 모두 감지)
            let progressChanged = newProgress != progress
            progress = newProgress
            downloadInfo.progress = progress
            downloadInfo.state = .downloading(progress)
            
            // 완료 상태 확인
            let isCompleted = progress >= 1.0
            
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
            
            // 상태 업데이트
            if progressChanged || isCompleted {
                self.downloads[appId] = downloadInfo
                
                // 5초에 한 번만 또는 완료 시에만 저장 (성능 최적화)
                let currentTime = Date()
                if isCompleted || currentTime.timeIntervalSince(lastSaveTime) >= 5.0 {
                    self.saveState()
                    lastSaveTime = currentTime
                }
                
                // 즉시 프로그레스 업데이트 알림 전송 (스로틀링은 sendProgressUpdateNotification 내부에서 처리)
                self.sendProgressUpdateNotification(for: appId, progress: progress)
                
                // 완료 시 상태 변경 알림 추가
                if isCompleted {
                    self.objectWillChange.send()
                    self.sendButtonStateChangeNotification(for: appId)
                }
            }
        }
        
        // 타이머가 백그라운드에서도 동작하도록 설정
        RunLoop.main.add(timers[appId]!, forMode: .common)
    }
    
    // 기존 startTimer 함수를 최적화된 버전으로 대체
    private func startTimer(for appId: String) {
        optimizedStartTimer(for: appId)
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
                        optimizedStartTimer(for: appId)
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
    
    // MARK: - 버튼 상태 알림 관련
    
    func sendButtonStateChangeNotification(for appId: String) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .downloadButtonStateChanged,
                object: nil,
                userInfo: ["appId": appId]
            )
        }
    }
    
    // 다운로드 시작 함수 (UI에 즉시 반응하는 버전)
    func startDownload_modified(for app: AppModel) {
        // 중요: 이미 다운로드 중이면 무시
        guard downloads[app.id]?.state.isDownloading != true else { return }
        
        // 메인 스레드에서 즉시 UI 상태 업데이트
        DispatchQueue.main.async { [weak self] in
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
            
            // 즉시 UI 업데이트
            self.downloads[app.id] = downloadInfo
            
            // 메인 스레드에서 즉시 타이머 시작 (최적화 버전)
            self.optimizedStartTimer(for: app.id)
            
            // 상태 저장
            self.saveState()
            
            // 버튼 상태 변경 알림 즉시 전송
            self.sendButtonStateChangeNotification(for: app.id)
            
            // 상태 변경 알림 전송
            NotificationCenter.default.post(name: .downloadStateChanged, object: nil)
            
            // 초기 프로그레스 즉시 전송 (UI 업데이트 트리거)
            self.sendProgressUpdateNotification(for: app.id, progress: downloadInfo.progress)
            
            // 약간의 시간차를 두고 추가 프로그레스 업데이트 발송 (0.3초 후)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if let currentInfo = self.downloads[app.id],
                   case .downloading(let progress) = currentInfo.state {
                    self.sendProgressUpdateNotification(for: app.id, progress: progress)
                }
            }
        }
    }

    // 다운로드 일시 중지 함수 (UI에 즉시 반응하는 버전)
    func pauseDownload_modified(for appId: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            guard var downloadInfo = self.downloads[appId],
                  case .downloading(let progress) = downloadInfo.state else { return }
            
            // 즉시 UI 상태 변경
            downloadInfo.state = .paused(progress)
            downloadInfo.downloadElapsedTime += Date().timeIntervalSince(downloadInfo.downloadStartTime ?? Date())
            self.downloads[appId] = downloadInfo
            
            // 타이머 중지 및 알림 전송
            self.stopTimer(for: appId)
            self.sendButtonStateChangeNotification(for: appId)
            
            // 상태 저장
            self.saveState()
        }
    }
    
    // MARK: - 프로그레스 업데이트 최적화
    
    // 최적화된 프로그레스 알림 전송 함수 (뷰에 맞는 스로틀링 적용)
    func sendDetailViewProgressUpdateNotification(for appId: String, progress: Float) {
        // 마지막 알림 시간 추적을 위한 정적 변수
        struct Static {
            static var lastDetailNotificationTimes: [String: Date] = [:]
            static var lastSearchNotificationTimes: [String: Date] = [:]
        }
        
        // 현재 시간
        let currentTime = Date()
        
        // Detail 뷰를 위한 스로틀링 (0.2초마다 - 기존 0.3초에서 개선)
        let detailTimeSinceLastNotification = currentTime.timeIntervalSince(
            Static.lastDetailNotificationTimes[appId] ?? Date(timeIntervalSince1970: 0)
        )
        
        // Search 뷰를 위한 스로틀링 (0.1초마다 - 기존 0.2초에서 개선)
        let searchTimeSinceLastNotification = currentTime.timeIntervalSince(
            Static.lastSearchNotificationTimes[appId] ?? Date(timeIntervalSince1970: 0)
        )
        
        // 두 종류의 알림 전송 (Detail 뷰용 및 Search 뷰용)
        
        // 1. Detail 뷰용 (개선된 빈도)
        if detailTimeSinceLastNotification >= 0.2 {
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .detailViewProgressUpdated,
                    object: nil,
                    userInfo: ["appId": appId, "progress": progress]
                )
            }
            
            // 마지막 알림 시간 업데이트
            Static.lastDetailNotificationTimes[appId] = currentTime
        }
        
        // 2. Search 뷰용 (개선된 빈도)
        if searchTimeSinceLastNotification >= 0.1 {
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .downloadProgressUpdated,
                    object: nil,
                    userInfo: ["appId": appId, "progress": progress]
                )
            }
            
            // 마지막 알림 시간 업데이트
            Static.lastSearchNotificationTimes[appId] = currentTime
        }
    }
    
    // MARK: - 앱 다운로드 초기화 관련
    
    // 앱 초기화 시 호출할 함수
    func initializeDownloadTimers() {
        var activeDownloads: [String] = []
        
        // 다운로드 중인 앱들 찾기
        for (appId, downloadInfo) in downloads {
            if case .downloading = downloadInfo.state {
                activeDownloads.append(appId)
            }
        }
        
        // 타이머 시작 확인
        for appId in activeDownloads {
            // 타이머가 없으면 메인 스레드에서 즉시 시작
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                // 타이머 강제 시작 (최적화 버전)
                self.optimizedStartTimer(for: appId)
                
                // 0.1초 간격으로 5번 프로그레스 업데이트 알림 발송 (초기화 보장)
                if let progress = self.downloads[appId]?.progress {
                    for i in 0..<5 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1 * Double(i)) {
                            // 프로그레스 알림 발송
                            NotificationCenter.default.post(
                                name: .downloadProgressUpdated,
                                object: nil,
                                userInfo: ["appId": appId, "progress": progress]
                            )
                            
                            // 버튼 상태 변경 알림도 발송
                            NotificationCenter.default.post(
                                name: .downloadButtonStateChanged,
                                object: nil,
                                userInfo: ["appId": appId]
                            )
                        }
                    }
                }
            }
        }
        
        // 전체 UI 갱신
        objectWillChange.send()
        
        // 글로벌 알림 발송
        NotificationCenter.default.post(name: .forceUIRefresh, object: nil)
    }
    
    // 특정 앱에 대한 타이머 동작 보장 및 초기 알림 발송 (최적화 버전)
    func ensureTimerRunning(for appId: String) {
        // 다운로드 정보 확인
        guard let downloadInfo = downloads[appId],
              case .downloading(let progress) = downloadInfo.state else {
            return
        }
        
        // 메인 스레드에서 실행 보장
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 타이머가 없으면 시작
            if self.timers[appId] == nil {
                // 타이머 즉시 시작 (최적화 버전)
                self.optimizedStartTimer(for: appId)
                
                // 0.05초 간격으로 8번 프로그레스 알림 발송 (초기화 보장 및 실시간 업데이트 강화)
                for i in 0..<8 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05 * Double(i)) {
                        // 프로그레스 알림 발송
                        self.sendProgressUpdateNotification(for: appId, progress: progress)
                        
                        // 버튼 상태 변경 알림 발송 (2번째 이후만)
                        if i > 0 {
                            self.sendButtonStateChangeNotification(for: appId)
                        }
                    }
                }
                
                // 글로벌 상태 변경 알림 (마지막에 한 번)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    NotificationCenter.default.post(name: .downloadStateChanged, object: nil)
                    self.objectWillChange.send()
                }
            } else {
                // 타이머가 이미 실행 중인 경우에도 프로그레스 상태 알림 발송
                self.sendProgressUpdateNotification(for: appId, progress: progress)
            }
        }
    }

    // 앱이 처음 실행될 때 호출되는 초기화 함수 (최적화 버전)
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
                
                // 다운로드 중인 경우 타이머 재시작 (최적화 버전)
                optimizedStartTimer(for: appId)
                
                // 즉시 알림 전송하여 UI 갱신 트리거
                DispatchQueue.main.async {
                    // 프로그레스 업데이트 알림 (여러 번 발송하여 확실한 UI 업데이트 보장)
                    for i in 0..<3 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05 * Double(i)) {
                            self.sendProgressUpdateNotification(for: appId, progress: progress)
                        }
                    }
                    
                    // 버튼 상태 변경 알림
                    self.sendButtonStateChangeNotification(for: appId)
                }
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
            
        // 앱 시작 시 전체 UI 갱신 트리거
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.objectWillChange.send()
            
            // 상태 변경 알림 (UI 갱신용)
            NotificationCenter.default.post(name: .downloadStateChanged, object: nil)
        }
    }
    
    // 앱 시작 시 초기 상태 전달 메서드
    func broadcastInitialStates() {
        for (appId, downloadInfo) in downloads {
            if case .downloading(let progress) = downloadInfo.state {
                // 다운로드 중인 항목은 프로그레스 알림 전송 (여러 번 발송)
                for i in 0..<3 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05 * Double(i)) {
                        self.sendProgressUpdateNotification(for: appId, progress: progress)
                    }
                }
                sendButtonStateChangeNotification(for: appId)
            } else {
                // 다운로드 중이 아닌 항목도 상태 알림 전송
                sendButtonStateChangeNotification(for: appId)
            }
        }
        
        // 전체 UI 갱신
        objectWillChange.send()
    }
    
    // 앱 시작 시 호출되는 메서드 (최적화 버전)
    func enhancedSetupOnAppLaunch() {
        // 다운로드 매니저 초기화
        initializeBackgroundTimers()
        
        // 다운로드 중인 앱 ID 수집
        let downloadingAppIds = downloads.compactMap { (appId, info) -> String? in
            if case .downloading = info.state {
                return appId
            }
            return nil
        }
        
        // 다운로드 중인 앱이 있으면 타이머 확인 및 알림 발송 우선 처리
        for appId in downloadingAppIds {
            // 타이머 동작 즉시 확인
            ensureTimerRunning(for: appId)
            
            // 현재 진행률 즉시 공유
            if let progress = downloads[appId]?.progress {
                // 0.05초 간격으로 초기 프로그레스 상태 브로드캐스트
                for i in 0..<5 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05 * Double(i)) {
                        NotificationCenter.default.post(
                            name: .downloadProgressUpdated,
                            object: nil,
                            userInfo: ["appId": appId, "progress": progress]
                        )
                    }
                }
            }
        }
        
        // 약간의 지연 후 전체 상태 브로드캐스트 (UI가 로드된 후 업데이트되도록)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.broadcastInitialStates()
        }
    }
    
    // 간편 호출용 앱 시작 시 호출 메서드 (기존 코드와 호환)
    func setupOnAppLaunch() {
        enhancedSetupOnAppLaunch()
    }
}

extension Notification.Name {
    // DetailView 전용 낮은 빈도의 프로그레스 업데이트 알림
    static let detailViewProgressUpdated = Notification.Name("detailViewProgressUpdated")
}
