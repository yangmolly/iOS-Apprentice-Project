//
//  SupabaseConfig.swift
//  iOSApprenticeProject
//
//  Values come from Services/Secrets.swift, which is gitignored.
//  Template: Secrets.swift.example at the repo root.
//

import Foundation

enum SupabaseConfig {
    static let url = URL(string: Secrets.supabaseURL)!
    static let anonKey = Secrets.supabaseAnonKey
}
