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
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack {
                // 닫기 버튼
                HStack {
                    Spacer()
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .padding()
                    }
                }
                
                // 스크린샷 페이저
                TabView(selection: $currentIndex) {
                    ForEach(Array(screenshotURLs.enumerated()), id: \.offset) { index, url in
                        AsyncImageView(url: url, placeholderImageName: "rectangle.on.rectangle")
                            .aspectRatio(contentMode: .fit)
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
                
                // 인덱스 표시기
                Text("\(currentIndex + 1) / \(screenshotURLs.count)")
                    .foregroundColor(.white)
                    .font(.subheadline)
                    .padding(.bottom)
            }
        }
    }
}
