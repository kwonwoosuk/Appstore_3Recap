//
//  SearchResultRow.swift
//  Appstore_3Recap
//
//  Created by 권우석 on 4/25/25.
//

import SwiftUI

struct SearchResultRow: View {
    let app: AppModel
    let downloadState: AppDownloadState
    
    @State private var showAlert = false
    @EnvironmentObject private var downloadManager: AppDownloadManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 앱 정보 헤더 (아이콘, 이름, 버튼)
            HStack(spacing: 12) {
                // 앱 아이콘
                AsyncImageView(url: app.iconURL, placeholderImageName: "app.fill", cornerRadius: 12)
                    .frame(width: 60, height: 60)
                
                // 앱 정보
                VStack(alignment: .leading, spacing: 4) {
                    Text(app.name)
                        .font(.headline)
                        .lineLimit(1)
                    
                    // 앱 장르/설명 (카카오톡 예시: "소셜 네트워킹, 생산성")
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
                
                // 다운로드 버튼
                ZStack {
                    Button(action: {
                        handleDownloadAction()
                    }) {
                        AppDownloadButton(app: app, state: downloadState) {
                            // 실제 동작은 상위 버튼에서 처리
                        }
                    }
                }
                .zIndex(10) // 버튼을 최상위 레이어로 설정
            }
            
            // 스크린샷 - 앱이 설치되지 않은 경우에만 표시
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
            }
        }
        .padding(.vertical, 8)
        .alert("앱 삭제", isPresented: $showAlert) {
            Button("취소", role: .cancel) { }
            Button("삭제", role: .destructive) {
                downloadManager.deleteApp(withId: app.id)
            }
        } message: {
            Text("이 앱을 삭제하면 해당 데이터도 삭제됩니다.")
        }
    }
    
    private func handleDownloadAction() {
        switch downloadState {
        case .notDownloaded, .redownload:
            downloadManager.startDownload(for: app)
        case .downloading:
            downloadManager.pauseDownload(for: app.id)
        case .paused:
            downloadManager.startDownload(for: app)
        case .downloaded:
            // 이미 설치된 앱은 별도의 동작 없음
            break
        }
    }
}
