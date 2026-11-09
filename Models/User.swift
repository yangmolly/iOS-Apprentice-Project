//
//  User.swift
//  iOSApprenticeProject
//
//  Created by Sarayu Pesala on 10/11/26.
//

import Foundation

/// A row in the `profiles` table (one per signed-up user).
struct UserProfile: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var email: String
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, email
        case createdAt = "created_at"
    }
}
