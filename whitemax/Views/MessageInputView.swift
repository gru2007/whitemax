//
//  MessageInputView.swift
//  whitemax
//

import SwiftUI

struct MessageInputView: View {
    @Binding var text: String
    var isSending: Bool
    var onAttach: (() -> Void)?
    var onSend: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            if let onAttach {
                Button(action: onAttach) {
                    Image(systemName: "paperclip")
                        .font(.system(size: 20, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                }
                .disabled(isSending)
            }

            TextField("Сообщение", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .liquidGlass(cornerRadius: 18, material: .thinMaterial)

            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .symbolRenderingMode(.hierarchical)
            }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
        }
    }
}

