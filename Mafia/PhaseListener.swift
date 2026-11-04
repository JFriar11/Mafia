//
//  PhaseListener.swift
//  Mafia
//
//  Created by Jack Friar on 10/12/25.
//

import Foundation
import FirebaseDatabase
import Combine

class PhaseListener: ObservableObject {
    @Published var phase: String = Phase.lobby.rawValue
    private let observerManager = ObserverManager()
    private let dbRef: DatabaseReference

    init(code: String) {
        dbRef = Database.database().reference()
            .child("lobbies")
            .child(code)
            .child("meta/phase")
        
        observerManager.observe(dbRef) { [weak self] snapshot in
            if let newPhase = snapshot.value as? String {
                DispatchQueue.main.async {
                    self?.phase = newPhase
                }
            }
        }
    }
    
    deinit {
        observerManager.removeAllObservers()
    }
}
