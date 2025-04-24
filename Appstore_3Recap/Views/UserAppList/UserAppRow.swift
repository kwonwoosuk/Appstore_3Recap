//
//  UserAppRow.swift
//  Appstore_3Recap
//
//  Created by 권우석 on 4/25/25.
//

import SwiftUI

struct UserAppRow: View {
    let app: AppModel
    
    var body: some View {
        HStack(spacing: 12) {
            // 앱 아이콘
            AsyncImageView(url: app.iconURL, placeholderImageName: "app.fill", cornerRadius: 12)
                .frame(width: 60, height: 60)
            
            // 앱 정보
            VStack(alignment: .leading, spacing: 4) {
                Text(app.name)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(app.category)
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .lineLimit(1)
                
                // 버전
                Text("버전 \(app.version)")
                    .font(.caption)
                    .foregroundColor(.tertiaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // 열기 버튼
            AppDownloadButton(
                app: app,
                state: .downloaded
            ) {
                // 앱 열기 액션 - 실제로는 앱을 실행하는 코드가 여기에 들어갈 수 있음
                print("앱 열기: \(app.name)")
            }
        }
        .padding(.vertical, 8)
    }
}
