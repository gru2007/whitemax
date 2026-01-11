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

    // Extended messenger state (decoded from wrapper events / API if present)
    let reactions: [String: Int]?
    let isPinned: Bool
    let replyTo: String?
    let attachments: [MaxAttachment]?
    let isEdited: Bool

    init(
        id: String,
        chatId: Int,
        text: String,
        senderId: Int? = nil,
        date: Int? = nil,
        type: String? = nil,
        reactions: [String: Int]? = nil,
        isPinned: Bool = false,
        replyTo: String? = nil,
        attachments: [MaxAttachment]? = nil,
        isEdited: Bool = false
    ) {
        self.id = id
        self.chatId = chatId
        self.text = text
        self.senderId = senderId
        self.date = date
        self.type = type
        self.reactions = reactions
        self.isPinned = isPinned
        self.replyTo = replyTo
        self.attachments = attachments
        self.isEdited = isEdited
    }

    enum CodingKeys: String, CodingKey {
        case id
        case chatId
        case text
        case senderId
        case date
        case type
        case reactions
        case isPinned
        case replyTo
        case attachments
        case isEdited
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        chatId = try c.decode(Int.self, forKey: .chatId)
        text = (try? c.decode(String.self, forKey: .text)) ?? ""
        senderId = try c.decodeIfPresent(Int.self, forKey: .senderId)
        date = try c.decodeIfPresent(Int.self, forKey: .date)
        type = try c.decodeIfPresent(String.self, forKey: .type)
        reactions = try c.decodeIfPresent([String: Int].self, forKey: .reactions)
        isPinned = (try? c.decode(Bool.self, forKey: .isPinned)) ?? false
        replyTo = try c.decodeIfPresent(String.self, forKey: .replyTo)
        attachments = try c.decodeIfPresent([MaxAttachment].self, forKey: .attachments)
        isEdited = (try? c.decode(Bool.self, forKey: .isEdited)) ?? false
    }
}
