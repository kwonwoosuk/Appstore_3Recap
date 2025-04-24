//
//  SearchView.swift
//  Appstore_3Recap
//
//  Created by 권우석 on 4/25/25.
//

import SwiftUI

struct AsyncSearchView: View {
    @State var viewModel = SearchViewModel()
    @State private var showingDetail = false
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 검색 바
                SearchBar(
                    text: Binding(
                        get: { viewModel.searchQuery },
                        set: { viewModel.searchQuery = $0 }
                    ),
                    onCommit: { viewModel.searchApps() },  // 리턴키를 통해 검색 실행
                    onCancel: { viewModel.resetSearch() }  // 취소 버튼을 눌렀을 때 검색 초기화
                )
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                // 결과 목록
                if viewModel.searchResults.isEmpty && !viewModel.hasSearched {
                    // 검색 전 화면 (hasSearched가 false인 경우에만 표시)
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
                    // 검색 결과 없음 (hasSearched가 true일 때만 표시)
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
                    List {
                        ForEach(viewModel.searchResults) { app in
                            SearchResultRow(app: app, downloadState: viewModel.getDownloadState(for: app.id))
                                .onTapGesture {
                                    viewModel.selectApp(app)
                                    showingDetail = true
                                }
                                .onAppear {
                                    // 마지막 항목일 경우 더 로드
                                    if app.id == viewModel.searchResults.last?.id {
                                        viewModel.loadMoreResults()
                                    }
                                }
                        }
                        
                        if viewModel.hasMoreResults {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                                .onAppear {
                                    viewModel.loadMoreResults()
                                }
                        }
                    }
                    .listStyle(PlainListStyle())
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
            .navigationDestination(isPresented: $showingDetail) {
                if let selectedApp = viewModel.selectedApp {
                    AsyncAppDetailView(viewModel: AppDetailViewModel(app: selectedApp))
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                // 앱이 활성화될 때마다 다운로드 상태 갱신
                if newPhase == .active && oldPhase != .active {
                    // 뷰 갱신 (UI 업데이트 트리거)
                    let currentResults = viewModel.searchResults
                    viewModel.searchResults = []
                    viewModel.searchResults = currentResults
                }
            }
        }
    }
}
