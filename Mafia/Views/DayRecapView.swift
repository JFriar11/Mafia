//
//  DayRecapView.swift
//  Mafia
//
//  Created by Jack Friar on 10/12/25.
//

import SwiftUI
import FirebaseDatabase

struct DayRecapView: View {
    let code: String
    let playerName: String
    let isHost: Bool

    @EnvironmentObject var phaseListener: PhaseListener
    @State private var summary = "Waiting for recap…"
    @State private var nightDead: [String] = []
    @State private var dayEliminated: String?
    @State private var showBlock = false

    private var db: DatabaseReference {
        Database.database().reference().child("lobbies").child(code)
    }
    
    private let phaseManager: PhaseManager
    
    init(code: String, playerName: String, isHost: Bool) {
        self.code = code
        self.playerName = playerName
        self.isHost = isHost
        self.phaseManager = PhaseManager(code: code)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("🌅 Day Recap").font(.largeTitle)

            if !nightDead.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("During the night:").font(.headline)
                    ForEach(nightDead, id: \.self) { name in
                        HStack {
                            Text("💀")
                            Text(name)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(10)
            } else {
                Text("No one died during the night.")
                    .font(.headline)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(10)
            }

            if let dayEliminated {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Yesterday's vote eliminated:").font(.headline)
                    HStack {
                        Text("☠️")
                        Text(dayEliminated)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(10)
            }

            Text(summary)
                .foregroundColor(.secondary)
                .padding()

            Button("Continue") {
                db.child("players").child(playerName).updateChildValues(["done": true])
            }
            .buttonStyle(.borderedProminent)

            NavigationLink("", isActive: $showBlock) {
                BlockView(code: code, playerName: playerName, isHost: isHost)
                    .environmentObject(phaseListener)
            }
        }
        .padding()
        .onAppear {
            loadRecap()
            if isHost {
                phaseManager.startObservingCompletion(for: .dayRecap)
            }
        }
        .onDisappear {
            if isHost {
                phaseManager.stopObserving()
            }
        }
        .onChange(of: phaseListener.phase) { newPhase in
            if newPhase == Phase.block.rawValue {
                showBlock = true
            }
        }
    }

    private func loadRecap() {
        db.child("meta/night").observeSingleEvent(of: .value) { nightSnap in
            let night = (nightSnap.value as? Int) ?? 1
            db.child("recap").child("\(night)").observeSingleEvent(of: .value) { r in
                if let d = r.value as? [String: Any] {
                    summary = (d["summary"] as? String) ?? summary
                    if let arr = d["deadPlayers"] as? [String] {
                        nightDead = arr
                    }
                    dayEliminated = d["dayEliminated"] as? String
                }
            }
        }
    }
}
