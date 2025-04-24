//
//  AppHeaderSection.swift
//  Appstore_3Recap
//
//  Created by 권우석 on 4/25/25.
//

import SwiftUI

struct AppHeaderSection: View {
    let app: AppModel
    let downloadState: AppDownloadState
    let onDownloadAction: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // 앱 아이콘
            AsyncImageView(url: app.iconURL, placeholderImageName: "app.fill", cornerRadius: 16)
                .frame(width: 120, height: 120)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(app.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .lineLimit(2)
                
                Text(app.developerName)
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                
                Spacer()
                
                // 다운로드 버튼
                AppDownloadButton(app: app, state: downloadState, action: onDownloadAction)
                    .frame(height: 32)
            }
        }
        .frame(height: 120)
    }
}
