//
//  ProfileView.swift
//  whitemax
//

import SwiftUI

struct ProfileView: View {
    @StateObject private var service = MaxClientService.shared

    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var about: String = ""
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Профиль") {
                TextField("Имя", text: $firstName)
                TextField("Фамилия", text: $lastName)
                TextField("О себе", text: $about, axis: .vertical)
                    .lineLimit(3...6)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button {
                    save()
                } label: {
                    if isSaving {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else {
                        Text("Сохранить")
                    }
                }
                .disabled(isSaving || firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .navigationTitle("Профиль")
        .onAppear {
            // Pre-fill from current user where possible
            if let current = service.currentUser {
                firstName = current.firstName
            }
        }
    }

    private func save() {
        errorMessage = nil
        isSaving = true

        let fn = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let ln = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let ab = about.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            defer { Task { @MainActor in isSaving = false } }
            do {
                try await service.updateProfile(
                    firstName: fn,
                    lastName: ln.isEmpty ? nil : ln,
                    about: ab.isEmpty ? nil : ab,
                    photoPath: nil
                )
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

