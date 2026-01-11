//
//  GlobalSearchView.swift
//  whitemax
//

import SwiftUI

struct GlobalSearchView: View {
    @StateObject private var service = MaxClientService.shared
    @AppStorage("private_mode") private var privateMode: Bool = false

    @State private var query: String = ""
    @State private var isSearching: Bool = false
    @State private var errorMessage: String?

    @State private var userResult: MaxUser?
    @State private var channelResult: MaxChat?

    var body: some View {
        Form {
            Section("Запрос") {
                TextField("+7999… или @channel", text: $query)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)

                Button {
                    search()
                } label: {
                    if isSearching {
                        HStack { Spacer(); ProgressView(); Spacer() }
                    } else {
                        Label("Искать", systemImage: "magnifyingglass")
                    }
                }
                .disabled(isSearching || query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if privateMode {
                    Text("Private Mode: поиск делается только по явному нажатию «Искать».")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            if let userResult {
                Section("Пользователь") {
                    HStack {
                        Image(systemName: "person.crop.circle")
                            .imageScale(.large)
                        Text(userResult.firstName)
                        Spacer()
                        Text("#\(userResult.id)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let channelResult {
                Section("Канал") {
                    NavigationLink(destination: MessagesView(chat: channelResult)) {
                        HStack {
                            Image(systemName: "megaphone")
                                .imageScale(.large)
                            Text(channelResult.title)
                            Spacer()
                            Text("#\(channelResult.id)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Поиск")
        .onChange(of: query) { _, newValue in
            guard !privateMode else { return }
            // In non-private mode we can be more responsive: small debounce would be nicer,
            // but keep it simple for now: only auto-search when query looks complete.
            let q = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if q.hasPrefix("+") && q.count >= 7 {
                search()
            } else if q.hasPrefix("@") && q.count >= 3 {
                search()
            }
        }
    }

    private func search() {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }

        isSearching = true
        errorMessage = nil
        userResult = nil
        channelResult = nil

        Task {
            defer { Task { @MainActor in isSearching = false } }
            do {
                if q.hasPrefix("+") {
                    let user = try await service.searchUserByPhone(q)
                    await MainActor.run { userResult = user }
                } else if q.hasPrefix("@") {
                    let ch = try await service.resolveChannelByName(q)
                    await MainActor.run { channelResult = ch }
                } else {
                    // fallback: try channel name
                    let ch = try await service.resolveChannelByName(q)
                    await MainActor.run { channelResult = ch }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

