//
//  JoinByLinkView.swift
//  whitemax
//

import SwiftUI

struct JoinByLinkView: View {
    @StateObject private var service = MaxClientService.shared

    @State private var link: String = ""
    @State private var mode: Mode = .auto
    @State private var isWorking: Bool = false
    @State private var errorMessage: String?

    @State private var joinedChat: MaxChat?

    enum Mode: String, CaseIterable, Identifiable {
        case auto = "Авто"
        case group = "Группа"
        case channel = "Канал"
        var id: String { rawValue }
    }

    var body: some View {
        Form {
            Section("Ссылка") {
                TextField("Вставьте ссылку", text: $link, axis: .vertical)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)

                Picker("Тип", selection: $mode) {
                    ForEach(Mode.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)

                Button {
                    join()
                } label: {
                    if isWorking {
                        HStack { Spacer(); ProgressView(); Spacer() }
                    } else {
                        Label("Вступить", systemImage: "link")
                    }
                }
                .disabled(isWorking || link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            if let joinedChat {
                Section("Результат") {
                    NavigationLink(destination: MessagesView(chat: joinedChat)) {
                        Label(joinedChat.title, systemImage: joinedChat.type.uppercased() == "CHANNEL" ? "megaphone" : "person.2")
                    }
                }
            }
        }
        .navigationTitle("Вступить по ссылке")
    }

    private func join() {
        errorMessage = nil
        joinedChat = nil
        isWorking = true

        let raw = link.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveMode = resolveMode(raw)

        Task {
            defer { Task { @MainActor in isWorking = false } }
            do {
                let chat: MaxChat
                switch effectiveMode {
                case .channel:
                    chat = try await service.joinChannel(link: raw)
                case .group:
                    chat = try await service.joinGroup(link: raw)
                case .auto:
                    // not used
                    chat = try await service.joinGroup(link: raw)
                }
                await MainActor.run { joinedChat = chat }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }

    private func resolveMode(_ raw: String) -> Mode {
        switch mode {
        case .group, .channel:
            return mode
        case .auto:
            // pymax join_group expects "join/" style; channels are often "https://max.ru/<name>".
            if raw.contains("join/") {
                return .group
            }
            return .channel
        }
    }
}

