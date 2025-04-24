//
//  UserAppRow.swift
//  Appstore_3Recap
//
//  Created by 권우석 on 4/25/25.
//

import SwiftUI

struct UserAppRow: View {
    let app: AppModel
    
    // yyyy년 MM월 dd일 형식을 yyyy.MM.dd 형식으로 변환하는 함수
    private func formatDate(_ dateString: String) -> String {
        // 기존 포맷에서 년, 월, 일 추출
        let components = dateString.components(separatedBy: CharacterSet(charactersIn: "년월일 "))
            .filter { !$0.isEmpty }
        
        // 추출된 구성요소가 3개(년, 월, 일)인지 확인
        if components.count >= 3 {
            let year = components[0]
            let month = components[1]
            let day = components[2]
            
            return "\(year).\(month).\(day)"
        }
        
        // 파싱할 수 없는 경우 원본 반환
        return dateString
    }
    
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
                
                // 카테고리와 버전 대신 출시일(릴리즈 날짜) yyyy.MM.dd 형식으로 표시
                Text(formatDate(app.releaseDate))
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .lineLimit(1)
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
