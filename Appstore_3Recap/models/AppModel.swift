//
//  AppModel.swift
//  Appstore_3Recap
//
//  Created by 권우석 on 4/25/25.
//

import Foundation

// iTunes Search API 응답 모델
struct ITunesSearchResponse: Decodable {
    let resultCount: Int
    let results: [ITunesApp]
    
    // 앱 모델로 변환하는 확장
    func toApps() -> [AppModel] {
        return results.map { itunesApp in
            return itunesApp.toAppModel()
        }
    }
}

// iTunes 앱 정보 모델
struct ITunesApp: Decodable {
    let trackId: Int
    let trackName: String
    let bundleId: String?
    let version: String?
    let artistName: String
    let artistId: Int?
    
    let price: Double
    let formattedPrice: String
    let currency: String?
    
    let description: String
    let releaseNotes: String?
    let primaryGenreName: String
    let genres: [String]?
    let genreIds: [String]?
    
    let trackContentRating: String
    let contentAdvisoryRating: String?
    
    let minimumOsVersion: String?
    let averageUserRating: Double?
    let userRatingCount: Int?
    
    // 이미지 URL
    let artworkUrl60: String?
    let artworkUrl100: String?
    let artworkUrl512: String?
    
    // 스크린샷 URL
    let screenshotUrls: [String]?
    let ipadScreenshotUrls: [String]?
    
    let releaseDate: String?
    let currentVersionReleaseDate: String?
    
    let languageCodesISO2A: [String]?
    let fileSizeBytes: String?
    
    // AppModel로 변환
    func toAppModel() -> AppModel {
        return AppModel(
            id: String(trackId),
            name: trackName,
            developerName: artistName,
            iconURL: artworkUrl512 ?? artworkUrl100 ?? artworkUrl60 ?? "",
            category: primaryGenreName,
            rating: averageUserRating ?? 0.0,
            version: version ?? "1.0",
            ageRating: trackContentRating,
            screenshotURLs: screenshotUrls ?? [],
            description: description,
            releaseNotes: releaseNotes ?? "",
            price: formattedPrice,
            size: fileSizeBytes ?? "",
            releaseDate: formatDate(dateString: releaseDate),
            minimumOsVersion: minimumOsVersion ?? "15.0"
        )
    }
    
    private func formatDate(dateString: String?) -> String {
        guard let dateString = dateString else {
            return "정보 없음"
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        formatter.locale = Locale(identifier: "ko_KR")
        
        if let date = formatter.date(from: dateString) {
            formatter.dateFormat = "yyyy년 MM월 dd일"
            return formatter.string(from: date)
        }
        
        return "정보 없음"
    }
}

// 앱 모델
struct AppModel: Identifiable, Equatable {
    let id: String
    let name: String
    let developerName: String
    let iconURL: String
    let category: String
    let rating: Double
    let version: String
    let ageRating: String
    let screenshotURLs: [String]
    let description: String
    let releaseNotes: String
    let price: String
    let size: String
    let releaseDate: String
    let minimumOsVersion: String
    
    // 스크린샷 URL이 없으면 더미 URL 생성
    var effectiveScreenshotURLs: [String] {
        if screenshotURLs.isEmpty {
            return [
                "https://via.placeholder.com/300x600?text=\(name)_1",
                "https://via.placeholder.com/300x600?text=\(name)_2",
                "https://via.placeholder.com/300x600?text=\(name)_3"
            ]
        }
        return screenshotURLs
    }
    
    static func == (lhs: AppModel, rhs: AppModel) -> Bool {
        return lhs.id == rhs.id
    }
}

// 앱 다운로드 상태
enum AppDownloadState: Equatable {
    case notDownloaded       // 받기
    case downloading(Float)  // 다운로드중 (진행률)
    case paused(Float)       // 재개 (중단 시점의 진행률)
    case downloaded          // 열기
    case redownload          // 다시받기
    
    var buttonText: String {
        switch self {
        case .notDownloaded:
            return "받기"
        case .downloading:
            return ""  // 프로그레스 표시
        case .paused:
            return "재개"
        case .downloaded:
            return "열기"
        case .redownload:
            return "다시받기"
        }
    }
}

// 앱 다운로드 정보
struct AppDownloadInfo: Identifiable {
    let id: String  // 앱 ID와 동일
    var state: AppDownloadState
    var progress: Float = 0.0  // 0.0 ~ 1.0
    var downloadStartTime: Date?
    var downloadElapsedTime: TimeInterval = 0.0
    
    init(id: String, state: AppDownloadState = .notDownloaded) {
        self.id = id
        self.state = state
    }
}
