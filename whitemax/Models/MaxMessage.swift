//
//  MaxMessage.swift
//  whitemax
//
//  Модель сообщения Max.RU
//

import Foundation

struct MaxMessage: Identifiable, Codable {
    let id: String
    let chatId: Int
    let text: String
    let senderId: Int?
    let date: Int?
    let type: String?
}
