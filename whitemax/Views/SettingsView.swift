//
//  SettingsView.swift
//  whitemax
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("private_mode") private var privateMode: Bool = false
    @StateObject private var service = MaxClientService.shared

    @State private var isClearing: Bool = false

    var body: some View {
        Form {
            Section("Приватность") {
                Toggle("Private Mode (не писать события на диск)", isOn: $privateMode)
                    .onChange(of: privateMode) { _, newValue in
                        if newValue {
                            service.stopEventMonitoring()
                        } else {
                            Task { try? await service.startEventMonitoring() }
                        }
                    }

                Text("В Private Mode real-time обновления могут быть ограничены, но приложение оставляет меньше локальных следов.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Организация") {
                NavigationLink("Папки") {
                    FoldersView()
                }
                NavigationLink("Вступить по ссылке") {
                    JoinByLinkView()
                }
            }

            Section("Данные") {
                Button(role: .destructive) {
                    clearLocalCache()
                } label: {
                    if isClearing {
                        Label("Очистка…", systemImage: "trash")
                    } else {
                        Label("Очистить локальный кэш", systemImage: "trash")
                    }
                }
                .disabled(isClearing)
            }

            Section("Аккаунт") {
                NavigationLink("Профиль") {
                    ProfileView()
                }
            }
        }
        .navigationTitle("Настройки")
    }

    private func clearLocalCache() {
        isClearing = true
        Task {
            defer { Task { @MainActor in isClearing = false } }

            service.stopEventMonitoring()
            // Best-effort: remove events dir in Documents/max_cache/events
            let fm = FileManager.default
            let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first
            let events = docs?.appendingPathComponent("max_cache/events", isDirectory: true)
            if let events {
                try? fm.removeItem(at: events)
            }
        }
    }
}

