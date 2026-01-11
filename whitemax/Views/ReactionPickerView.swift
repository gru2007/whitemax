//
//  ReactionPickerView.swift
//  whitemax
//

import SwiftUI

struct ReactionPickerView: View {
    let reactions: [String]
    var onSelect: (String) -> Void

    init(
        reactions: [String] = ["👍", "❤️", "😂", "😮", "😢", "😡"],
        onSelect: @escaping (String) -> Void
    ) {
        self.reactions = reactions
        self.onSelect = onSelect
    }

    var body: some View {
        HStack(spacing: 10) {
            ForEach(reactions, id: \.self) { r in
                Button {
                    onSelect(r)
                } label: {
                    Text(r)
                        .font(.title3)
                        .frame(width: 36, height: 32)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        }
    }
}

