//
//  SupabaseManager.swift
//  iOSApprenticeProject
//

import Foundation
import Supabase

/// One shared client for the whole app.
let supabase = SupabaseClient(
    supabaseURL: SupabaseConfig.url,
    supabaseKey: SupabaseConfig.anonKey
)
