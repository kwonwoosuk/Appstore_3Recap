//
//  ScreenshotViewer.swift
//  Appstore_3Recap
//
//  Created by 권우석 on 4/25/25.
//

import SwiftUI

struct ScreenshotViewer: View {
    let screenshotURLs: [String]
    let initialIndex: Int
    let app: AppModel
    
    @State private var currentIndex: Int
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var downloadManager: AppDownloadManager
    
    init(screenshotURLs: [String], initialIndex: Int, app: AppModel) {
        self.screenshotURLs = screenshotURLs
        self.initialIndex = initialIndex
        self.app = app
        self._currentIndex = State(initialValue: initialIndex)
    }
    
    var body: some View {
        ZStack {
            Color.white.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // 상단 헤더 영역
                HStack {
                    // 왼쪽 완료 버튼
                    Button(action: {
                        dismiss()
                    }) {
                        Text("완료")
                            .foregroundColor(.appStoreBlue)
                            .font(.system(size: 17, weight: .regular))
                            .padding()
                    }
                    
                    Spacer()
                    
                    // 오른쪽 열기 버튼 (기능 없음)
                    Text("열기")
                        .foregroundColor(.appStoreBlue)
                        .font(.system(size: 17, weight: .regular))
                        .padding()
                }
                .background(Color.white)
                .foregroundColor(.white)
                
                // 스크린샷 페이저
                TabView(selection: $currentIndex) {
                    ForEach(Array(screenshotURLs.enumerated()), id: \.offset) { index, url in
                        AsyncImageView(url: url, placeholderImageName: "rectangle.on.rectangle")
                            .scaledToFit()
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
                .background(Color.black)
                
                // 하단 정보
                HStack {
                    // 인덱스 표시기
                    Text("\(currentIndex + 1) / \(screenshotURLs.count)")
                        .foregroundColor(.white)
                        .font(.subheadline)
                }
                .padding(.bottom)
                .background(Color.black)
            }
        }
        .statusBarHidden(true)
    }
}
