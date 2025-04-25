//
//  CustomNavigationLink.swift
//  Appstore_3Recap
//
//  Created by 권우석 on 4/25/25.
//

import SwiftUI

struct CustomNavigationLink<Content: View, Destination: View>: View {
    let destination: Destination
    let content: () -> Content
    
    @State private var isActive = false
    
    init(destination: Destination, @ViewBuilder content: @escaping () -> Content) {
        self.destination = destination
        self.content = content
    }
    
    var body: some View {
        ZStack {
            NavigationLink(destination: destination, isActive: $isActive) {
                EmptyView()
            }
            .opacity(0)
            
            content()
                .allowsHitTesting(true) // 내부 뷰의 터치 이벤트 허용
            
            // 다운로드 버튼 영역을 제외한 나머지 영역에만 탭 제스처 적용
            GeometryReader { geometry in
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // 터치 위치 확인 (다운로드 버튼 영역이 아닌 경우에만 활성화)
                        isActive = true
                    }
            }
            .allowsHitTesting(true)
        }
        // 다운로드 버튼 영역에서의 이벤트 전파 중지
        .simultaneousGesture(
            TapGesture()
                .onEnded { _ in }
            , including: .subviews
        )
    }
}
