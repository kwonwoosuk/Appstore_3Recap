//
//  NetworkService.swift
//  Appstore_3Recap
//
//  Created by 권우석 on 4/25/25.
//

import Foundation
import Combine

// MARK: - API URLs
enum APIURL {
    static let baseURL = "https://itunes.apple.com"
    static let searchURL = "\(baseURL)/search"
    static let lookupURL = "\(baseURL)/lookup"
    
    static func searchURLWithParameters(term: String, country: String = "kr", media: String = "software", limit: Int = 20) -> String {
        return "\(searchURL)?term=\(term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&country=\(country)&media=\(media)&limit=\(limit)"
    }
    
    static func lookupURLWithId(_ id: String) -> String {
        return "\(lookupURL)?id=\(id)"
    }
}

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

// MARK: - Network Service
class NetworkService {
    static let shared = NetworkService()
    
    private(set) var useMockData: Bool = false
    private let mockDataProvider = MockDataProvider.shared
    
    private init() {}
    
    func setMockMode(enabled: Bool) {
        useMockData = enabled
    }
    
    private func fetch<T: Decodable>(url: URL) -> AnyPublisher<T, APIError> {
        print("Fetching from URL: \(url.absoluteString)")
        
        return URLSession.shared.dataTaskPublisher(for: url)
            .tryMap { (data, response) -> Data in
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
                    
                    // Check if the data is empty or just contains empty brackets []
                    if data.isEmpty || (data.count <= 2 && String(data: data, encoding: .utf8) == "[]") {
                        print("Warning: Empty data returned from server")
                        throw APIError.emptyResponse
                    }
                    
                    return data
                case 429:
                    throw APIError.callLimitExceeded
                case 500...599:
                    throw APIError.serverError
                default:
                    throw APIError.unknownError
                }
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .mapError { error in
                print("Error in network request: \(error)")
                
                if let apiError = error as? APIError {
                    return apiError
                } else if let decodingError = error as? DecodingError {
                    print("Decoding error details: \(decodingError)")
                    return APIError.decodingError(error)
                } else {
                    return APIError.networkError(error)
                }
            }
            .eraseToAnyPublisher()
    }
    
    func searchApps(query: String) -> AnyPublisher<ITunesSearchResponse, APIError> {
        // Mock 모드인 경우
        if useMockData {
            return mockDataProvider.getMockSearchResponse(for: query)
                .setFailureType(to: APIError.self)
                .eraseToAnyPublisher()
        }
        
        // 실제 API 호출 코드
        guard let url = URL(string: APIURL.searchURLWithParameters(term: query)) else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        return fetch(url: url)
    }
    
    func fetchAppDetail(id: String) -> AnyPublisher<ITunesSearchResponse, APIError> {
        // Mock 모드인 경우
        if useMockData {
            return mockDataProvider.getMockAppDetail(for: id)
                .setFailureType(to: APIError.self)
                .eraseToAnyPublisher()
        }
        
        // 실제 API 호출 코드
        guard let url = URL(string: APIURL.lookupURLWithId(id)) else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        return fetch(url: url)
    }
    
    // 최신 트렌딩 앱 가져오기 (현재 이 기능은 iTunes Search API에서 직접 지원하지 않으므로 인기 검색어로 대체)
    func fetchTrendingApps() -> AnyPublisher<ITunesSearchResponse, APIError> {
        // 인기 검색어 목록 (실제 앱에서는 이 부분을 DB나 서버에서 가져온 인기 검색어로 대체할 수 있음)
        let popularTerms = ["게임", "카카오", "네이버", "유튜브", "인스타그램"]
        let randomTerm = popularTerms.randomElement() ?? "인기앱"
        
        return searchApps(query: randomTerm)
    }
}

// MARK: - Mock Data Provider
class MockDataProvider {
    static let shared = MockDataProvider()
    
    private init() {}
    
    // Mock 검색 결과
    func getMockSearchResponse(for query: String) -> Just<ITunesSearchResponse> {
        // JSON 파일에서 Mock 데이터를 로드하거나, 하드코딩된 데이터 사용
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
            genres: ["라이프스타일", "의료"],
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
        
        let response = ITunesSearchResponse(resultCount: 1, results: [mockApp])
        return Just(response)
    }
    
    // Mock 앱 상세 정보
    func getMockAppDetail(for id: String) -> Just<ITunesSearchResponse> {
        return getMockSearchResponse(for: "")
    }
}
