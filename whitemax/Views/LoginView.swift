//
//  LoginView.swift
//  whitemax
//
//  Экран ввода номера телефона для авторизации
//

import SwiftUI

struct LoginView: View {
    @StateObject private var service = MaxClientService.shared
    @State private var phoneNumber = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCodeVerification = false
    @State private var tempToken: String?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Вход в Max.RU")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top, 40)
            
            Text("Введите номер телефона для получения кода авторизации")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Номер телефона")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("+79991234567", text: $phoneNumber)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.phonePad)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            .padding(.horizontal)
            
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
            
            Button(action: {
                requestCode()
            }) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Text("Отправить код")
                        .fontWeight(.semibold)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isLoading || phoneNumber.isEmpty)
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
        .navigationDestination(isPresented: $showCodeVerification) {
            if let token = tempToken {
                CodeVerificationView(phoneNumber: phoneNumber, tempToken: token)
            }
        }
    }
    
    private func requestCode() {
        guard !phoneNumber.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Создаем wrapper для телефона
                try await service.createWrapper(phone: phoneNumber)
                
                // Запрашиваем код
                let token = try await service.requestCode(phone: phoneNumber)
                
                await MainActor.run {
                    self.tempToken = token
                    self.isLoading = false
                    self.showCodeVerification = true
                }
            } catch let error as MaxClientError {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Ошибка: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        LoginView()
    }
}
