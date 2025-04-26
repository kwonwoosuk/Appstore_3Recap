//
//  SearchView.swift
//  Appstore_3Recap
//
//  Created by 권우석 on 4/25/25.
//

import SwiftUI

struct AsyncSearchView: View {
    @State var viewModel = SearchViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var downloadManager: AppDownloadManager
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 검색 바
                SearchBar(
                    text: Binding(
                        get: { viewModel.searchQuery },
                        set: { viewModel.searchQuery = $0 }
                    ),
                    onCommit: { viewModel.searchApps() },
                    onCancel: { viewModel.resetSearch() }
                )
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                if viewModel.searchResults.isEmpty && !viewModel.hasSearched {
                    // 검색 전 화면
                    VStack {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.5))
                            .padding(.bottom)
                        
                        Text("검색어를 입력하고\n원하는 앱을 찾아보세요.")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.appBackground)
                } else if viewModel.searchResults.isEmpty && !viewModel.isLoading && viewModel.errorMessage == nil && viewModel.hasSearched {
                    // 검색 결과 없음
                    EmptyResultsView(
                        message: "'\(viewModel.searchQuery)'에 대한\n검색 결과가 없습니다.",
                        systemImageName: "magnifyingglass"
                    )
                } else if let errorMessage = viewModel.errorMessage {
                    // 에러 화면
                    NetworkErrorView(error: APIError.networkError(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: errorMessage]))) {
                        viewModel.searchApps()
                    }
                } else {
                    // 검색 결과 목록
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.searchResults) { app in
                                VStack {
                                    // 행 내용을 담을 ZStack
                                    ZStack(alignment: .topLeading) {
                                        // 앱 정보 행 (탭 가능한 영역)
                                        NavigationLink(destination: AsyncAppDetailView(viewModel: AppDetailViewModel(app: app))) {
                                            // 행 전체 컨텐츠 (버튼 제외)
                                            RowContentView(app: app)
                                        }
                                        
                                        // 다운로드 버튼을 별도 레이어로 추가
                                        HStack {
                                            Spacer()
                                            DownloadButtonView(
                                                app: app
                                            )
                                            .padding(.trailing, 16)
                                        }
                                        .frame(height: 60)
                                        .allowsHitTesting(true)
                                    }
                                    
                                    Divider()
                                        .padding(.leading, 88) // 아이콘 너비 + 패딩
                                }
                                .id("app-row-\(app.id)")
                                .onAppear {
                                    // 마지막에서 5번째 항목일 경우 더 로드 (버퍼 추가)
                                    if viewModel.searchResults.count >= 10 &&
                                       viewModel.searchResults.suffix(5).contains(where: { $0.id == app.id }) &&
                                       viewModel.hasMoreResults {
                                        viewModel.loadMoreResults()
                                    }
                                }
                            }
                            
                            // 더 로드 중일 때 하단 로딩 표시
                            if viewModel.hasMoreResults {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .padding()
                                    Spacer()
                                }
                                .id("loadingIndicator")
                                .onAppear {
                                    if !viewModel.isLoading {
                                        viewModel.loadMoreResults()
                                    }
                                }
                            }
                            
                            // 결과가 더 이상 없을 때 표시
                            if !viewModel.hasMoreResults && !viewModel.searchResults.isEmpty {
                                Text("검색 결과 끝")
                                    .font(.caption)
                                    .foregroundColor(.secondaryText)
                                    .padding()
                                    .id("endOfResults")
                            }
                        }
                    }
                    .refreshable {
                        viewModel.refreshResults()
                    }
                }
                
                // 로딩 오버레이
                if viewModel.isLoading && viewModel.searchResults.isEmpty {
                    LoadingIndicator()
                }
            }
            .background(Color.appBackground)
            .onAppear {
                print("SearchView appeared")
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .active {
                    print("Scene phase changed to active")
                }
            }
        }
    }
}
// 다운로드 버튼을 위한 별도 View
struct DownloadButtonView: View {
    let app: AppModel
    @EnvironmentObject private var downloadManager: AppDownloadManager
    @State private var downloadState: AppDownloadState
    
    init(app: AppModel) {
        self.app = app
        // 초기 상태를 가져와 @State로 저장
        _downloadState = State(initialValue: AppDownloadManager.shared.downloads[app.id]?.state ?? .notDownloaded)
    }
    
    var body: some View {
        // 액션을 클로저로 직접 AppDownloadButton에 전달
        AppDownloadButton(app: app, state: downloadState) {
            handleDownloadAction()
        }
        // 특정 앱 ID에 대한 알림만 수신하도록 설정
        .onReceive(
            NotificationCenter.default.publisher(for: .downloadButtonStateChanged)
                .filter { ($0.userInfo?["appId"] as? String) == app.id }
        ) { _ in
            // 상태 갱신 - 전체 뷰가 아닌 현재 버튼만 업데이트
            downloadState = downloadManager.downloads[app.id]?.state ?? .notDownloaded
        }
        // 이 View만 고유하게 식별하는 ID
        .id("downloadButton-\(app.id)")
    }
    
    private func handleDownloadAction() {
        DispatchQueue.global(qos: .userInitiated).async {
            switch downloadState {
            case .notDownloaded, .redownload:
                downloadManager.startDownload_modified(for: app)
            case .downloading:
                downloadManager.pauseDownload_modified(for: app.id)
            case .paused:
                downloadManager.startDownload_modified(for: app)
            case .downloaded:
                // 이미 설치된 앱은 별도의 동작 없음
                break
            }
        }
    }
}
// 행 내용을 위한 별도 View (버튼 제외)
struct RowContentView: View {
    let app: AppModel
    @EnvironmentObject private var downloadManager: AppDownloadManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 앱 정보 헤더 (아이콘, 이름 - 버튼 제외)
            HStack(spacing: 12) {
                // 앱 아이콘
                AsyncImageView(url: app.iconURL, placeholderImageName: "app.fill", cornerRadius: 12)
                    .frame(width: 60, height: 60)
                
                // 앱 정보
                VStack(alignment: .leading, spacing: 4) {
                    Text(app.name)
                        .font(.headline)
                        .lineLimit(1)
                        .foregroundColor(.primary) // 다크모드 대응
                    
                    // 앱 장르/설명
                    if let genres = app.genres, !genres.isEmpty {
                        Text(genres.joined(separator: ", "))
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                            .lineLimit(1)
                    } else {
                        Text(app.category)
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                            .lineLimit(1)
                    }
                    
                    Spacer().frame(height: 4)
                    
                    // 하단 iOS, 개발자, 카테고리 정보 행
                    HStack(spacing: 16) {
                        // iOS 버전
                        Text("iOS \(app.minimumOsVersion)")
                            .font(.caption2)
                            .foregroundColor(.tertiaryText)
                        
                        // 개발자 정보
                        HStack(spacing: 2) {
                            Image(systemName: "person.crop.rectangle")
                                .font(.caption2)
                                .foregroundColor(.tertiaryText)
                            
                            Text(app.developerName)
                                .font(.caption2)
                                .foregroundColor(.tertiaryText)
                        }
                        
                        // 카테고리
                        Text(app.category)
                            .font(.caption2)
                            .foregroundColor(.tertiaryText)
                    }
                    .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // 다운로드 버튼 영역을 위한 빈 공간
                Spacer()
                    .frame(width: 70)
            }
            
            // 스크린샷 - 앱이 설치되지 않은 경우에만 표시
            let downloadState = downloadManager.downloads[app.id]?.state ?? .notDownloaded
            if downloadState != .downloaded {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(app.effectiveScreenshotURLs.prefix(3).enumerated()), id: \.offset) { index, url in
                            AsyncImageView(url: url, placeholderImageName: "rectangle.on.rectangle", cornerRadius: 8)
                                .frame(width: 120, height: 200)
                                .cornerRadius(8)
                                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                        }
                    }
                    .padding(.vertical, 4)
                }
                // 스크린샷 영역에 고유 ID 부여
                .id("screenshots-\(app.id)")
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }
}
