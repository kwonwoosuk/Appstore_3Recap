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
    
    var body: some View {
        Button(action: action) {
            switch state {
            case .notDownloaded:
                // 받기 버튼 - 텍스트만
                Text(state.buttonText)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(height: 28)
                    .frame(minWidth: 70)
                    .background(Color.appStoreBlue)
                    .cornerRadius(14)
            
            case .downloading(let progress):
                // 다운로드 중 - 일시정지 아이콘 포함
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 28, height: 28)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(progress))
                        .stroke(Color.appStoreBlue, lineWidth: 2)
                        .frame(width: 28, height: 28)
                        .rotationEffect(.degrees(-90))
                    
                    Image(systemName: "pause.fill")
                        .foregroundColor(.appStoreBlue)
                        .font(.system(size: 10, weight: .bold))
                }
                .frame(width: 28, height: 28)
            
            case .paused:
                // 재개 버튼 - 아이콘과 텍스트
                HStack(spacing: 4) {
                    Image(systemName: "icloud.and.arrow.down")
                        .font(.system(size: 12))
                    Text(state.buttonText)
                }
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(height: 28)
                .frame(minWidth: 70)
                .background(Color.appStoreBlue)
                .cornerRadius(14)
            
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
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(Color.appStoreBlue)
                    .clipShape(Circle())
            }
        }
    }
}
