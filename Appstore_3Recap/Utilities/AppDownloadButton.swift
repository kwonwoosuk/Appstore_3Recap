//
//  AppDownloadButton.swift
//  Appstore_3Recap
//
//  Created by 권우석 on 4/25/25.
//

import SwiftUI

// MARK: - 앱 다운로드 버튼
struct AppDownloadButton: View {
    let app: AppModel
    let state: AppDownloadState
    let action: () -> Void
    
    // 애니메이션을 위한 상태
    @State private var animatedProgress: Float = 0
    // 초기 로드 완료 추적
    @State private var isLoaded = false
    
    var body: some View {
        Button(action: action) {
            switch state {
            case .notDownloaded:
                // 받기 버튼 - 텍스트만
                Text(state.buttonText)
                    .fontWeight(.medium)
                    .foregroundColor(.appStoreBlue)
                    .frame(height: 28)
                    .frame(minWidth: 70)
                    .background(Color.secondaryBackground)
                    .cornerRadius(14)
                
            case .downloading(let progress):
                // 다운로드 중 - 일시정지 아이콘 포함
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 28, height: 28)
                    
                    // animatedProgress 사용으로 부드러운 전환
                    Circle()
                        .trim(from: 0, to: CGFloat(animatedProgress))
                        .stroke(Color.appStoreBlue, lineWidth: 2)
                        .frame(width: 28, height: 28)
                        .rotationEffect(.degrees(-90))
                    
                    Image(systemName: "pause.fill")
                        .foregroundColor(.appStoreBlue)
                        .font(.system(size: 10, weight: .bold))
                }
                .frame(width: 28, height: 28)
                .contentShape(Rectangle()) // 터치 영역 명확히 지정
                .onChange(of: progress) { _, newValue in
                    withAnimation(.linear(duration: 0.2)) {
                        animatedProgress = newValue
                    }
                }
                
            case .paused(let progress):
                // 재개 버튼 - 아이콘과 텍스트
                HStack(spacing: 4) {
                    Image(systemName: "icloud.and.arrow.down")
                        .font(.system(size: 12))
                    Text(state.buttonText)
                }
                .fontWeight(.medium)
                .foregroundColor(.appStoreBlue)
                .frame(height: 28)
                .frame(minWidth: 70)
                .background(Color.secondaryBackground)
                .cornerRadius(14)
                .onAppear {
                    animatedProgress = progress // 일시정지 상태일 때도 animatedProgress 업데이트
                }
                
            case .downloaded:
                // 열기 버튼
                Text(state.buttonText)
                    .fontWeight(.medium)
                    .foregroundColor(.appStoreBlue)
                    .frame(height: 28)
                    .frame(minWidth: 70)
                    .background(Color.secondaryBackground)
                    .cornerRadius(14)
                
            case .redownload:
                // 다시받기 버튼 - 아이콘만
                Image(systemName: "icloud.and.arrow.down")
                    .font(.system(size: 16))
                    .foregroundColor(.appStoreBlue)
                    .frame(width: 28, height: 28)
                    .background(Color.secondaryBackground)
                    .clipShape(Circle())
            }
        }
        .buttonStyle(PlainButtonStyle()) // 명시적으로 플레인 스타일 지정
        .id("dBtn-\(app.id)-\(state.stateType.rawValue)-\(Int(state.progress * 100))") // 상태 변경 시마다 강제 리렌더링
        .onAppear {
            // 초기 로드 시 animatedProgress 즉시 설정
            if !isLoaded {
                if case .downloading(let progress) = state {
                    // 초기 로드 시에는 애니메이션 없이 즉시 적용
                    animatedProgress = progress
                    
                    // 현재 진행 중인지 확인하고, 즉시 프로그레스 업데이트 요청
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        // 강제 리프레시 알림
                        NotificationCenter.default.post(
                            name: .downloadProgressUpdated,
                            object: nil,
                            userInfo: ["appId": app.id, "progress": progress]
                        )
                    }
                }
                isLoaded = true
            }
        }
        // 상태가 변경될 때마다 호출
        .onChange(of: state) { oldState, newState in
            if case .downloading(let progress) = newState {
                withAnimation(.linear(duration: 0.2)) {
                    animatedProgress = progress
                }
            } else if case .paused(let progress) = newState {
                animatedProgress = progress
            }
        }
        // 앱이 처음 뜨는 경우 즉시 적용하기 위한 task
        .task {
            if case .downloading(let progress) = state {
                // 초기 값 즉시 적용
                animatedProgress = progress
            }
        }
    }
}
