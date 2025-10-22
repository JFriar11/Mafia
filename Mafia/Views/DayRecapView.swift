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
    private var manager: PhaseManager { PhaseManager(code: code) }

    var body: some View {
        VStack(spacing: 16) {
            Text("🌅 Day Recap").font(.largeTitle)

            if !nightDead.isEmpty {
                VStack(alignment: .leading) {
                    Text("During the night:").font(.headline)
                    ForEach(nightDead, id: \.self) { Text("💀 \($0)") }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("No one died during the night.").font(.headline)
            }

            if let dayEliminated {
                VStack(alignment: .leading) {
                    Text("Yesterday's vote eliminated:").font(.headline)
                    Text("☠️ \(dayEliminated)")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text(summary).foregroundColor(.secondary)

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
            if isHost { manager.observeCompletion(for: .dayRecap) }
        }
        .onChange(of: phaseListener.phase) { newPhase in
            if newPhase == Phase.block.rawValue { showBlock = true }
        }
    }

    private func loadRecap() {
        db.child("meta/night").observeSingleEvent(of: .value) { nightSnap in
            let night = (nightSnap.value as? Int) ?? 1
            db.child("recap").child("\(night)").observeSingleEvent(of: .value) { r in
                if let d = r.value as? [String: Any] {
                    summary = (d["summary"] as? String) ?? summary
                    if let arr = d["deadPlayers"] as? [String] { nightDead = arr }
                    dayEliminated = d["dayEliminated"] as? String
                }
            }
        }
    }
}
