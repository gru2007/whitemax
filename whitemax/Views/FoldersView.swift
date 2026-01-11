//
//  FoldersView.swift
//  whitemax
//

import SwiftUI

private struct FolderItem: Identifiable, Hashable {
    let id: String
    var title: String
    var include: [Int]
}

struct FoldersView: View {
    @StateObject private var service = MaxClientService.shared

    @State private var folders: [FolderItem] = []
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?

    @State private var showCreate: Bool = false
    @State private var draftTitle: String = ""

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.accentColor.opacity(0.18), Color(uiColor: .systemBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .overlay { Rectangle().fill(.ultraThinMaterial).opacity(0.55) }

            Group {
                if isLoading {
                    ProgressView("Загрузка папок…")
                        .padding()
                        .liquidGlass(cornerRadius: 16)
                } else if let errorMessage {
                    ContentUnavailableView(
                        "Не удалось загрузить папки",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                    .overlay(alignment: .bottom) {
                        Button("Повторить") { Task { await load() } }
                            .buttonStyle(.borderedProminent)
                            .padding(.bottom, 24)
                    }
                    .padding()
                } else if folders.isEmpty {
                    ContentUnavailableView(
                        "Папок нет",
                        systemImage: "folder",
                        description: Text("Создайте папку для группировки чатов.")
                    )
                    .padding()
                } else {
                    List {
                        ForEach(folders) { folder in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(folder.title)
                                    .font(.headline)
                                Text("Чатов: \(folder.include.count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .onDelete(perform: delete)
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.insetGrouped)
                }
            }
        }
        .navigationTitle("Папки")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    draftTitle = ""
                    showCreate = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task { await load() }
        .sheet(isPresented: $showCreate) {
            NavigationStack {
                Form {
                    Section("Новая папка") {
                        TextField("Название", text: $draftTitle)
                    }
                    Section {
                        Button("Создать") {
                            Task { await createFolder() }
                        }
                        .disabled(draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .navigationTitle("Создать папку")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Закрыть") { showCreate = false }
                    }
                }
            }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let raw = try await service.getFolders(folderSync: 0)
            let parsed: [FolderItem] = raw.compactMap { dict in
                guard let id = dict["id"] as? String else { return nil }
                let title = dict["title"] as? String ?? ""
                let include = dict["include"] as? [Int] ?? []
                return FolderItem(id: id, title: title, include: include)
            }
            folders = parsed
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func createFolder() async {
        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        do {
            // include editing can be added later; allow empty folder
            try await service.createFolder(title: title, chatInclude: [])
            showCreate = false
            await load()
        } catch {
            // show inline via reload error for now
            showCreate = false
        }
    }

    private func delete(at offsets: IndexSet) {
        let ids = offsets.map { folders[$0].id }
        folders.remove(atOffsets: offsets)
        Task {
            for id in ids {
                try? await service.deleteFolder(folderId: id)
            }
            await load()
        }
    }
}

