//
//  NetworkService.swift
//  Appstore_3Recap
//
//  Created by 권우석 on 4/25/25.
//


import Foundation
import Combine

// MARK: - API Error
enum APIError: Error {
    case invalidURL
    case invalidResponse
    case networkError(Error)
    case decodingError(Error)
    case callLimitExceeded
    case serverError
    case unknownError
    case emptyResponse
    
    var message: String {
        switch self {
        case .invalidURL:
            return "잘못된 URL입니다."
        case .invalidResponse:
            return "서버로부터 유효하지 않은 응답을 받았습니다."
        case .networkError(let error):
            return "네트워크 오류: \(error.localizedDescription)"
        case .decodingError(let error):
            return "데이터 변환 오류: \(error.localizedDescription)"
        case .callLimitExceeded:
            return "API 호출 한도를 초과했습니다."
        case .serverError:
            return "서버 오류가 발생했습니다."
        case .unknownError:
            return "알 수 없는 오류가 발생했습니다."
        case .emptyResponse:
            return "서버에서 빈 응답을 받았습니다."
        }
    }
}

class NetworkService {
    static let shared = NetworkService()
    
    private(set) var useMockData: Bool = false
    private let mockDataProvider = MockDataProvider.shared
    
    // 캐시된 앱 목록 - AppDownloadManager에서 사용
    private(set) var cachedApps: [AppModel] = []
    
    private init() {}
    
    func setMockMode(enabled: Bool) {
        useMockData = enabled
    }
    
    
    func cacheApp(_ app: AppModel) {
        if !cachedApps.contains(where: { $0.id == app.id }) {
            cachedApps.append(app)
        }
    }
    
    // MARK: - Swift Concurrency API
    func searchApps(query: String) async throws -> [AppModel] {
        if useMockData {
            let response = mockDataProvider.getMockITunesSearchResponse(for: query)
            let apps = response.toApps()
            for app in apps {
                cacheApp(app)
            }
            return apps
        }
        
        guard let url = APIRequestBuilder.buildSearchURL(term: query) else {
            throw APIError.invalidURL
        }
        
        print("Fetching from URL: \(url.absoluteString)")
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        print("Response status code: \(httpResponse.statusCode)")
        
        switch httpResponse.statusCode {
        case 200...299:
            // Debug: Print a sample of the data
            if let dataString = String(data: data.prefix(200), encoding: .utf8) {
                print("Response data sample: \(dataString)...")
            }
            
            // Check if the data is empty
            if data.isEmpty {
                print("Warning: Empty data returned from server")
                throw APIError.emptyResponse
            }
            
            do {
                let response = try JSONDecoder().decode(ITunesSearchResponse.self, from: data)
                let apps = response.toApps()
                
                // 앱 캐시에 저장
                for app in apps {
                    cacheApp(app)
                }
                
                return apps
            } catch {
                print("Decoding error: \(error)")
                throw APIError.decodingError(error)
            }
            
        case 429:
            throw APIError.callLimitExceeded
        case 500...599:
            throw APIError.serverError
        default:
            throw APIError.unknownError
        }
    }
    
    func fetchAppDetail(id: String) async throws -> AppModel {
        if useMockData {
            // Just를 사용하지 않고 직접 MockDataProvider에서 응답 가져오기
            let response = mockDataProvider.getMockAppDetail(for: id)
            if let app = response.toApps().first {
                cacheApp(app)
                return app
            }
            throw APIError.emptyResponse
        }
        
        guard let url = APIRequestBuilder.buildLookupURL(id: id) else {
            throw APIError.invalidURL
        }
        
        print("Fetching app detail from URL: \(url.absoluteString)")
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        print("Response status code: \(httpResponse.statusCode)")
        
        switch httpResponse.statusCode {
        case 200...299:
            do {
                let response = try JSONDecoder().decode(ITunesSearchResponse.self, from: data)
                if let app = response.toApps().first {
                    cacheApp(app)
                    return app
                } else {
                    throw APIError.emptyResponse
                }
            } catch {
                print("Decoding error: \(error)")
                throw APIError.decodingError(error)
            }
            
        case 429:
            throw APIError.callLimitExceeded
        case 500...599:
            throw APIError.serverError
        default:
            throw APIError.unknownError
        }
    }
    
    // 트렌딩 앱 가져오기 (인기 검색어로 대체)
    func fetchTrendingApps() async throws -> [AppModel] {
        // 인기 검색어 목록
        let popularTerms = ["게임", "카카오", "네이버", "유튜브", "인스타그램"]
        let randomTerm = popularTerms.randomElement() ?? "인기앱"
        
        return try await searchApps(query: randomTerm)
    }
    
    // MARK: - Combine 브릿지
    func searchApps(query: String) -> AnyPublisher<[AppModel], APIError> {
        return Future { promise in
            Task {
                do {
                    let result = try await self.searchApps(query: query)
                    promise(.success(result))
                } catch let error as APIError {
                    promise(.failure(error))
                } catch {
                    promise(.failure(.networkError(error)))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func fetchAppDetail(id: String) -> AnyPublisher<AppModel, APIError> {
        return Future { promise in
            Task {
                do {
                    let result = try await self.fetchAppDetail(id: id)
                    promise(.success(result))
                } catch let error as APIError {
                    promise(.failure(error))
                } catch {
                    promise(.failure(.networkError(error)))
                }
            }
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - Mock Data Provider
class MockDataProvider {
    static let shared = MockDataProvider()
    
    private init() {}
    
    // Combine 방식이 아닌 동기 방식으로 직접 데이터 반환
    func getMockITunesSearchResponse(for query: String) -> ITunesSearchResponse {
        // Mock 앱 데이터
        let mockApp = ITunesApp(
            trackId: 6744337138,
            trackName: "MEOWIARY",
            bundleId: "com.kwonws.MEOWIARY",
            version: "1.0.4",
            artistName: "woosuk kwon",
            artistId: 1805501307,
            price: 0,
            formattedPrice: "무료",
            currency: "KRW",
            description: "당신의 오늘 하루는 어땠나요? 냥주인님과 꽁냥꽁냥 잘지내셨는지요 ;-)\n\n귀여원던 사진과 함께 오늘하루를 정리해보는건 어떠신가요~?\n사용할일이 없으면 좋겠지만 증상을 빠르게 심각도와 함께 저장하는 기능도 있답니다\n우리 냥이는 소중하니까 늦은밤에 근처 24시간 병원을 빠르게 찾을 수 있는 기능도 있습니다 !\n\n귀여운사진들을 한데 모아 회상하고\n사진들을 합쳐 Gif나 동영상으로 변환할 수 있어요!\n\n[서비스 접근권한 안내]\n- 사용자 카메라 접근권한\n- 사용자 앨범 접근권한\n- 사용자 위치정보 접근 권한",
            releaseNotes: "- 태그별색상을 지정하여 일정을 추가하고 위젯에서 디데이를 바로  볼 수 있는 기능을 추가했어요 \n\n- 일정 목록을 한번에 볼 수 있는 화면이 추가 되었어요!\n\n- 헉헉 열일 중!! 많이 사용해주세요 :)",
            primaryGenreName: "라이프스타일",
            genres: ["라이프스타일", "의료", "소셜 네트워킹"], // 장르 추가
            genreIds: ["6012", "6020"],
            trackContentRating: "12+",
            contentAdvisoryRating: "12+",
            minimumOsVersion: "15.6",
            averageUserRating: 5.0,
            userRatingCount: 3,
            artworkUrl60: "https://is1-ssl.mzstatic.com/image/thumb/Purple211/v4/3a/9a/f5/3a9af5cb-f14f-f3f6-c2a3-a1592b842964/AppIcon-0-0-1x_U007ephone-0-1-85-220.png/60x60bb.jpg",
            artworkUrl100: "https://is1-ssl.mzstatic.com/image/thumb/Purple211/v4/3a/9a/f5/3a9af5cb-f14f-f3f6-c2a3-a1592b842964/AppIcon-0-0-1x_U007ephone-0-1-85-220.png/100x100bb.jpg",
            artworkUrl512: "https://is1-ssl.mzstatic.com/image/thumb/Purple211/v4/3a/9a/f5/3a9af5cb-f14f-f3f6-c2a3-a1592b842964/AppIcon-0-0-1x_U007ephone-0-1-85-220.png/512x512bb.jpg",
            screenshotUrls: [
                "https://via.placeholder.com/300x600?text=MEOWIARY_1",
                "https://via.placeholder.com/300x600?text=MEOWIARY_2",
                "https://via.placeholder.com/300x600?text=MEOWIARY_3"
            ],
            ipadScreenshotUrls: [],
            releaseDate: "2025-04-10T07:00:00Z",
            currentVersionReleaseDate: "2025-04-23T07:22:50Z",
            languageCodesISO2A: ["EN"],
            fileSizeBytes: "16675840"
        )
        
        // 카카오톡 앱 모크 데이터 (추가)
        let kakaoTalkApp = ITunesApp(
            trackId: 362057947,
            trackName: "카카오톡",
            bundleId: "com.kakao.talk",
            version: "10.0.7",
            artistName: "Kakao Corp.",
            artistId: 304013645,
            price: 0,
            formattedPrice: "무료",
            currency: "KRW",
            description: "카카오톡은 전세계 어디서나 무료로 즐기는 메신저 앱입니다.",
            releaseNotes: "버그 수정 및 안정성 개선",
            primaryGenreName: "Social Networking",
            genres: ["소셜 네트워킹", "생산성"],
            genreIds: ["6005", "6007"],
            trackContentRating: "4+",
            contentAdvisoryRating: "4+",
            minimumOsVersion: "16.0",
            averageUserRating: 4.5,
            userRatingCount: 887,
            artworkUrl60: "https://is1-ssl.mzstatic.com/image/thumb/Purple126/v4/78/a2/c1/78a2c1bd-d531-7f31-9e65-a9be9b1459f4/AppIcon-0-0-1x_U007emarketing-0-0-0-7-0-0-sRGB-0-0-0-GLES2_U002c0-512MB-85-220-0-0.png/60x60bb.jpg",
            artworkUrl100: "https://is1-ssl.mzstatic.com/image/thumb/Purple126/v4/78/a2/c1/78a2c1bd-d531-7f31-9e65-a9be9b1459f4/AppIcon-0-0-1x_U007emarketing-0-0-0-7-0-0-sRGB-0-0-0-GLES2_U002c0-512MB-85-220-0-0.png/100x100bb.jpg",
            artworkUrl512: "https://is1-ssl.mzstatic.com/image/thumb/Purple126/v4/78/a2/c1/78a2c1bd-d531-7f31-9e65-a9be9b1459f4/AppIcon-0-0-1x_U007emarketing-0-0-0-7-0-0-sRGB-0-0-0-GLES2_U002c0-512MB-85-220-0-0.png/512x512bb.jpg",
            screenshotUrls: [
                "https://via.placeholder.com/300x600?text=KakaoTalk_1",
                "https://via.placeholder.com/300x600?text=KakaoTalk_2",
                "https://via.placeholder.com/300x600?text=KakaoTalk_3"
            ],
            ipadScreenshotUrls: [],
            releaseDate: "2010-03-18T07:00:00Z",
            currentVersionReleaseDate: "2025-04-01T07:00:00Z",
            languageCodesISO2A: ["KO", "EN", "JA"],
            fileSizeBytes: "158956544"
        )
        
        // 네이버 지도 앱 모크 데이터 (추가)
        let naverMapApp = ITunesApp(
            trackId: 311867728,
            trackName: "네이버 지도, 내비게이션",
            bundleId: "com.nhn.NMap",
            version: "6.5.0",
            artistName: "NAVER Corp.",
            artistId: 411206400,
            price: 0,
            formattedPrice: "무료",
            currency: "KRW",
            description: "길찾기, 교통정보, 내비게이션까지 제공하는 국내 대표 지도 서비스",
            releaseNotes: "버그 수정 및 인터페이스 개선",
            primaryGenreName: "Navigation",
            genres: ["내비게이션", "여행"],
            genreIds: ["6010", "6003"],
            trackContentRating: "4+",
            contentAdvisoryRating: "4+",
            minimumOsVersion: "16.0",
            averageUserRating: 4.8,
            userRatingCount: 568,
            artworkUrl60: "https://is1-ssl.mzstatic.com/image/thumb/Purple116/v4/5b/0f/91/5b0f915a-9c3c-a183-c41c-79ca1dbcad2a/AppIcon-0-0-1x_U007emarketing-0-0-0-5-0-0-sRGB-0-0-0-GLES2_U002c0-512MB-85-220-0-0.png/60x60bb.jpg",
            artworkUrl100: "https://is1-ssl.mzstatic.com/image/thumb/Purple116/v4/5b/0f/91/5b0f915a-9c3c-a183-c41c-79ca1dbcad2a/AppIcon-0-0-1x_U007emarketing-0-0-0-5-0-0-sRGB-0-0-0-GLES2_U002c0-512MB-85-220-0-0.png/100x100bb.jpg",
            artworkUrl512: "https://is1-ssl.mzstatic.com/image/thumb/Purple116/v4/5b/0f/91/5b0f915a-9c3c-a183-c41c-79ca1dbcad2a/AppIcon-0-0-1x_U007emarketing-0-0-0-5-0-0-sRGB-0-0-0-GLES2_U002c0-512MB-85-220-0-0.png/512x512bb.jpg",
            screenshotUrls: [
                "https://via.placeholder.com/300x600?text=NaverMap_1",
                "https://via.placeholder.com/300x600?text=NaverMap_2",
                "https://via.placeholder.com/300x600?text=NaverMap_3"
            ],
            ipadScreenshotUrls: [],
            releaseDate: "2009-08-21T07:00:00Z",
            currentVersionReleaseDate: "2025-03-15T07:00:00Z",
            languageCodesISO2A: ["KO", "EN", "JA", "ZH"],
            fileSizeBytes: "189765632"
        )
        
        // 쿼리에 따라 다른 앱 반환
        var results: [ITunesApp] = []
        
        if query.lowercased().contains("카카오") {
            results.append(kakaoTalkApp)
        } else if query.lowercased().contains("네이버") || query.lowercased().contains("지도") {
            results.append(naverMapApp)
        } else {
            results.append(mockApp)
            if query.count > 2 {
                results.append(kakaoTalkApp)
                results.append(naverMapApp)
            }
        }
        
        return ITunesSearchResponse(resultCount: results.count, results: results)
    }
    
    // 앱 상세 정보 Mock - 동기 방식
    func getMockAppDetail(for id: String) -> ITunesSearchResponse {
        // ID에 따라 다른 앱 상세 정보 반환
        if id == "362057947" {
            return ITunesSearchResponse(resultCount: 1, results: [
                getMockITunesSearchResponse(for: "카카오").results[0]
            ])
        } else if id == "311867728" {
            return ITunesSearchResponse(resultCount: 1, results: [
                getMockITunesSearchResponse(for: "네이버").results[0]
            ])
        } else {
            return ITunesSearchResponse(resultCount: 1, results: [
                getMockITunesSearchResponse(for: "").results[0]
            ])
        }
    }
    
    // Combine 사용 시 호환성을 위한 메서드
    func getMockSearchResponse(for query: String) -> AnyPublisher<ITunesSearchResponse, Never> {
        return Just(getMockITunesSearchResponse(for: query))
            .eraseToAnyPublisher()
    }
    
    func getMockAppDetailPublisher(for id: String) -> AnyPublisher<ITunesSearchResponse, Never> {
        return Just(getMockAppDetail(for: id))
            .eraseToAnyPublisher()
    }
}
