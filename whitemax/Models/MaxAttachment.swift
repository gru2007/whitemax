//
//  MaxAttachment.swift
//  whitemax
//
//  Attachment model for messages (photo/file/video).
//

import Foundation

struct MaxAttachment: Identifiable, Codable, Hashable {
    let id: Int
    let type: String
    let url: String?
    let thumbnailUrl: String?
    let fileName: String?
    let fileSize: Int?
}

