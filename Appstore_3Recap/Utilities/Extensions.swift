//
//  Extensions.swift
//  Appstore_3Recap
//
//  Created by 권우석 on 4/25/25.
//

import Foundation
import SwiftUI


// MARK: - UserDefaults 확장
extension UserDefaults {
    static let groupShared = UserDefaults(suiteName: "group.com.appstore.clone") ?? .standard
}

// MARK: - Image 확장
extension Image {
    func roundedIcon(size: CGFloat = 60) -> some View {
        self
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Color 확장
extension Color {
    static let appBackground = Color(.systemBackground)
    static let secondaryBackground = Color(.secondarySystemBackground)
    static let appText = Color(.label)
    static let secondaryText = Color(.secondaryLabel)
    static let tertiaryText = Color(.tertiaryLabel)
    static let accentBlue = Color.blue
    static let appStoreBlue = Color(red: 0.0, green: 0.47, blue: 0.9)
}

// MARK: - View 확장
extension View {
    func defaultPadding() -> some View {
        self.padding(.horizontal, 16)
    }
    
    func defaultListRowInsets() -> some View {
        self.listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }
    
    @ViewBuilder
    func isHidden(_ hidden: Bool, remove: Bool = false) -> some View {
        if hidden {
            if !remove {
                self.hidden()
            }
        } else {
            self
        }
    }
}

// MARK: - 로딩 인디케이터 뷰
struct LoadingIndicator: View {
    var body: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.5)
            
            Text("로딩 중...")
                .font(.caption)
                .foregroundColor(.secondaryText)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }
}

// MARK: - 빈 결과 뷰
struct EmptyResultsView: View {
    let message: String
    let systemImageName: String
    let action: (() -> Void)?
    let actionTitle: String?
    
    init(
        message: String,
        systemImageName: String = "magnifyingglass",
        action: (() -> Void)? = nil,
        actionTitle: String? = nil
    ) {
        self.message = message
        self.systemImageName = systemImageName
        self.action = action
        self.actionTitle = actionTitle
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImageName)
                .font(.system(size: 50))
                .foregroundColor(.secondaryText)
            
            Text(message)
                .font(.headline)
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.center)
            
            if let action = action, let actionTitle = actionTitle {
                Button(action: action) {
                    Text(actionTitle)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.accentBlue)
                        .cornerRadius(10)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }
}

// MARK: - 네트워크 오류 뷰
struct NetworkErrorView: View {
    let error: APIError
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("네트워크 오류")
                .font(.headline)
                .foregroundColor(.appText)
            
            Text(error.message)
                .font(.subheadline)
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.center)
            
            Button(action: retryAction) {
                Text("다시 시도")
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.accentBlue)
                    .cornerRadius(10)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }
}



// MARK: - 이미지 로딩 뷰

struct AsyncImageView: View {
    let url: String
    let placeholderImageName: String
    var cornerRadius: CGFloat = 0
    
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var loadFailed = false
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if isLoading {
                ZStack {
                    Color.secondaryBackground
                    Image(systemName: placeholderImageName)
                        .foregroundColor(.gray)
                }
            } else if loadFailed {
                ZStack {
                    Color.secondaryBackground
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.gray)
                }
            }
        }
        .cornerRadius(cornerRadius)
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        // 이미 이미지가 로드되어 있으면 반환
        if image != nil { return }
        
        guard let imageURL = URL(string: url) else {
            isLoading = false
            loadFailed = true
            return
        }
        
        // 캐시에서 이미지 확인
        if let cachedImage = ImageCache.shared.get(for: url) {
            image = cachedImage
            isLoading = false
            return
        }
        
        // 백그라운드 큐에서 이미지 로드
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let data = try Data(contentsOf: imageURL)
                if let downloadedImage = UIImage(data: data) {
                    // 캐시에 저장
                    ImageCache.shared.set(downloadedImage, for: url)
                    
                    DispatchQueue.main.async {
                        self.image = downloadedImage
                        self.isLoading = false
                    }
                } else {
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.loadFailed = true
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.loadFailed = true
                }
            }
        }
    }
}

// MARK: - 별점 표시 뷰
struct RatingView: View {
    let rating: Double
    let count: Int?
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: getStarImageName(for: index))
                    .foregroundColor(.gray)
                    .font(.system(size: 12))
            }
            
            if let count = count {
                Text("(\(count))")
                    .font(.caption)
                    .foregroundColor(.tertiaryText)
            }
        }
    }
    
    private func getStarImageName(for index: Int) -> String {
        if Double(index) <= rating {
            return "star.fill"
        } else if Double(index) - 0.5 <= rating {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }
}


extension Notification.Name {
    // 네트워크 관련 알림
    static let networkConnected = Notification.Name("networkConnected")
    static let networkDisconnected = Notification.Name("networkDisconnected")
    
    // 다운로드 관련 알림
    static let downloadsPausedDueToNetwork = Notification.Name("downloadsPausedDueToNetwork")
    static let networkReconnected = Notification.Name("networkReconnected")
    
    // 타이머 관련 알림
    static let timersCompleted = Notification.Name("timersCompleted")
    
    // 기존 알림 명확화
    static let downloadStateChanged = Notification.Name("downloadStateChanged")
    static let downloadButtonStateChanged = Notification.Name("downloadButtonStateChanged")
    static let downloadProgressUpdated = Notification.Name("downloadProgressUpdated")
    
    // 앱 초기화 시 타이머 강제 시작을 위한 알림 추가
    static let forceTimerStart = Notification.Name("forceTimerStart")
    
    // UI 강제 업데이트 알림
    static let forceUIRefresh = Notification.Name("forceUIRefresh")
}
