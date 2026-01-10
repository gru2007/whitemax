//
//  ContentView.swift
//  whitemax
//
//  Главный view с навигацией
//

import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState()
    
    var body: some View {
        Group {
            if appState.isLoading {
                ProgressView("Загрузка...")
            } else if appState.isAuthenticated {
                ChatsListView()
                    .environmentObject(appState)
            } else {
                NavigationStack {
                    LoginView()
                        .environmentObject(appState)
                }
            }
        }
        .onChange(of: MaxClientService.shared.isAuthenticated) { oldValue, newValue in
            appState.setAuthenticated(newValue)
        }
    }
}

#Preview {
    ContentView()
}
