//
//  AppDescriptionSection.swift
//  Appstore_3Recap
//
//  Created by 권우석 on 4/25/25.
//

import SwiftUI

struct AppDescriptionSection: View {
    let description: String
    let isExpanded: Bool
    let onToggle: () -> Void
    
    private let maxCollapsedLines = 3
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("설명")
                .font(.headline)
                .padding(.top, 4)
            
            Text(description)
                .font(.subheadline)
                .lineLimit(isExpanded ? nil : maxCollapsedLines)
                .padding(.vertical, 4)
            
            if needsMoreButton {
                Button(action: onToggle) {
                    Text(isExpanded ? "간략히 보기" : "더보기")
                        .font(.subheadline)
                        .foregroundColor(.appStoreBlue)
                }
            }
        }
    }
    
    private var needsMoreButton: Bool {
        let textHeight = description.height(withConstrainedWidth: UIScreen.main.bounds.width - 32, font: .systemFont(ofSize: 15))
        let lineHeight: CGFloat = 20 // 근사값
        return textHeight > lineHeight * CGFloat(maxCollapsedLines + 1)
    }
}
