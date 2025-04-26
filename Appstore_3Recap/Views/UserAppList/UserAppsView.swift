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
            // VStack 전체를 ScrollView로 감싸기
            ScrollView {
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
                        // 최소 높이 설정
                        .frame(minHeight: UIScreen.main.bounds.height - 100)
                    } else if viewModel.filteredApps.isEmpty && !viewModel.searchQuery.isEmpty {
                        // 검색 결과가 없는 경우
                        EmptyResultsView(
                            message: "'\(viewModel.searchQuery)'와(과) 일치하는 앱이 없습니다.",
                            systemImageName: "magnifyingglass"
                        )
                        // 최소 높이 설정
                        .frame(minHeight: UIScreen.main.bounds.height - 100)
                    } else {
                        // 앱 목록
                        LazyVStack(spacing: 0, pinnedViews: []) {
                            ForEach(viewModel.filteredApps) { app in
                                CustomAppRow(
                                    app: app,
                                    onDelete: {
                                        appToDelete = app
                                        showDeleteAlert = true
                                    }
                                )
                                .contentShape(Rectangle())
                                
                                Divider()
                                    .padding(.leading, 88)
                                    .frame(height: 1) // Divider 높이 명시
                            }
                        }
                        .padding(.bottom, 20)
                        // 디버깅: 콘텐츠 높이 확인
                        .background(
                            GeometryReader { geometry in
                                Color.clear
                                    .onAppear {
                                        print("LazyVStack 높이: \(geometry.size.height)")
                                    }
                            }
                        )
                    }
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
    
    private func performDelete(app: AppModel) {
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
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // 배경 삭제 버튼 레이어
            Button(action: {
                // 햅틱 피드백 추가
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                onDelete()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "trash")
                    Text("삭제")
                }
                .foregroundColor(.white)
                .frame(width: max(100, -offset), height: 76) // 스와이프 거리에 따라 동적 너비 조정
                .background(Color.red)
                .contentShape(Rectangle())
            }
            
            // 앱 정보 레이어 (스와이프 가능)
            UserAppRow(app: app)
                .padding(.leading, 16)
                .background(Color.appBackground)
                .offset(x: offset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            // 왼쪽으로만 스와이프 허용
                            if value.translation.width < 0 {
                                offset = max(value.translation.width, -150) // 최대 스와이프 거리 제한
                            }
                        }
                        .onEnded { value in
                            // 스와이프 거리에 따라 위치 결정
                            if value.predictedEndTranslation.width < -100 {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    offset = -100
                                }
                            } else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    offset = 0
                                }
                            }
                        }
                )
                .onTapGesture {
                    // 스와이프 상태에서 탭하면 원위치
                    if offset != 0 {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            offset = 0
                        }
                    }
                }
        }
        .frame(height: 76)
        .clipped()
    }
}
