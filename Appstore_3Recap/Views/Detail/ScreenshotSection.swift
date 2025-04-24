//
//  ScreenshotSection.swift
//  Appstore_3Recap
//
//  Created by 권우석 on 4/25/25.
//

import SwiftUI

struct ScreenshotSection: View {
    let screenshotURLs: [String]
    let onScreenshotTap: (Int) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("미리보기")
                .font(.headline)
                .padding(.top, 4)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(screenshotURLs.enumerated()), id: \.offset) { index, url in
                        AsyncImageView(url: url, placeholderImageName: "rectangle.on.rectangle", cornerRadius: 12)
                            .frame(width: 200, height: 360)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                            .onTapGesture {
                                onScreenshotTap(index)
                            }
                    }
                }
            }
        }
    }
}
