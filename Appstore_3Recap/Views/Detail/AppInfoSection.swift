//
//  AppInfoSection.swift
//  Appstore_3Recap
//
//  Created by 권우석 on 4/25/25.
//

import SwiftUI

struct AppInfoSection: View {
    let app: AppModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("정보")
                .font(.headline)
                .padding(.top, 4)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 24) {
                    InfoItem(title: "판매자", value: app.developerName)
                    InfoItem(title: "카테고리", value: app.category)
                    InfoItem(title: "연령", value: app.ageRating)
                    InfoItem(title: "가격", value: app.price)
                    InfoItem(title: "크기", value: formatFileSize(app.size))
                    InfoItem(title: "버전", value: app.version)
                    InfoItem(title: "출시일", value: app.releaseDate)
                    InfoItem(title: "최소 버전", value: "iOS \(app.minimumOsVersion)")
                }
                .padding(.vertical, 8)
            }
        }
    }
    
    private func formatFileSize(_ sizeString: String) -> String {
        if let size = Int(sizeString) {
            let bcf = ByteCountFormatter()
            bcf.allowedUnits = [.useMB]
            bcf.countStyle = .file
            return bcf.string(fromByteCount: Int64(size))
        }
        return sizeString
    }
}

struct InfoItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondaryText)
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.appText)
        }
        .frame(minWidth: 80, alignment: .leading)
    }
}
