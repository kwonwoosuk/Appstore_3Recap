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
    
    @State private var currentIndex: Int
    @Environment(\.dismiss) private var dismiss
    
    init(screenshotURLs: [String], initialIndex: Int) {
        self.screenshotURLs = screenshotURLs
        self.initialIndex = initialIndex
        self._currentIndex = State(initialValue: initialIndex)
    }
    
    var body: some View {
        ZStack {
            Color(.systemBackground).edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // 상단 네비게이션 바
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Text("완료")
                            .foregroundColor(.appStoreBlue)
                            .font(.system(size: 17, weight: .medium))
                    }
                    
                    Spacer()
                    
                    // 열기 버튼 (다운로드 버튼 스타일과 유사하게)
                    Button(action: {
                        // 열기 버튼 액션 (별 기능 없음)
                    }) {
                        Text("열기")
                            .fontWeight(.medium)
                            .foregroundColor(.appStoreBlue)
                            .frame(height: 28)
                            .frame(minWidth: 70)
                            .background(Color.secondaryBackground)
                            .cornerRadius(14)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                // 스크린샷 페이저 (라운드 코너와 그림자 적용)
                TabView(selection: $currentIndex) {
                    ForEach(Array(screenshotURLs.enumerated()), id: \.offset) { index, url in
                        AsyncImageView(url: url, placeholderImageName: "rectangle.on.rectangle", cornerRadius: 12)
                            .aspectRatio(contentMode: .fit)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.systemBackground))
                            )
                            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 2)
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
}
