//
//  UserAppsView.swift
//  Appstore_3Recap
//
//  Created by 권우석 on 4/25/25.
//

import SwiftUI

struct AsyncUserAppsView: View {
    @State var viewModel = UserAppsViewModel()
    @State private var showDeleteAlert = false
    @State private var appToDelete: AppModel? = nil
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 실시간 검색 필드 (앱 탭에서만 실시간 검색 유지)
                SearchBar(
                    text: Binding(
                        get: { viewModel.searchQuery },
                        set: {
                            // 앱 탭에서는 실시간 검색 유지
                            viewModel.updateSearchQuery($0)
                        }
                    ),
                    onCommit: { /* 앱 탭에서는 리턴키 동작 불필요 */ }, onCancel: {
                        
                    }
                )
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                if viewModel.installedApps.isEmpty {
                    // 설치된 앱이 없는 경우
                    EmptyResultsView(
                        message: "설치된 앱이 없습니다.",
                        systemImageName: "square.stack.3d.up",
                        action: {
                            // 탭바에서 검색 탭으로 이동 - 실제 구현 시 탭 인덱스 변경 필요
                        },
                        actionTitle: "앱 둘러보기"
                    )
                } else if viewModel.filteredApps.isEmpty && !viewModel.searchQuery.isEmpty {
                    // 검색 결과가 없는 경우
                    EmptyResultsView(
                        message: "'\(viewModel.searchQuery)'와(과) 일치하는 앱이 없습니다.",
                        systemImageName: "magnifyingglass"
                    )
                } else {
                    // 앱 목록
                    List {
                        ForEach(viewModel.filteredApps) { app in
                            UserAppRow(app: app)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        appToDelete = app
                                        showDeleteAlert = true
                                    } label: {
                                        Label("삭제", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .listStyle(PlainListStyle())
                    .animation(.default, value: viewModel.filteredApps)
                }
            }
            .background(Color.appBackground)
            .navigationTitle("앱")
            .alert("앱 삭제", isPresented: $showDeleteAlert) {
                Button("취소", role: .cancel) { appToDelete = nil }
                Button("삭제", role: .destructive) {
                    if let app = appToDelete {
                        viewModel.deleteApp(withId: app.id)
                    }
                    appToDelete = nil
                }
            } message: {
                Text("이 앱을 삭제하면 해당 데이터도 삭제됩니다.")
            }
        }
    }
}
