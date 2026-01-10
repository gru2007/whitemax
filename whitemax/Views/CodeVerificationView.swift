//
//  CodeVerificationView.swift
//  whitemax
//
//  Экран ввода кода верификации
//

import SwiftUI

struct CodeVerificationView: View {
    let phoneNumber: String
    let tempToken: String
    
    @StateObject private var service = MaxClientService.shared
    @State private var code = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Подтверждение")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top, 40)
            
            Text("Введите код из SMS")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Text("Отправлено на \(phoneNumber)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Код верификации")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("000000", text: $code)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.title2)
                    .onChange(of: code) { oldValue, newValue in
                        // Ограничиваем ввод 6 цифрами
                        code = String(newValue.prefix(6).filter { $0.isNumber })
                    }
            }
            .padding(.horizontal)
            
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
            
            Button(action: {
                verifyCode()
            }) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Text("Войти")
                        .fontWeight(.semibold)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isLoading || code.count != 6)
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
        .navigationBarBackButtonHidden(isLoading)
    }
    
    private func verifyCode() {
        guard code.count == 6 else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let user = try await service.loginWithCode(tempToken: tempToken, code: code)
                
                await MainActor.run {
                    self.isLoading = false
                    // Навигация будет обработана через AppState
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
        CodeVerificationView(phoneNumber: "+79991234567", tempToken: "test_token")
    }
}
