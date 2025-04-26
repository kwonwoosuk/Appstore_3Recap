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
    @State private var deletePosition: CGPoint? = nil
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 실시간 검색 필드
                SearchBar(
                    text: Binding(
                        get: { viewModel.searchQuery },
                        set: {
                            viewModel.updateSearchQuery($0)
                        }
                    ),
                    onCommit: { },
                    onCancel: { }
                )
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                if viewModel.installedApps.isEmpty {
                    // 설치된 앱이 없는 경우
                    EmptyResultsView(
                        message: "설치된 앱이 없습니다.",
                        systemImageName: "square.stack.3d.up",
                        action: { },
                        actionTitle: "앱 둘러보기"
                    )
                } else if viewModel.filteredApps.isEmpty && !viewModel.searchQuery.isEmpty {
                    // 검색 결과가 없는 경우
                    EmptyResultsView(
                        message: "'\(viewModel.searchQuery)'와(과) 일치하는 앱이 없습니다.",
                        systemImageName: "magnifyingglass"
                    )
                } else {
                    // List 대신 ScrollView + LazyVStack 사용
                    ScrollView {
                        LazyVStack(spacing: 0, pinnedViews: []) {
                            ForEach(viewModel.filteredApps) { app in
                                CustomAppRow(
                                    app: app,
                                    onDelete: {
                                        // 삭제 버튼 클릭 시
                                        appToDelete = app
                                        showDeleteAlert = true
                                    }
                                )
                                .contentShape(Rectangle())
                                
                                Divider()
                                    .padding(.leading, 88)
                            }
                        }
                        .padding(.bottom, 20)
                    }
                    .background(Color.appBackground)
                }
            }
            .background(Color.appBackground)
            .navigationTitle("앱")
            .alert("앱 삭제", isPresented: $showDeleteAlert) {
                Button("취소", role: .cancel) {
                    appToDelete = nil
                }
                Button("삭제", role: .destructive) {
                    if let app = appToDelete {
                        performDelete(app: app)
                    }
                }
            } message: {
                Text("이 앱을 삭제하면 해당 데이터도 삭제됩니다.")
            }
        }
    }
    
    // 실제 삭제 로직 수행
    private func performDelete(app: AppModel) {
        // 약간의 지연 후 삭제 실행
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            viewModel.deleteApp(withId: app.id)
            appToDelete = nil
        }
    }
}

// 커스텀 앱 행 (스와이프 기능 포함)
struct CustomAppRow: View {
    let app: AppModel
    let onDelete: () -> Void
    
    @State private var offset: CGFloat = 0
    @State private var showDeleteButton = false
    
    var body: some View {
        ZStack {
            // 배경 삭제 버튼 레이어
            HStack {
                Spacer()
                Button(action: onDelete) {
                    HStack {
                        Image(systemName: "trash")
                        Text("삭제")
                    }
                    .foregroundColor(.white)
                    .frame(width: 100, height: 76)
                    .background(Color.red)
                }
            }
            
            // 앱 정보 레이어 (스와이프 가능)
            UserAppRow(app: app)
                .padding(.leading, 16) // 왼쪽 패딩 추가
                .background(Color.appBackground)
                .offset(x: offset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            // 왼쪽으로만 스와이프 허용
                            if value.translation.width < 0 {
                                offset = value.translation.width
                                
                                // 일정 거리 이상 스와이프 시 삭제 버튼 표시
                                if abs(offset) > 60 && !showDeleteButton {
                                    withAnimation {
                                        showDeleteButton = true
                                    }
                                } else if abs(offset) <= 60 && showDeleteButton {
                                    withAnimation {
                                        showDeleteButton = false
                                    }
                                }
                            }
                        }
                        .onEnded { value in
                            // 충분히 스와이프했으면 버튼 표시 상태 유지
                            if abs(value.translation.width) > 100 {
                                withAnimation {
                                    offset = -100
                                    showDeleteButton = true
                                }
                            } else {
                                // 아니면 원위치
                                withAnimation {
                                    offset = 0
                                    showDeleteButton = false
                                }
                            }
                        }
                )
                .onTapGesture {
                    // 스와이프 상태에서 탭하면 원위치
                    if offset != 0 {
                        withAnimation {
                            offset = 0
                            showDeleteButton = false
                        }
                    }
                }
        }
        .frame(height: 76)
        .clipped()
    }
}
