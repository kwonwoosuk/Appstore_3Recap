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

