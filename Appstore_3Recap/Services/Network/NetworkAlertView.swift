//
//  NetworkAlertView.swift
//  Appstore_3Recap
//
//  Created by 권우석 on 4/25/25.
//

import SwiftUI

struct NetworkAlertView: View {
    let isDisconnected: Bool
    let message: String
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                // 네트워크 상태에 따른 아이콘
                Image(systemName: isDisconnected ? "wifi.slash" : "wifi")
                    .font(.system(size: 20))
                    .foregroundColor(isDisconnected ? .red : .green)
                    .padding(.trailing, 4)
                
                // 알림 메시지
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.appText)
                
                Spacer()
                
                // 닫기 버튼
                Button(action: {
                    withAnimation {
                        isPresented = false
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14))
                        .foregroundColor(.secondaryText)
                }
            }
            .padding()
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondaryBackground)
                .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
        )
        .padding(.horizontal)
    }
}




