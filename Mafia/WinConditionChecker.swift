//
//  WinConditionChecker.swift
//  Mafia
//
//  Created by Jack Friar on 10/23/25.
//

import Foundation
import FirebaseDatabase

final class WinConditionChecker {
    private let db: DatabaseReference
    
    init(code: String) {
        self.db = Database.database().reference().child("lobbies").child(code)
    }
    
    /// Check win conditions and end game if met
    /// Returns true if game should end
    func checkAndApplyWinCondition(completion: @escaping (Bool) -> Void) {
        db.child("players").observeSingleEvent(of: .value) { [weak self] snap in
            guard let self else {
                completion(false)
                return
            }
            
            var mafiaAlive = 0
            var townAlive = 0
            
            for case let c as DataSnapshot in snap.children {
                if let d = c.value as? [String: Any],
                   (d["alive"] as? Bool ?? true) {
                    let role = (d["role"] as? String) ?? "Civi"
                    if role == "Godfather" || role == "Recruit" {
                        mafiaAlive += 1
                    } else {
                        townAlive += 1
                    }
                }
            }
            
            if mafiaAlive == 0 {
                // Town wins
                self.db.child("meta").updateChildValues([
                    "phase": Phase.end.rawValue,
                    "winner": "Town"
                ])
                completion(true)
            } else if mafiaAlive >= townAlive {
                // Mafia wins (equal or greater numbers)
                self.db.child("meta").updateChildValues([
                    "phase": Phase.end.rawValue,
                    "winner": "Mafia"
                ])
                completion(true)
            } else {
                // Game continues
                completion(false)
            }
        }
    }
}
