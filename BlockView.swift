//
//  BlockView.swift
//  Mafia
//
//  Created by Jack Friar on 10/12/25.
//

import SwiftUI
import FirebaseDatabase

struct BlockView: View {
    let code: String
    let playerName: String
    let isHost: Bool

    @EnvironmentObject var phaseListener: PhaseListener
    @State private var players: [String] = []
    @State private var nominee: String?
    @State private var primaryNominee: String?
    @State private var pickingSecondary = false
    @State private var secondChoice: String?
    @State private var showVoting = false

    private var db: DatabaseReference {
        Database.database().reference().child("lobbies").child(code)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("⚖️ Block (Nomination)").font(.largeTitle)

            if pickingSecondary {
                Text("You are on the block. Pick one person to join you:")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ScrollView {
                    ForEach(players.filter { $0 != playerName && $0 != primaryNominee }, id: \.self) { n in
                        Button {
                            secondChoice = n
                        } label: {
                            HStack {
                                Text(n)
                                Spacer()
                                if secondChoice == n { Image(systemName: "checkmark.circle.fill") }
                            }
                            .padding()
                            .background(Color.gray.opacity(0.12))
                            .cornerRadius(10)
                        }
                    }
                }

                Button("Confirm Second Nominee") {
                    confirmSecondNominee()
                }
                .buttonStyle(.borderedProminent)
                .disabled(secondChoice == nil)
            } else {
                Text("Nominate someone to be on the block:")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ScrollView {
                    ForEach(players.filter { $0 != playerName }, id: \.self) { n in
                        Button {
                            nominee = n
                        } label: {
                            HStack {
                                Text(n)
                                Spacer()
                                if nominee == n { Image(systemName: "checkmark.circle.fill") }
                            }
                            .padding()
                            .background(Color.gray.opacity(0.12))
                            .cornerRadius(10)
                        }
                    }
                }

                Button("Submit Nomination") {
                    submitNomination()
                }
                .buttonStyle(.borderedProminent)
                .disabled(nominee == nil)
            }

            NavigationLink("", isActive: $showVoting) {
                VotingView(code: code, playerName: playerName, isHost: isHost)
                    .environmentObject(phaseListener)
            }
        }
        .padding()
        .onAppear {
            loadPlayers()
            watchPrimaryAndSecondary()
            if isHost { observeAllDoneThenPickPrimary() }
        }
        .onChange(of: phaseListener.phase) { newPhase in
            if newPhase == Phase.vote.rawValue { showVoting = true }
        }
    }

    // MARK: Firebase

    private func loadPlayers() {
        db.child("players").observeSingleEvent(of: .value) { snap in
            var list: [String] = []
            for case let c as DataSnapshot in snap.children {
                if let d = c.value as? [String: Any], (d["alive"] as? Bool ?? true) {
                    list.append((d["name"] as? String) ?? c.key)
                }
            }
            players = list.sorted()
        }
    }

    private func submitNomination() {
        guard let nominee else { return }
        db.child("meta/night").observeSingleEvent(of: .value) { nightSnap in
            let night = (nightSnap.value as? Int) ?? 1
            db.child("nominations").child("\(night)").childByAutoId().setValue([
                "nominator": playerName,
                "nominee": nominee,
                "ts": Date().timeIntervalSince1970
            ])
            db.child("players").child(playerName).updateChildValues(["done": true])
        }
    }

    /// Host: when all alive players are done nominating, choose PRIMARY (top) and open secondary picker for that player.
    private func observeAllDoneThenPickPrimary() {
        db.child("players").observe(.value) { _ in
            self.tryPickPrimary()
        }
    }

    private func tryPickPrimary() {
        db.child("players").observeSingleEvent(of: .value) { snap in
            var allDone = true
            var alive: [String] = []
            for case let c as DataSnapshot in snap.children {
                if let d = c.value as? [String: Any] {
                    let aliveFlag = d["alive"] as? Bool ?? true
                    if aliveFlag {
                        alive.append(c.key)
                        if d["done"] as? Bool == false { allDone = false }
                    }
                }
            }
            guard allDone else { return }

            // Tally nominations
            self.db.child("meta/night").observeSingleEvent(of: .value) { nightSnap in
                let night = (nightSnap.value as? Int) ?? 1
                self.db.child("nominations").child("\(night)").observeSingleEvent(of: .value) { nomSnap in
                    var counts: [String: Int] = [:]
                    for case let c as DataSnapshot in nomSnap.children {
                        if let d = c.value as? [String: Any],
                           let nom = d["nominee"] as? String {
                            counts[nom, default: 0] += 1
                        }
                    }
                    // pick top nominee (break ties randomly)
                    let maxVotes = counts.values.max() ?? 0
                    let tops = counts.filter { $0.value == maxVotes }.map { $0.key }
                    let primary = tops.randomElement() ?? (alive.randomElement() ?? "")
                    // Save primary and open secondary selection
                    self.db.child("meta").updateChildValues([
                        "blockPrimary": primary,
                        "blockSelectSecondaryOpen": true,
                        "voteNominees": [] // clear
                    ])
                    // Reset done for the next sub-phase (secondary selection)
                    for n in alive {
                        self.db.child("players").child(n).updateChildValues(["done": false])
                    }
                }
            }
        }
    }

    /// Everyone watches meta to know if they're the primary (who must pick the second)
    private func watchPrimaryAndSecondary() {
        db.child("meta").observe(.value) { snap in
            if let m = snap.value as? [String: Any] {
                primaryNominee = m["blockPrimary"] as? String
                let secondaryOpen = m["blockSelectSecondaryOpen"] as? Bool ?? false

                // If I'm the primary and the selection window is open, switch UI mode
                if secondaryOpen, primaryNominee == playerName {
                    pickingSecondary = true
                } else {
                    pickingSecondary = false
                }
            }
        }
    }

    private func confirmSecondNominee() {
        guard let primary = primaryNominee, let second = secondChoice, second != primary else { return }

        // Save the final pair → voteNominees, close selection, move to Vote
        db.child("meta").updateChildValues([
            "voteNominees": [primary, second],
            "blockSelectSecondaryOpen": false,
            "phase": Phase.vote.rawValue
        ])

        // Reset players.done for voting
        db.child("players").observeSingleEvent(of: .value) { p in
            for case let c as DataSnapshot in p.children {
                if let d = c.value as? [String: Any], (d["alive"] as? Bool ?? true) {
                    self.db.child("players").child(c.key).updateChildValues(["done": false])
                }
            }
        }
    }
}
