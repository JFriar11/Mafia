//
//  Extensions.swift
//  Mafia
//
//  Created by Jack Friar on 10/11/25.
//

import SwiftUI

extension Dictionary where Key == String, Value == Any {
    func str(_ key: String) -> String? { self[key] as? String }
    func bool(_ key: String) -> Bool { self[key] as? Bool ?? false }
    func int(_ key: String) -> Int { self[key] as? Int ?? 0 }
}

extension View {
    func eraseToAnyView() -> AnyView { AnyView(self) }
}

func replaceRootView<T: View>(_ view: T) {
    guard let window = UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene })
        .first?.windows.first else { return }
    window.rootViewController = UIHostingController(rootView: view)
    window.makeKeyAndVisible()
}

