//
//  AppState.swift
//  whitemax
//
//  Глобальное состояние приложения
//

import Foundation
import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = true
    
    private let service = MaxClientService.shared
    
    init() {
        checkAuthentication()
    }
    
    func checkAuthentication() {
        isLoading = true
        
        Task {
            // Проверяем наличие токена
            let hasToken = service.checkAuthentication()
            
            if hasToken {
                // Пытаемся запустить клиент
                do {
                    try await service.startClient()
                    isAuthenticated = service.isAuthenticated
                } catch {
                    print("Failed to start client: \(error)")
                    isAuthenticated = false
                }
            } else {
                isAuthenticated = false
            }
            
            isLoading = false
        }
    }
    
    func setAuthenticated(_ value: Bool) {
        isAuthenticated = value
    }
}
