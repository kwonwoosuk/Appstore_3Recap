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
    let clickingButton: Bool
    
    @State private var isActive = false
    
    init(destination: Destination, clickingButton: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        self.destination = destination
        self.content = content
        self.clickingButton = clickingButton
    }
    
    var body: some View {
        ZStack {
            NavigationLink(destination: destination, isActive: $isActive) {
                EmptyView()
            }
            .opacity(0)
            
            content()
                .contentShape(Rectangle())
                .onTapGesture {
                    // 버튼을 클릭한 경우는 NavigationLink를 활성화하지 않음
                    if !clickingButton {
                        isActive = true
                    }
                }
        }
    }
}
