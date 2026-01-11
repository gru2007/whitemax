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
        ZStack {
            LinearGradient(
                colors: [Color.accentColor.opacity(0.18), Color(uiColor: .systemBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .overlay { Rectangle().fill(.ultraThinMaterial).opacity(0.55) }

            VStack(spacing: 18) {
                VStack(spacing: 8) {
                    Text("Подтверждение")
                        .font(.largeTitle.bold())
                    Text("Введите код из SMS")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 28)
                .padding(.horizontal, 20)

                Text("Отправлено на \(phoneNumber)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Код")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("000000", text: $code)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.title2.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .liquidGlass(cornerRadius: 16, material: .thinMaterial)
                        .onChange(of: code) { _, newValue in
                            // Ограничиваем ввод 6 цифрами
                            code = String(newValue.prefix(6).filter { $0.isNumber })
                        }
                }
                .padding(.horizontal, 20)

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 20)
                }

                Button(action: verifyCode) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("Войти")
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isLoading || code.count != 6)
                .padding(.horizontal, 20)

                Spacer(minLength: 0)
            }
        }
        .navigationBarBackButtonHidden(isLoading)
    }
    
    private func verifyCode() {
        guard code.count == 6 else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                _ = try await service.loginWithCode(tempToken: tempToken, code: code)
                
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
