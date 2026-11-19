//
//  SyncFailure.swift
//  iOSApprenticeProject
//
//  Decides what a failed write means: retry later, give up, or treat as done.
//

import Foundation
import Supabase

enum SyncFailure: Equatable {
    /// Network trouble or a server hiccup: keep it queued and retry.
    case transient
    /// The server rejected it and always will (duplicate spot, RLS, bad data): drop it and tell the user.
    case permanent(message: String)
    /// The write already happened, such as a retry after a timeout that actually succeeded.
    case alreadyApplied

    /// Classifies from the pieces of a PostgREST error so it can be unit-tested without the SDK.
    static func classify(code: String?, message: String, isNetworkError: Bool) -> SyncFailure {
        if isNetworkError { return .transient }
        switch code {
        case "23505":
            // Unique violation. On the primary key (or the review/RSVP/saved keys),
            // the row is already there. On any other key, such as a spot name, it is a real conflict.
            let idempotentKeys = ["_pkey", "reviews_user_spot_key"]
            if idempotentKeys.contains(where: { message.contains($0) }) { return .alreadyApplied }
            return .permanent(message: "That already exists.")
        case "P0001":
            if message.hasPrefix("duplicate_spot:") {
                let detail = message.dropFirst("duplicate_spot:".count).trimmingCharacters(in: .whitespaces)
                return .permanent(message: "A similar spot already exists: \(detail).")
            }
            return .permanent(message: message)
        case "42501":
            return .permanent(message: "You don't have permission to do that.")
        case let c? where c.hasPrefix("22") || c.hasPrefix("23"):
            // Data exceptions and other integrity violations won't succeed on retry.
            return .permanent(message: message)
        default:
            return .transient
        }
    }

    static func classify(_ error: Error) -> SyncFailure {
        if let pg = error as? PostgrestError {
            return classify(code: pg.code, message: pg.message, isNetworkError: false)
        }
        if error is URLError {
            return .transient
        }
        let ns = error as NSError
        return classify(code: nil, message: ns.localizedDescription,
                        isNetworkError: ns.domain == NSURLErrorDomain)
    }
}
