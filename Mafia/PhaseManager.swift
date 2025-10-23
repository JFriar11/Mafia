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
        case .vote: .night   // TODO: switch to .end if win conditions met
        case .end: .lobby
        }
        db.child("meta").updateChildValues(["phase": next.rawValue])
    }

    /// Host-only: when all players' `done == true`, advance the phase and reset flags.
    func observeCompletion(for phase: Phase) {
        db.child("players").observe(.value) { snapshot in
            var allDone = true
            for case let child as DataSnapshot in snapshot.children {
                if let data = child.value as? [String: Any],
                   (data["alive"] as? Bool ?? true),
                   (data["done"] as? Bool == false) {
                    allDone = false
                }
            }
            if allDone {
                self.advancePhase(from: phase)
                self.resetPlayersDone()
            }
        }
    }

    private func resetPlayersDone() {
        db.child("players").observeSingleEvent(of: .value) { snapshot in
            for case let child as DataSnapshot in snapshot.children {
                self.db.child("players").child(child.key).updateChildValues(["done": false])
            }
        }
    }
}

