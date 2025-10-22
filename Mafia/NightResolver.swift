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

    init(code: String) {
        self.code = code
        self.db = Database.database().reference().child("lobbies").child(code)
    }

    /// Call on host when entering Night. It watches for all players done, resolves,
    /// writes /recap/{night} and switches phase → dayRecap.
    func observeAndResolveNight() {
        // Observe players/done and meta/phase together
        db.child("players").observe(.value) { [weak self] _ in self?.tryResolveIfReady() }
        db.child("meta").observe(.value) { [weak self] _ in self?.tryResolveIfReady() }
    }

    private func tryResolveIfReady() {
        db.child("meta").observeSingleEvent(of: .value) { [weak self] metaSnap in
            guard let self else { return }
            guard var meta = metaSnap.value as? [String: Any] else { return }
            let phase = (meta["phase"] as? String) ?? Phase.lobby.rawValue
            guard phase == Phase.night.rawValue else { return }

            let night = (meta["night"] as? Int) ?? 1

            // Check all alive players are done
            self.db.child("players").observeSingleEvent(of: .value) { playersSnap in
                var allDone = true
                var aliveNames: [String] = []
                for case let child as DataSnapshot in playersSnap.children {
                    if let data = child.value as? [String: Any] {
                        let alive = data["alive"] as? Bool ?? true
                        let done  = data["done"] as? Bool ?? false
                        if alive { aliveNames.append(child.key) }
                        if alive && !done { allDone = false }
                    }
                }
                guard allDone else { return }

                // Pull actions for this night
                self.db.child("actions").child("\(night)").observeSingleEvent(of: .value) { actsSnap in
                    var actions: [[String: Any]] = []
                    for case let a as DataSnapshot in actsSnap.children {
                        if let dict = a.value as? [String: Any] { actions.append(dict) }
                    }

                    // Resolve outcomes
                    let outcome = self.resolve(night: night, actions: actions, playersAlive: aliveNames)

                    // Write recap + apply eliminations/silence flags
                    var recapPayload: [String: Any] = [
                        "summary": outcome.summary,
                        "deadPlayers": outcome.dead,
                        "night": night,
                        "ts": Date().timeIntervalSince1970
                    ]
                    if !outcome.cleans.isEmpty { recapPayload["cleans"] = outcome.cleans }
                    if !outcome.frames.isEmpty { recapPayload["frames"] = outcome.frames }

                    self.db.child("recap").child("\(night)").setValue(recapPayload)

                    // Apply state changes
                    self.applyEliminations(outcome.dead)
                    self.applySilences(outcome.silenced)

                    // Clear players.done for next phase
                    self.resetPlayersDone()

                    // Move to Day Recap
                    self.db.child("meta").updateChildValues(["phase": Phase.dayRecap.rawValue])
                }
            }
        }
    }

    // Core resolution logic — simplified, deterministic tie-breaking.
    private func resolve(night: Int, actions: [[String: Any]], playersAlive: [String]) -> (dead: [String], silenced: [String], summary: String, frames: [String], cleans: [String]) {
        var kills: [String] = []
        var saves: Set<String> = []
        var silenced: Set<String> = []
        var checks: [(cop: String, target: String)] = []
        var recruits: [String] = []
        var frames: [String] = []
        var cleans: [String] = []

        // Parse
        for a in actions {
            guard let role = a["role"] as? String,
                  let kind = a["kind"] as? String,
                  let target = a["target"] as? String else { continue }

            switch (role, kind) {
            case ("Godfather", ActionKind.kill):
                kills.append(target)
            case ("Godfather", ActionKind.recruit):
                // Recruit: mark to mafia in resolution (doesn't kill)
                recruits.append(target)
            case ("Medic", ActionKind.save):
                saves.insert(target)
            case ("Cop", ActionKind.check):
                if let actor = a["actor"] as? String { checks.append((cop: actor, target: target)) }
            case ("Vis", ActionKind.kill):
                kills.append(target)
            case ("Diddy", ActionKind.silence):
                silenced.insert(target)
            case ("Kazee", ActionKind.kill):
                // Kazee kills target and one collateral (the first different alive)
                kills.append(target)
                if let extra = playersAlive.first(where: { $0 != target }) {
                    kills.append(extra)
                }
            default:
                break
            }
        }

        // Apply Medic saves (remove from kills)
        let finalKills = kills.filter { !saves.contains($0) }

        // Build summary text
        var parts: [String] = []
        if finalKills.isEmpty {
            parts.append("It was a quiet night. No one died.")
        } else {
            parts.append("The town mourns \(finalKills.joined(separator: ", ")).")
        }
        if !silenced.isEmpty {
            parts.append("Silenced for the day: \(Array(silenced).joined(separator: ", ")).")
        }

        // Record Cop intel privately (per-cop)
        for c in checks {
            let isMafia = self.isMafia(name: c.target)
            self.db.child("intel").child(c.cop).child("\(night)").setValue([
                "target": c.target,
                "isMafia": isMafia,
                "ts": Date().timeIntervalSince1970
            ])
        }

        // Apply recruits: mark role to "Recruit" -> becomes mafia aligned next day
        for r in recruits {
            self.db.child("players").child(r).observeSingleEvent(of: .value) { snap in
                if var d = snap.value as? [String: Any] {
                    // If already mafia, ignore; else convert alignment by setting role if civilian/townie
                    let currentRole = (d["role"] as? String) ?? "Civi"
                    if currentRole == "Civi" || currentRole == "Vis" || currentRole == "Diddy" || currentRole == "Judge" || currentRole == "Medic" || currentRole == "Cop" {
                        self.db.child("players").child(r).updateChildValues(["role": "Recruit"])
                    }
                }
            }
        }

        return (dead: Array(Set(finalKills)),
                silenced: Array(silenced),
                summary: parts.joined(separator: " "),
                frames: frames,
                cleans: cleans)
    }

    private func applyEliminations(_ names: [String]) {
        for n in names {
            db.child("players").child(n).updateChildValues(["alive": false])
        }
    }

    private func applySilences(_ names: [String]) {
        for n in names {
            db.child("players").child(n).updateChildValues(["silenced": true])
        }
    }

    private func resetPlayersDone() {
        db.child("players").observeSingleEvent(of: .value) { snap in
            for case let c as DataSnapshot in snap.children {
                self.db.child("players").child(c.key).updateChildValues(["done": false])
            }
        }
    }

    // Alignment helper — uses role string at time of check.
    private func isMafia(name: String) -> Bool {
        var mafia = false
        let sem = DispatchSemaphore(value: 0)
        db.child("players").child(name).observeSingleEvent(of: .value) { s in
            if let d = s.value as? [String: Any] {
                let role = (d["role"] as? String) ?? "Civi"
                mafia = ["Godfather", "Recruit"].contains(role)
            }
            sem.signal()
        }
        _ = sem.wait(timeout: .now() + 1.0)
        return mafia
    }
}
