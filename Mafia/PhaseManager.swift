//
//  PhaseManager.swift
//  Mafia
//
//  Created by Jack Friar on 10/12/25.
//

import Foundation
import FirebaseDatabase

final class PhaseManager {
    private let db: DatabaseReference
    private let code: String
    private let observerManager = ObserverManager()
    private var isObserving = false

    init(code: String) {
        self.code = code
        self.db = Database.database().reference().child("lobbies").child(code)
    }

    func advancePhase(from current: Phase) {
        let next: Phase = switch current {
        case .lobby: .roles
        case .roles: .night
        case .night: .dayRecap
        case .dayRecap: .block
        case .block: .vote
        case .vote: .night
        case .end: .lobby
        }
        db.child("meta").updateChildValues(["phase": next.rawValue])
    }

    /// Host-only: Start observing for phase completion
    func startObservingCompletion(for phase: Phase) {
        guard !isObserving else { return }
        isObserving = true
        
        observerManager.observe(db.child("players")) { [weak self] snapshot in
            self?.checkCompletion(for: phase, snapshot: snapshot)
        }
    }
    
    /// Stop observing (call this when leaving a phase)
    func stopObserving() {
        observerManager.removeAllObservers()
        isObserving = false
    }
    
    private func checkCompletion(for phase: Phase, snapshot: DataSnapshot) {
        var allDone = true
        var aliveCount = 0
        
        for case let child as DataSnapshot in snapshot.children {
            if let data = child.value as? [String: Any],
               (data["alive"] as? Bool ?? true) {
                aliveCount += 1
                if data["done"] as? Bool == false {
                    allDone = false
                }
            }
        }
        
        // Only advance if we have players and all are done
        guard aliveCount > 0 && allDone else { return }
        
        // Stop observing before advancing to prevent duplicate triggers
        stopObserving()
        
        advancePhase(from: phase)
        resetPlayersDone()
    }

    private func resetPlayersDone() {
        observerManager.observeSingleEvent(db.child("players")) { [weak self] snapshot in
            guard let self else { return }
            for case let child as DataSnapshot in snapshot.children {
                self.db.child("players").child(child.key).updateChildValues(["done": false])
            }
        }
    }
    
    deinit {
        stopObserving()
    }
}
