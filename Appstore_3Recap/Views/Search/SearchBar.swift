//
//  SearchBar.swift
//  Appstore_3Recap
//
//  Created by 권우석 on 4/25/25.
//

import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    var onCommit: () -> Void
    var onCancel: () -> Void
    
    @FocusState private var isFocused: Bool
    @State private var isEditing = false
    
    var body: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                    .padding(.leading, 8)
                
                TextField("앱, 게임, 스토리 등", text: $text)
                    .padding(8)
                    .focused($isFocused)
                    .onSubmit {
                        // 리턴키를 눌렀을 때 검색 실행
                        onCommit()
                    }
                    .onChange(of: text) { oldValue, newValue in
                        isEditing = true
                        // 실시간 검색은 제거하고 리턴키를 통해서만 검색하도록 변경
                    }
                
                if !text.isEmpty {
                    Button(action: {
                        text = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .padding(.trailing, 8)
                    }
                }
            }
            .background(Color.secondaryBackground)
            .cornerRadius(10)
            
            if isEditing {
                Button("취소") {
                    text = ""
                    isEditing = false
                    isFocused = false
                    
                    // 키보드 내리기
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    
                    // 취소 액션 실행 (검색 결과 초기화)
                    onCancel()
                }
                .padding(.leading, 10)
                .transition(.move(edge: .trailing))
                .animation(.default, value: isEditing)
            }
        }
    }
}
