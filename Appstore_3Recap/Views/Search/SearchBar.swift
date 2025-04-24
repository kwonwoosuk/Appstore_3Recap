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
                        onCommit()
                    }
                    .onChange(of: text) { oldValue, newValue in
                        isEditing = true
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
            .padding(.vertical, 4)
            .background(BlurView(style: .prominent)) // 블러 효과
            .background(Color(.systemBackground).opacity(0.01)) 
            .cornerRadius(10)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            if isEditing {
                Button("취소") {
                    text = ""
                    isEditing = false
                    isFocused = false
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    onCancel()
                }
                .padding(.leading, 10)
                .transition(.move(edge: .trailing))
                .animation(.default, value: isEditing)
            }
        }
    }
}

// UIVisualEffectView를 SwiftUI에 통합
struct BlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: style))
        return view
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}
