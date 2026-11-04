//
//  VotingView.swift
//  Mafia
//
//  Created by Jack Friar on 10/12/25.
//


import SwiftUI
import FirebaseDatabase

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
    @State private var iAmJudge = false
    @State private var judgeUsed = false
    @State private var judgeWindowOpen = false
    @State private var showNext = false
    @State private var myRole = ""
    @State private var iAmAlive = true

    private var db: DatabaseReference {
        Database.database().reference().child("lobbies").child(code)
    }
    
    private let votingManager: VotingManager
    
    init(code: String, playerName: String, isHost: Bool) {
        self.code = code
        self.playerName = playerName
        self.isHost = isHost
        self.votingManager = VotingManager(code: code)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("🗳️ Voting Phase").font(.largeTitle)

            if let pending = pendingElimination {
                // Show result and judge override option
                VStack(spacing: 12) {
                    Text("Vote Result").font(.headline)
                    Text("\(pending) would be eliminated")
                        .font(.title3)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(10)
                    
                    if iAmJudge && !judgeUsed && iAmAlive && judgeWindowOpen {
                        VStack(spacing: 8) {
                            Text("You are the Judge!")
                                .font(.headline)
                                .foregroundColor(.blue)
                            
                            Button("Use Judge Override (Save \(pending))") {
                                useJudgeOverride()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                            
                            Text("This is your one-time power")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                    }
                    
                    Button("Continue") {
                        db.child("players").child(playerName).updateChildValues(["done": true])
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                // Standard voting UI
                if nominees.isEmpty {
                    ProgressView("Loading nominees…")
                } else {
                    Text("Vote to eliminate one of these players:")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(nominees, id: \.self) { nominee in
                                Button {
                                    vote = nominee
                                } label: {
                                    HStack {
                                        Text(nominee)
                                            .font(.title3)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        if vote == nominee {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                        }
                                    }
                                    .padding()
                                    .background(
                                        vote == nominee
                                            ? Color.green.opacity(0.2)
                                            : Color.gray.opacity(0.12)
                                    )
                                    .cornerRadius(10)
                                }
                            }
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
            loadPlayerState()
            watchMetaVoteState()
            
            // Host starts the voting manager
            if isHost {
                votingManager.startObserving()
            }
        }
        .onDisappear {
            // Clean up
            if isHost {
                votingManager.stopObserving()
            }
        }
        .onChange(of: phaseListener.phase) { newPhase in
            if newPhase == Phase.night.rawValue || newPhase == Phase.end.rawValue {
                showNext = true
            }
        }
    }

    // MARK: - Data Loading

    private func loadNominees() {
        db.child("meta/voteNominees").observe(.value) { snap in
            if let arr = snap.value as? [String] {
                nominees = arr
            }
        }
    }

    private func loadPlayerState() {
        db.child("players").child(playerName).observe(.value) { snap in
            if let d = snap.value as? [String: Any] {
                myRole = (d["role"] as? String) ?? ""
                iAmAlive = (d["alive"] as? Bool) ?? true
                iAmJudge = (myRole == "Judge")
            }
        }
        
        db.child("meta/judgeUsed").observe(.value) { snap in
            judgeUsed = (snap.value as? Bool) ?? false
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

    // MARK: - Actions

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

    private func useJudgeOverride() {
        // Judge sets the override decision
        db.child("meta").updateChildValues(["judgeDecision": "override"])
        
        // Mark judge as done
        db.child("players").child(playerName).updateChildValues(["done": true])
    }
}
