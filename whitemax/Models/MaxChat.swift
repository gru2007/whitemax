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
    let photoId: Int?
    let unreadCount: Int
}
