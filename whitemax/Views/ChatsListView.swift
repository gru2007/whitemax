//
//  ChatsListView.swift
//  whitemax
//
//  Список чатов
//

import SwiftUI

struct ChatsListView: View {
    @StateObject private var service = MaxClientService.shared
    @State private var chats: [MaxChat] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Загрузка чатов...")
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Text("Ошибка загрузки")
                            .font(.headline)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button("Повторить") {
                            loadChats()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if chats.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "message")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("Нет чатов")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List(chats) { chat in
                        NavigationLink(destination: MessagesView(chat: chat)) {
                            ChatRow(chat: chat)
                        }
                    }
                    .refreshable {
                        await loadChatsAsync()
                    }
                }
            }
            .navigationTitle("Чаты")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Выйти") {
                        logout()
                    }
                }
            }
        }
        .task {
            await loadChatsAsync()
        }
    }
    
    private func loadChats() {
        Task {
            await loadChatsAsync()
        }
    }
    
    private func loadChatsAsync() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let loadedChats = try await service.getChats()
            await MainActor.run {
                self.chats = loadedChats
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func logout() {
        Task {
            do {
                try await service.logout()
                // Навигация обратно к экрану входа будет обработана через AppState
            } catch {
                print("Logout error: \(error)")
            }
        }
    }
}

struct ChatRow: View {
    let chat: MaxChat
    
    var body: some View {
        HStack {
            // Иконка чата
            Circle()
                .fill(Color.accentColor)
                .frame(width: 50, height: 50)
                .overlay {
                    Text(String(chat.title.prefix(1)))
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(chat.title)
                    .font(.headline)
                
                Text(chat.type)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if chat.unreadCount > 0 {
                Text("\(chat.unreadCount)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.red)
                    .clipShape(Circle())
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ChatsListView()
}
