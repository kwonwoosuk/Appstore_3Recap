//
//  ReleaseNotesSection.swift
//  Appstore_3Recap
//
//  Created by 권우석 on 4/25/25.
//

import SwiftUI

struct ReleaseNotesSection: View {
    let releaseNotes: String
    let isExpanded: Bool
    let onToggle: () -> Void
    
    private let maxCollapsedLines = 3
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("새로운 소식")
                .font(.headline)
                .padding(.top, 4)
            
            Text(releaseNotes)
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
        let textHeight = releaseNotes.height(withConstrainedWidth: UIScreen.main.bounds.width - 32, font: .systemFont(ofSize: 15))
        let lineHeight: CGFloat = 20 // 근사값
        return textHeight > lineHeight * CGFloat(maxCollapsedLines + 1)
    }
}

extension String {
    func height(withConstrainedWidth width: CGFloat, font: UIFont) -> CGFloat {
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingBox = self.boundingRect(
            with: constraintRect,
            options: .usesLineFragmentOrigin,
            attributes: [NSAttributedString.Key.font: font],
            context: nil
        )
        return ceil(boundingBox.height)
    }
}
