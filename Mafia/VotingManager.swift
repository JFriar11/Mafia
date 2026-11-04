//
//  VotingManager.swift
//  Mafia
//
//  Created by Jack Friar on 10/23/25.
//

import Foundation
import FirebaseDatabase

final class VotingManager {
    private let db: DatabaseReference
    private let code: String
    private let observerManager = ObserverManager()
    private let winChecker: WinConditionChecker
    private var votingState: VotingState = .collectingVotes
    
    enum VotingState {
        case collectingVotes
        case awaitingJudge
        case finalized
    }
    
    init(code: String) {
        self.code = code
        self.db = Database.database().reference().child("lobbies").child(code)
        self.winChecker = WinConditionChecker(code: code)
    }
    
    func startObserving() {
        observerManager.observe(db.child("players")) { [weak self] _ in
            self?.checkVotingProgress()
        }
        
        observerManager.observe(db.child("meta/judgeDecision")) { [weak self] _ in
            self?.checkVotingProgress()
        }
    }
    
    func stopObserving() {
        observerManager.removeAllObservers()
    }
    
    private func checkVotingProgress() {
        observerManager.observeSingleEvent(db.child("meta")) { [weak self] metaSnap in
            guard let self else { return }
            guard let meta = metaSnap.value as? [String: Any] else { return }
            
            // If already has pending elimination, check for finalization
            if let pending = meta["pendingElimination"] as? String {
                self.checkForFinalization(pending: pending, meta: meta)
            } else {
                // Check if ready to tally
                self.checkForTally()
            }
        }
    }
    
    private func checkForTally() {
        guard votingState == .collectingVotes else { return }
        
        db.child("players").observeSingleEvent(of: .value) { [weak self] snap in
            guard let self else { return }
            
            var allDone = true
            var aliveNames: [String] = []
            
            for case let c as DataSnapshot in snap.children {
                if let d = c.value as? [String: Any],
                   (d["alive"] as? Bool ?? true) {
                    aliveNames.append(c.key)
                    if d["done"] as? Bool == false {
                        allDone = false
                    }
                }
            }
            
            guard allDone && !aliveNames.isEmpty else { return }
            
            self.votingState = .awaitingJudge
            self.tallyVotes()
        }
    }
    
    private func tallyVotes() {
        db.child("meta/night").observeSingleEvent(of: .value) { [weak self] nightSnap in
            guard let self else { return }
            let night = (nightSnap.value as? Int) ?? 1
            
            self.db.child("meta/voteNominees").observeSingleEvent(of: .value) { nomSnap in
                let nominees = (nomSnap.value as? [String]) ?? []
                
                self.db.child("votes").child("\(night)").observeSingleEvent(of: .value) { vSnap in
                    var counts: [String: Int] = [:]
                    for n in nominees { counts[n] = 0 }
                    
                    for case let c as DataSnapshot in vSnap.children {
                        if let d = c.value as? [String: Any],
                           let t = d["target"] as? String,
                           nominees.contains(t) {
                            counts[t, default: 0] += 1
                        }
                    }
                    
                    let maxVotes = counts.values.max() ?? 0
                    let top = counts.filter { $0.value == maxVotes }.map { $0.key }
                    let eliminated = top.randomElement() ?? nominees.first ?? ""
                    
                    self.db.child("meta").updateChildValues([
                        "pendingElimination": eliminated
                    ])
                    
                    // Check if judge is available
                    self.checkJudgeAvailability { judgeAvailable in
                        if judgeAvailable {
                            self.db.child("meta").updateChildValues([
                                "judgeWindowOpen": true,
                                "judgeDecision": ""
                            ])
                        } else {
                            self.db.child("meta").updateChildValues([
                                "judgeWindowOpen": false
                            ])
                        }
                        
                        // Reset done for judge decision phase
                        self.db.child("players").observeSingleEvent(of: .value) { p in
                            for case let c as DataSnapshot in p.children {
                                if let d = c.value as? [String: Any],
                                   (d["alive"] as? Bool ?? true) {
                                    self.db.child("players").child(c.key).updateChildValues(["done": false])
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func checkJudgeAvailability(completion: @escaping (Bool) -> Void) {
        db.child("players").observeSingleEvent(of: .value) { [weak self] snap in
            guard let self else {
                completion(false)
                return
            }
            
            var judgeAlive = false
            for case let c as DataSnapshot in snap.children {
                if let d = c.value as? [String: Any],
                   (d["role"] as? String) == "Judge",
                   (d["alive"] as? Bool ?? true) {
                    judgeAlive = true
                    break
                }
            }
            
            if !judgeAlive {
                completion(false)
                return
            }
            
            self.db.child("meta/judgeUsed").observeSingleEvent(of: .value) { used in
                let isUsed = (used.value as? Bool) ?? false
                completion(!isUsed)
            }
        }
    }
    
    private func checkForFinalization(pending: String, meta: [String: Any]) {
        guard votingState == .awaitingJudge else { return }
        
        let judgeWindowOpen = meta["judgeWindowOpen"] as? Bool ?? false
        let judgeDecision = meta["judgeDecision"] as? String ?? ""
        
        // If judge window is open and no decision yet, wait
        if judgeWindowOpen && judgeDecision.isEmpty {
            return
        }
        
        // Check if all players are done (or judge made override)
        db.child("players").observeSingleEvent(of: .value) { [weak self] snap in
            guard let self else { return }
            
            var allDone = true
            for case let c as DataSnapshot in snap.children {
                if let d = c.value as? [String: Any],
                   (d["alive"] as? Bool ?? true),
                   (d["done"] as? Bool == false) {
                    allDone = false
                }
            }
            
            guard allDone || judgeDecision == "override" else { return }
            
            self.votingState = .finalized
            self.finalizeVote(eliminated: pending, judgeDecision: judgeDecision)
        }
    }
    
    private func finalizeVote(eliminated: String, judgeDecision: String) {
        db.child("meta/night").observeSingleEvent(of: .value) { [weak self] nightSnap in
            guard let self else { return }
            let night = (nightSnap.value as? Int) ?? 1
            
            if judgeDecision == "override" {
                // Judge saves the person
                self.db.child("players").child(eliminated).updateChildValues(["alive": true])
                
                self.db.child("meta").updateChildValues([
                    "judgeUsed": true,
                    "judgeWindowOpen": false,
                    "judgeDecision": "",
                    "pendingElimination": NSNull()
                ])
                
                self.db.child("recap").child("\(night)").updateChildValues([
                    "judgeOverride": true,
                    "judgeOverrideTarget": eliminated
                ])
                
                self.stopObserving()
                self.advanceToNextPhase(currentNight: night)
            } else {
                // Normal elimination
                self.db.child("players").child(eliminated).updateChildValues(["alive": false])
                
                self.db.child("recap").child("\(night)").updateChildValues([
                    "dayEliminated": eliminated
                ])
                
                self.db.child("meta").updateChildValues([
                    "judgeWindowOpen": false,
                    "judgeDecision": "",
                    "pendingElimination": NSNull()
                ])
                
                self.stopObserving()
                self.advanceToNextPhase(currentNight: night)
            }
        }
    }
    
    private func advanceToNextPhase(currentNight night: Int) {
        // Check win conditions
        winChecker.checkAndApplyWinCondition { [weak self] gameEnded in
            guard let self else { return }
            
            if !gameEnded {
                // Continue to next night
                self.db.child("meta").updateChildValues([
                    "phase": Phase.night.rawValue,
                    "night": night + 1,
                    "voteNominees": []
                ])
                
                // Reset flags for next night
                self.db.child("players").observeSingleEvent(of: .value) { p in
                    for case let c as DataSnapshot in p.children {
                        self.db.child("players").child(c.key).updateChildValues([
                            "done": false,
                            "silenced": false
                        ])
                    }
                }
            }
            // If gameEnded, winChecker already set phase to .end
        }
    }
    
    deinit {
        stopObserving()
    }
}
