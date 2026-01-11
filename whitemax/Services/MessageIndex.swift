//
//  MessageIndex.swift
//  whitemax
//

import Foundation
import Combine

struct MessageSearchHit: Identifiable, Hashable {
    var id: String { "\(chatId):\(messageId)" }

    let chatId: Int
    let messageId: String
    let messageText: String
    let timestamp: Int?
}

@MainActor
final class MessageIndex: ObservableObject {
    // chatId -> messageId -> message
    private var store: [Int: [String: MaxMessage]] = [:]

    // Soft limits to keep memory under control
    private let maxMessagesPerChat = 500

    func upsert(chatId: Int, messages: [MaxMessage]) {
        guard !messages.isEmpty else { return }

        var chatMap = store[chatId] ?? [:]
        for m in messages {
            chatMap[m.id] = m
        }

        // trim oldest
        if chatMap.count > maxMessagesPerChat {
            let sorted = chatMap.values.sorted { (a, b) in
                (a.date ?? 0) < (b.date ?? 0)
            }
            let keep = sorted.suffix(maxMessagesPerChat)
            var trimmed: [String: MaxMessage] = [:]
            trimmed.reserveCapacity(keep.count)
            for m in keep { trimmed[m.id] = m }
            chatMap = trimmed
        }

        store[chatId] = chatMap
        objectWillChange.send()
    }

    func delete(chatId: Int, messageIds: [String]) {
        guard var chatMap = store[chatId], !messageIds.isEmpty else { return }
        for id in messageIds { chatMap.removeValue(forKey: id) }
        store[chatId] = chatMap
        objectWillChange.send()
    }

    func search(_ query: String) -> [MessageSearchHit] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        let needle = q.lowercased()

        var hits: [MessageSearchHit] = []
        for (chatId, messagesById) in store {
            for msg in messagesById.values {
                let text = msg.text
                if text.lowercased().contains(needle) {
                    hits.append(
                        MessageSearchHit(
                            chatId: chatId,
                            messageId: msg.id,
                            messageText: text,
                            timestamp: msg.date
                        )
                    )
                }
            }
        }

        hits.sort { ($0.timestamp ?? 0) > ($1.timestamp ?? 0) }
        return hits
    }

    func indexedChatsCount() -> Int { store.count }
    func indexedMessagesCount() -> Int { store.values.reduce(0) { $0 + $1.count } }
}

