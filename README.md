# App Store 클론 프로젝트

## 📋 개요

iOS의 App Store를 모방한 클론 프로젝트로, 앱 검색, 다운로드, 앱 관리 기능을 구현했습니다.<br>
이 프로젝트는 SwiftUI와 MVVM 아키텍처를 기반으로 개발되었으며, 특히 백그라운드 타이머 처리와 네트워크 모니터링에 중점을 두었습니다.

## 🗓️ 개발 정보
- **개발 기간**: 2025.04.24 ~ 2025.04.25
- **개발 인원**: 1명 (권우석)
- **담당 업무**: 기획, 디자인, 개발, 테스트

## 💁🏻‍♂️ 프로젝트 소개

App Store 애플리케이션의 핵심 기능을 재구현한 클론 프로젝트입니다. 사용자는 앱을 검색하고, 상세 정보를 확인하며, 다운로드 및 관리할 수 있습니다. 특히 앱이 백그라운드로 전환되거나 종료된 후에도 다운로드 상태를 유지하는 기능과 네트워크 연결 상태에 따른 다운로드 관리 기능을 중점적으로 구현했습니다.

## ⭐️ 주요 기능

### 앱 검색 - iTunes Search API를 활용한 앱 검색 기능

| 검색화면 |
|------|
| <img src="https://github.com/user-attachments/assets/809c3728-02b4-4f10-bca6-2026ae953ed6" width="300" > |  
- 앱을 검색하고 다운 받을 수 있는 화면입니다
- 다운로드 버튼은 모든화면에서 동기화 됩니다
- 앱이 백그라운드 상태가 되어도 다운로드상태는 유지됩니다
- 버전정보와 카테고리 같은 간단한 정보가 표시됩니다
- 앱이 열기 상태인 경우 미리보기 스크린샷이 보여지지 않습니다 

<br>
<br>

### 앱 상세 정보 - 앱의 상세 정보, 스크린샷, 설명 확인  

| 상세화면 |
|------|
| <img src="https://github.com/user-attachments/assets/f1f85a62-6607-4163-8068-c436812a901e" width="300" > |
- 앱의 상세 정보를 확인할 수 있습니다
- 앱 스크린샷을 확대해서 볼 수 있습니다
- 버전정보, 연령, 카테고리 등을 확인할 수 있습니다
<br>
<br>

### 앱 다운로드 관리 - 다운로드, 일시정지, 재개, 설치, 삭제 기능
| 다운로드 상태관리 |
|------|
| <img src="https://github.com/user-attachments/assets/279e4e62-745c-4fa4-a048-6caa6e8ac74d" width="300" > |
- 다운로드 상태는 모든화면서 동기화 됩니다

<br><br>
### 네트워크 모니터링 - 네트워크 연결 상태에 따른 다운로드 관리

| 네트워크 모니터링 |
|------|
| <img src="https://github.com/user-attachments/assets/73b3e71e-9658-4ca4-82c9-186f693ebd3d" width="300" > <img src="https://github.com/user-attachments/assets/17b60e99-5f11-4abc-98b8-9b5e99f49c43" width="300" > |
- 네트워크 연결이 끊어짐을 감지하고 자동으로 다운로드 프로그레스를 저장하고 일시정지합니다
- 네트워크 연결이 재개되면 사용자에서 토스트를 통해 알립니다


<br><br>
- **백그라운드 처리**: 앱이 백그라운드에 있을 때도 다운로드 진행
- **설치된 앱 관리**: 사용자의 설치된 앱 목록 확인 및 관리

## 🛠 기술 스택

- **언어 및 프레임워크**: Swift, SwiftUI
- **아키텍처**: MVVM
- **네트워크 통신**: URLSession + Swift Concurrency (async/await)
- **로컬 데이터 저장**: UserDefaults
- **상태 관리**: @Observable, @Bindable, NotificationCenter
- **백그라운드 처리**: BackgroundTasks, Timer

## 프로젝트 구조

```
Appstore_3Recap/
├── App/
│   ├── Appstore_3RecapApp.swift
│   └── MainTabView.swift
├── Models/
│   ├── AppModel.swift
│   └── ITunesSearchResponse.swift
├── ViewModels/
│   ├── AppDetailViewModel.swift
│   ├── SearchViewModel.swift
│   └── UserAppsViewModel.swift
├── Views/
│   ├── Search/
│   │   ├── SearchView.swift
│   │   └── SearchBar.swift
│   ├── AppDetail/
│   │   ├── AppDetailView.swift
│   │   ├── AppHeaderSection.swift
│   │   ├── AppInfoSection.swift
│   │   ├── AppDescriptionSection.swift
│   │   ├── ReleaseNotesSection.swift
│   │   ├── ScreenshotSection.swift
│   │   └── ScreenshotViewer.swift
│   ├── UserApps/
│   │   ├── UserAppsView.swift
│   │   └── UserAppRow.swift
│   └── Common/
│       └── AppDownloadButton.swift
├── Services/
│   ├── NetworkService.swift
│   ├── MockDataProvider.swift
│   └── APIConstants.swift
├── Managers/
│   ├── AppDownloadManager.swift
│   ├── BackgroundTimerManager.swift
│   ├── NetworkMonitor.swift
│   └── NetworkAlertManager.swift
└── Utils/
    ├── Extensions.swift
    └── CustomNavigationLink.swift
```

## 💡 주요 구현 내용

### **@Observable 패턴을 활용한 MVVM 아키텍처 구현**
* Swift 최신 버전의 @Observable 매크로를 활용한 효율적인 상태 관리
* ViewModel과 View의 명확한 분리로 코드 유지보수성 향상
* 각 화면에 특화된 ViewModel 설계로 비즈니스 로직 캡슐화

### **백그라운드 타이머 처리 시스템 구현**
* 앱이 백그라운드로 전환되거나 종료된 후에도 다운로드 진행 상태 유지
* UserDefaults를 활용한 상태 저장 및 복구 메커니즘 구현
* 앱 재실행 시 이전 상태 복원으로 사용자 경험 개선

### **효율적인 네트워크 모니터링 시스템 설계**
* NWPathMonitor를 활용한 실시간 네트워크 연결 상태 감시
* 네트워크 연결 해제 시 자동 다운로드 일시정지 기능 구현
* 네트워크 재연결 시 사용자에게 알림 제공 및 다운로드 재개 안내

### **Swift Concurrency를 활용한 비동기 네트워크 처리**
* async/await 패턴을 활용한 간결하고 가독성 높은 네트워크 코드 구현
* Task 기반 요청 관리로 메모리 누수 방지
* 응답 데이터 캐싱으로 중복 네트워크 요청 최소화

### **NotificationCenter를 활용한 컴포넌트 간 통신 구현**
* 다운로드 상태 변경 및 프로그레스 업데이트를 위한 내부 이벤트 시스템 구현
* 화면 간 데이터 동기화로 일관된 사용자 경험 제공
* 세분화된 알림 시스템으로 필요한 컴포넌트만 효율적으로 업데이트

### **성능 최적화를 위한 이미지 관리 시스템 설계**
* 이미지 캐싱 시스템 구현으로 반복적인 네트워크 요청 최소화
* 비동기 이미지 로딩으로 UI 스레드 차단 방지
* 화면에 표시되지 않는 이미지 메모리 자동 해제 기능 구현

### **UI 성능 최적화 기법 적용**
* ID 기반 뷰 재사용으로 불필요한 리렌더링 방지
* 애니메이션 스로틀링 적용으로 UI 응답성 향상
* 렌더링 계층 최적화로 메모리 사용량 감소

## 🔍 문제 해결 및 최적화

### **다운로드 버튼 UI 프리징 현상 해결**
* **문제**: 다운로드 진행 상태 업데이트 시 UI 프리징현상 발생
* **해결**: 애니메이션 스로틀링 및 상태 변경 로직 최적화로 부드러운 업데이트 구현
* **효과**: 사용자 경험 향상 및 CPU 사용량 감소

### **백그라운드 처리 시 다운로드 상태 손실 문제 해결**
* **문제**: 앱 종료 후 재실행 시 다운로드 상태 및 진행률 초기화 문제
* **해결**: UserDefaults 활용한 상태 저장 및 복구 메커니즘 구현
* **효과**: 앱 재실행 시에도 일관된 다운로드 경험 제공

### **네트워크 연결 해제 시 다운로드 실패 문제 개선**
* **문제**: 네트워크 연결 해제 시 다운로드 작업 실패 및 오류 발생
* **해결**: 네트워크 모니터링 시스템 구현 및 자동 일시정지 기능 추가
* **효과**: 네트워크 불안정 환경에서도 안정적인 다운로드 처리

### **메모리 사용량 최적화**
* **문제**: 많은 이미지 로딩 시 메모리 오버헤드 및 성능 저하
* **해결**: 이미지 캐싱 및 메모리 자동 해제 시스템 구현
* **효과**: 메모리 사용량 감소 및 앱 전반적인 성능 향상

