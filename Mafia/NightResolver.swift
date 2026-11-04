//
//  NightResolver.swift
//  Mafia
//
//  Created by Jack Friar on 10/13/25.
//

import Foundation
import FirebaseDatabase

/// Host-only engine that resolves the night's actions into recap + eliminations,
/// then advances phase to dayRecap.
final class NightResolver {
    private let code: String
    private let db: DatabaseReference
    private let observerManager = ObserverManager()
    private var isResolving = false
    private let winChecker: WinConditionChecker

    init(code: String) {
        self.code = code
        self.db = Database.database().reference().child("lobbies").child(code)
        self.winChecker = WinConditionChecker(code: code)
    }

    func startObserving() {
        observerManager.observe(db.child("meta")) { [weak self] _ in
            self?.tryResolveIfReady()
        }
        
        observerManager.observe(db.child("players")) { [weak self] _ in
            self?.tryResolveIfReady()
        }
    }
    
    func stopObserving() {
        observerManager.removeAllObservers()
    }

    private func tryResolveIfReady() {
        guard !isResolving else { return }
        
        observerManager.observeSingleEvent(db) { [weak self] lobbySnap in
            guard let self else { return }
            
            guard let meta = lobbySnap.childSnapshot(forPath: "meta").value as? [String: Any],
                  let phase = meta["phase"] as? String,
                  phase == Phase.night.rawValue else { return }
            
            let night = (meta["night"] as? Int) ?? 1
            
            let playersSnap = lobbySnap.childSnapshot(forPath: "players")
            var allDone = true
            var aliveNames: [String] = []
            
            for case let child as DataSnapshot in playersSnap.children {
                if let data = child.value as? [String: Any] {
                    let alive = data["alive"] as? Bool ?? true
                    let done = data["done"] as? Bool ?? false
                    if alive {
                        aliveNames.append(child.key)
                        if !done { allDone = false }
                    }
                }
            }
            
            guard allDone && !aliveNames.isEmpty else { return }
            
            self.isResolving = true
            
            let actionsSnap = lobbySnap.childSnapshot(forPath: "actions/\(night)")
            var actions: [[String: Any]] = []
            for case let a as DataSnapshot in actionsSnap.children {
                if let dict = a.value as? [String: Any] {
                    actions.append(dict)
                }
            }
            
            self.resolveNight(night: night, actions: actions, playersAlive: aliveNames)
        }
    }
    
    private func resolveNight(night: Int, actions: [[String: Any]], playersAlive: [String]) {
        var kills: [String] = []
        var saves: Set<String> = []
        var silenced: Set<String> = []
        var checks: [(cop: String, target: String)] = []
        var recruits: [String] = []

        for a in actions {
            guard let role = a["role"] as? String,
                  let kind = a["kind"] as? String,
                  let target = a["target"] as? String else { continue }

            switch (role, kind) {
            case ("Godfather", ActionKind.kill):
                kills.append(target)
            case ("Godfather", ActionKind.recruit):
                recruits.append(target)
            case ("Medic", ActionKind.save):
                saves.insert(target)
            case ("Cop", ActionKind.check):
                if let actor = a["actor"] as? String {
                    checks.append((cop: actor, target: target))
                }
            case ("Vis", ActionKind.kill):
                kills.append(target)
            case ("Diddy", ActionKind.silence):
                silenced.insert(target)
            case ("Kazee", ActionKind.kill):
                kills.append(target)
                if let extra = playersAlive.filter({ $0 != target }).randomElement() {
                    kills.append(extra)
                }
            default:
                break
            }
        }

        let finalKills = Array(Set(kills)).filter { !saves.contains($0) }

        var parts: [String] = []
        if finalKills.isEmpty {
            parts.append("It was a quiet night. No one died.")
        } else {
            parts.append("The town mourns \(finalKills.joined(separator: ", ")).")
        }
        if !silenced.isEmpty {
            parts.append("Silenced for the day: \(Array(silenced).joined(separator: ", ")).")
        }

        let recapPayload: [String: Any] = [
            "summary": parts.joined(separator: " "),
            "deadPlayers": finalKills,
            "night": night,
            "ts": Date().timeIntervalSince1970
        ]
        db.child("recap").child("\(night)").setValue(recapPayload)

        for name in finalKills {
            db.child("players").child(name).updateChildValues(["alive": false])
        }
        
        for name in silenced {
            db.child("players").child(name).updateChildValues(["silenced": true])
        }

        for c in checks {
            checkPlayer(name: c.target, cop: c.cop, night: night)
        }

        for r in recruits {
            db.child("players").child(r).updateChildValues(["role": "Recruit"])
        }

        for name in playersAlive {
            db.child("players").child(name).updateChildValues(["done": false])
        }

        stopObserving()

        // CHECK WIN CONDITIONS before moving to day
        winChecker.checkAndApplyWinCondition { [weak self] gameEnded in
            guard let self else { return }
            if !gameEnded {
                // Game continues to day recap
                self.db.child("meta").updateChildValues(["phase": Phase.dayRecap.rawValue])
            }
            // If gameEnded is true, winChecker already set phase to .end
        }
    }

    private func checkPlayer(name: String, cop: String, night: Int) {
        db.child("players").child(name).observeSingleEvent(of: .value) { [weak self] snap in
            guard let self else { return }
            if let d = snap.value as? [String: Any] {
                let role = (d["role"] as? String) ?? "Civi"
                let isMafia = ["Godfather", "Recruit"].contains(role)
                
                self.db.child("intel").child(cop).child("\(night)").setValue([
                    "target": name,
                    "isMafia": isMafia,
                    "ts": Date().timeIntervalSince1970
                ])
            }
        }
    }
    
    deinit {
        stopObserving()
    }
}
