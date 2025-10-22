//
//  VotingView.swift
//  Mafia
//
//  Created by Jack Friar on 10/12/25.
//


import SwiftUI
import FirebaseDatabase

struct VotingView: View {
    let code: String
    let playerName: String
    let isHost: Bool

    @EnvironmentObject var phaseListener: PhaseListener
    @State private var nominees: [String] = []
    @State private var vote: String?
    @State private var pendingElimination: String?
    @State private var judgeName: String?
    @State private var judgeUsed = false
    @State private var judgeAlive = false
    @State private var judgeWindowOpen = false
    @State private var iAmJudge = false
    @State private var showNext = false

    private var db: DatabaseReference {
        Database.database().reference().child("lobbies").child(code)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("🗳️ Voting Phase").font(.largeTitle)

            if let pending = pendingElimination {
                // Show result and (if judge) an override button
                Text("Result: \(pending) would be eliminated.")
                    .font(.headline)
                if iAmJudge && !judgeUsed && judgeAlive && judgeWindowOpen {
                    Button("Use Judge Override (once)") {
                        useJudgeOverride()
                    }
                    .buttonStyle(.borderedProminent)
                }
                Button("Continue") {
                    // Everyone presses Continue; host finalizes or advances
                    db.child("players").child(playerName).updateChildValues(["done": true])
                }
                .buttonStyle(.bordered)
            } else {
                // Standard voting UI
                if nominees.isEmpty {
                    ProgressView("Loading nominees…")
                } else {
                    ForEach(nominees, id: \.self) { n in
                        Button {
                            vote = n
                        } label: {
                            HStack {
                                Text(n).font(.title3)
                                Spacer()
                                if vote == n { Image(systemName: "checkmark.circle.fill") }
                            }
                            .padding()
                            .background(Color.gray.opacity(0.12))
                            .cornerRadius(10)
                        }
                    }

                    Button("Submit Vote") {
                        submitVote()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(vote == nil)
                }
            }

            NavigationLink("", isActive: $showNext) {
                if phaseListener.phase == Phase.night.rawValue {
                    NightView(code: code, playerName: playerName, isHost: isHost)
                        .environmentObject(phaseListener)
                } else {
                    EndView(code: code, playerName: playerName)
                        .environmentObject(phaseListener)
                }
            }
        }
        .padding()
        .onAppear {
            loadNominees()
            loadJudgeState()
            // Host observes: first tally (if none pending), then finalize/advance after decision
            if isHost { observeVotingFlow() }
            // Everyone watches meta for pendingElimination & judge window
            watchMetaVoteState()
        }
        .onChange(of: phaseListener.phase) { newPhase in
            if newPhase == Phase.night.rawValue || newPhase == Phase.end.rawValue { showNext = true }
        }
    }

    // MARK: Firebase: Loaders

    private func loadNominees() {
        db.child("meta/voteNominees").observeSingleEvent(of: .value) { snap in
            if let arr = snap.value as? [String] { nominees = arr }
        }
    }

    private func loadJudgeState() {
        // Judge present?
        db.child("players").observeSingleEvent(of: .value) { snap in
            var foundJudge: String?
            var alive = false
            for case let c as DataSnapshot in snap.children {
                if let d = c.value as? [String: Any] {
                    if (d["role"] as? String) == "Judge" {
                        foundJudge = (d["name"] as? String) ?? c.key
                        alive = (d["alive"] as? Bool ?? true)
                        break
                    }
                }
            }
            judgeName = foundJudge
            judgeAlive = alive
            iAmJudge = (foundJudge == playerName)

            // has judge been used?
            db.child("meta/judgeUsed").observeSingleEvent(of: .value) { used in
                judgeUsed = (used.value as? Bool) ?? false
            }
        }
    }

    private func watchMetaVoteState() {
        db.child("meta").observe(.value) { snap in
            if let m = snap.value as? [String: Any] {
                pendingElimination = m["pendingElimination"] as? String
                judgeWindowOpen = m["judgeWindowOpen"] as? Bool ?? false
            }
        }
    }

    // MARK: Voting submission

    private func submitVote() {
        guard let vote else { return }
        db.child("meta/night").observeSingleEvent(of: .value) { nightSnap in
            let night = (nightSnap.value as? Int) ?? 1
            db.child("votes").child("\(night)").childByAutoId().setValue([
                "voter": playerName,
                "target": vote,
                "ts": Date().timeIntervalSince1970
            ])
            db.child("players").child(playerName).updateChildValues(["done": true])
        }
    }

    // MARK: Host flow

    /// Host coordinates both steps: (1) tally to produce pendingElimination, (2) finalize after judge window.
    private func observeVotingFlow() {
        // Step 1: when all alive players are done AND no pending exists -> tally and open judge window if eligible
        db.child("players").observe(.value) { _ in
            self.tryTallyIfNeeded()
            self.tryFinalizeIfReady()
        }
        // Also watch judge decision
        db.child("meta/judgeDecision").observe(.value) { _ in
            self.tryFinalizeIfReady()
        }
    }

    private func tryTallyIfNeeded() {
        db.child("meta/pendingElimination").observeSingleEvent(of: .value) { pendingSnap in
            // If we already have a pending, skip tally
            if pendingSnap.exists() { return }

            // Are all alive players done?
            self.db.child("players").observeSingleEvent(of: .value) { snap in
                var allDone = true
                for case let c as DataSnapshot in snap.children {
                    if let d = c.value as? [String: Any],
                       (d["alive"] as? Bool ?? true),
                       (d["done"] as? Bool == false) { allDone = false }
                }
                guard allDone else { return }

                // Tally among nominees
                self.db.child("meta/night").observeSingleEvent(of: .value) { nightSnap in
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

                            // Write pending result + open judge window if eligible
                            self.db.child("meta").updateChildValues([
                                "pendingElimination": eliminated
                            ])

                            // If judge alive and unused → open window
                            self.db.child("meta").observeSingleEvent(of: .value) { m in
                                let judgeUsed = (m.childSnapshot(forPath: "judgeUsed").value as? Bool) ?? false
                                if let judgeName = self.judgeName, self.judgeAlive, !judgeUsed {
                                    self.db.child("meta").updateChildValues(["judgeWindowOpen": true, "judgeDecision": ""])
                                } else {
                                    self.db.child("meta").updateChildValues(["judgeWindowOpen": false])
                                }
                            }

                            // Reset done to let everyone press Continue (or Judge act)
                            self.db.child("players").observeSingleEvent(of: .value) { p in
                                for case let c as DataSnapshot in p.children {
                                    if let d = c.value as? [String: Any], (d["alive"] as? Bool ?? true) {
                                        self.db.child("players").child(c.key).updateChildValues(["done": false])
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    /// Step 2: After tally, finalize when either judge overrides or everyone presses Continue.
    private func tryFinalizeIfReady() {
        db.child("meta").observeSingleEvent(of: .value) { meta in
            guard let m = meta.value as? [String: Any] else { return }
            guard let eliminated = m["pendingElimination"] as? String else { return }

            let judgeUsed = (m["judgeUsed"] as? Bool) ?? false
            let judgeWindowOpen = (m["judgeWindowOpen"] as? Bool) ?? false
            let judgeDecision = (m["judgeDecision"] as? String) ?? ""

            // Are all alive done with this "result view"?
            self.db.child("players").observeSingleEvent(of: .value) { snap in
                var allDone = true
                for case let c as DataSnapshot in snap.children {
                    if let d = c.value as? [String: Any],
                       (d["alive"] as? Bool ?? true),
                       (d["done"] as? Bool == false) { allDone = false }
                }
                // If judge window open & judge hasn't decided yet, wait.
                if judgeWindowOpen && judgeDecision.isEmpty { return }
                guard allDone || judgeDecision == "override" else { return }

                // Finalize
                self.finalizeVote(eliminated: eliminated, judgeDecision: judgeDecision, judgeUsed: judgeUsed)
            }
        }
    }

    private func finalizeVote(eliminated: String, judgeDecision: String, judgeUsed: Bool) {
        db.child("meta/night").observeSingleEvent(of: .value) { nightSnap in
            let night = (nightSnap.value as? Int) ?? 1

            if judgeDecision == "override" {
                // Restore player if they were marked dead anywhere
                self.db.child("players").child(eliminated).updateChildValues(["alive": true])

                // Mark judge used
                self.db.child("meta").updateChildValues([
                    "judgeUsed": true,
                    "judgeWindowOpen": false,
                    "judgeDecision": "",
                    "pendingElimination": NSNull()
                ])

                // Record override in recap
                self.db.child("recap").child("\(night)").updateChildValues([
                    "judgeOverride": true,
                    "judgeOverrideTarget": eliminated
                ])

                // Continue to next night (or end) with standard check
                self.advanceToNightOrEnd(currentNight: night)
            } else {
                // Apply elimination normally (ensure alive=false)
                self.db.child("players").child(eliminated).updateChildValues(["alive": false])

                // Write day elimination in recap
                self.db.child("recap").child("\(night)").updateChildValues([
                    "dayEliminated": eliminated
                ])

                // Close judge window + clear pending
                self.db.child("meta").updateChildValues([
                    "judgeWindowOpen": false,
                    "judgeDecision": "",
                    "pendingElimination": NSNull()
                ])

                // Continue to next night (or end) with standard check
                self.advanceToNightOrEnd(currentNight: night)
            }
        }
    }

    private func advanceToNightOrEnd(currentNight night: Int) {
        // Win check
        db.child("players").observeSingleEvent(of: .value) { snap in
            var mafiaAlive = 0
            var townAlive = 0
            for case let c as DataSnapshot in snap.children {
                if let d = c.value as? [String: Any], (d["alive"] as? Bool ?? true) {
                    let role = (d["role"] as? String) ?? "Civi"
                    if role == "Godfather" || role == "Recruit" { mafiaAlive += 1 }
                    else { townAlive += 1 }
                }
            }

            if mafiaAlive == 0 {
                self.db.child("meta").updateChildValues(["phase": Phase.end.rawValue, "winner": "Town"])
            } else if mafiaAlive >= townAlive {
                self.db.child("meta").updateChildValues(["phase": Phase.end.rawValue, "winner": "Mafia"])
            } else {
                // Next night
                self.db.child("meta").updateChildValues(["phase": Phase.night.rawValue, "night": night + 1, "voteNominees": []])
                // Reset flags for next phase
                self.db.child("players").observeSingleEvent(of: .value) { p in
                    for case let c as DataSnapshot in p.children {
                        self.db.child("players").child(c.key).updateChildValues(["done": false, "silenced": false])
                    }
                }
            }
        }
    }

    // MARK: Judge action (client-side)

    private func useJudgeOverride() {
        // Judge sets decision flag; host will finalize accordingly
        db.child("meta").updateChildValues(["judgeDecision": "override"])
        // Judge also marks themselves done
        db.child("players").child(playerName).updateChildValues(["done": true])
    }
}
