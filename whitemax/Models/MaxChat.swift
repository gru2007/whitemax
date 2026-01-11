//
//  MaxChat.swift
//  whitemax
//
//  Модель чата Max.RU
//

import Foundation

struct MaxChat: Identifiable, Codable {
    let id: Int
    let title: String
    let type: String
    let photoId: Int?  // Для диалогов из User, для чатов/каналов может быть nil
    let iconUrl: String?  // Для чатов и каналов из base_icon_url
    let unreadCount: Int

    // Extended metadata for richer UI
    let lastMessage: MaxMessage?
    /// Unix timestamp in ms (to match Python wrapper output)
    let lastMessageTime: Int?

    init(
        id: Int,
        title: String,
        type: String,
        photoId: Int? = nil,
        iconUrl: String? = nil,
        unreadCount: Int = 0,
        lastMessage: MaxMessage? = nil,
        lastMessageTime: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.photoId = photoId
        self.iconUrl = iconUrl
        self.unreadCount = unreadCount
        self.lastMessage = lastMessage
        self.lastMessageTime = lastMessageTime
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case type
        case photoId
        case iconUrl
        case unreadCount
        case lastMessage
        case lastMessageTime
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        type = (try? c.decode(String.self, forKey: .type)) ?? "unknown"
        photoId = try c.decodeIfPresent(Int.self, forKey: .photoId)
        iconUrl = try c.decodeIfPresent(String.self, forKey: .iconUrl)
        unreadCount = (try? c.decode(Int.self, forKey: .unreadCount)) ?? 0
        lastMessage = try c.decodeIfPresent(MaxMessage.self, forKey: .lastMessage)
        lastMessageTime = try c.decodeIfPresent(Int.self, forKey: .lastMessageTime)
    }
}
