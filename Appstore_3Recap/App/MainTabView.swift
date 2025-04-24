//
//  MainTabView.swift
//  Appstore_3Recap
//
//  Created by 권우석 on 4/25/25.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 4 // 검색 탭
    
    var body: some View {
        TabView(selection: $selectedTab) {
            TodayPlaceholderView()
                .tabItem {
                    Label("투데이", systemImage: "doc.text.image")
                }
                .tag(0)
            
            GamesPlaceholderView()
                .tabItem {
                    Label("게임", systemImage: "gamecontroller")
                }
                .tag(1)
            
            AsyncUserAppsView()
                .tabItem {
                    Label("앱", systemImage: "square.stack.3d.up")
                }
                .tag(2)
            
            ArcadePlaceholderView()
                .tabItem {
                    Label("아케이드", systemImage: "arcade.stick")
                }
                .tag(3)
            
            AsyncSearchView()
                .tabItem {
                    Label("검색", systemImage: "magnifyingglass")
                }
                .tag(4)
        }
        .onAppear {
            // 다운로드 매니저 백그라운드 타이머 초기화
            AppDownloadManager.shared.initializeBackgroundTimers()
            
            // UI 애니메이션 설정
            UIView.appearance().tintColor = UIColor(Color.appStoreBlue)
        }
    }
    
    
    // 구현되지 않은 탭을 위한 임시 뷰들
    struct TodayPlaceholderView: View {
        var body: some View {
            VStack {
                Image(systemName: "doc.text.image")
                    .font(.system(size: 80))
                    .foregroundColor(.gray.opacity(0.5))
                    .padding(.bottom)
                
                Text("투데이 탭")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.bottom, 4)
                
                Text("투데이 탭은 이 과제에서 구현되지 않았습니다.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gray)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.appBackground)
        }
    }
    
    struct GamesPlaceholderView: View {
        var body: some View {
            VStack {
                Image(systemName: "gamecontroller")
                    .font(.system(size: 80))
                    .foregroundColor(.gray.opacity(0.5))
                    .padding(.bottom)
                
                Text("게임 탭")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.bottom, 4)
                
                Text("게임 탭은 이 과제에서 구현되지 않았습니다.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gray)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.appBackground)
        }
    }
    
    struct ArcadePlaceholderView: View {
        var body: some View {
            VStack {
                Image(systemName: "arcade.stick")
                    .font(.system(size: 80))
                    .foregroundColor(.gray.opacity(0.5))
                    .padding(.bottom)
                
                Text("아케이드 탭")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.bottom, 4)
                
                Text("아케이드 탭은 이 과제에서 구현되지 않았습니다.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gray)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.appBackground)
        }
    }
}
