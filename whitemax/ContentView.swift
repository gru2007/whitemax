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
    }
}

#Preview {
    ContentView()
}
