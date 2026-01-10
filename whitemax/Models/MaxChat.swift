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
}
