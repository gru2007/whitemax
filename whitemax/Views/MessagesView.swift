//
//  MessagesView.swift
//  whitemax
//
//  Экран с сообщениями чата
//

import SwiftUI

struct MessagesView: View {
    let chat: MaxChat
    
    @StateObject private var service = MaxClientService.shared
    @State private var messages: [MaxMessage] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView("Загрузка сообщений...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Text("Ошибка загрузки")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("Повторить") {
                        loadMessages()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if messages.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "message")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("Нет сообщений")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(messages) { message in
                            MessageRow(message: message)
                        }
                    }
                    .padding()
                }
                .refreshable {
                    await loadMessagesAsync()
                }
            }
        }
        .navigationTitle(chat.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadMessagesAsync()
        }
    }
    
    private func loadMessages() {
        Task {
            await loadMessagesAsync()
        }
    }
    
    private func loadMessagesAsync() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let loadedMessages = try await service.getMessages(chatId: chat.id, limit: 50)
            await MainActor.run {
                self.messages = loadedMessages.reversed() // Переворачиваем для правильного порядка
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

struct MessageRow: View {
    let message: MaxMessage
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if let senderId = message.senderId {
                    Text("User \(senderId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(message.text)
                    .padding(12)
                    .background(Color(uiColor: .systemGray5))
                    .cornerRadius(12)
                
                if let date = message.date {
                    Text(formatDate(date))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
    }
    
    private func formatDate(_ timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        MessagesView(chat: MaxChat(
            id: 1,
            title: "Test Chat",
            type: "PRIVATE",
            photoId: nil,
            unreadCount: 0
        ))
    }
}
