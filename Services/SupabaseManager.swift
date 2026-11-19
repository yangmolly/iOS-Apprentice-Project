//
//  SupabaseManager.swift
//  iOSApprenticeProject
//

import Foundation
import Supabase

/// One shared client for the whole app.
/// The auth session is persisted in the Keychain. The locally stored session is
/// emitted immediately on launch, so a returning user stays signed in while offline.
let supabase = SupabaseClient(
    supabaseURL: SupabaseConfig.url,
    supabaseKey: SupabaseConfig.anonKey,
    options: SupabaseClientOptions(
        auth: .init(
            storage: KeychainLocalStorage(),
            emitLocalSessionAsInitialSession: true
        )
    )
)
