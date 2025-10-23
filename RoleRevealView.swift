//
//  RoleRevealView.swift
//  Mafia
//
//  Created by Jack Friar on 10/12/25.
//

import SwiftUI
import FirebaseDatabase

struct RoleRevealView: View {
    let code: String
    let playerName: String
    let isHost: Bool

    @EnvironmentObject var phaseListener: PhaseListener
    @State private var role = ""
    @State private var showNight = false

    private var db: DatabaseReference {
        Database.database().reference().child("lobbies").child(code)
    }
    private var manager: PhaseManager { PhaseManager(code: code) }

    var body: some View {
        VStack(spacing: 20) {
            Text("Your Role").font(.largeTitle).bold()
            Text(role.isEmpty ? "Assigning..." : role).font(.title)

            Button("Got it") {
                db.child("players").child(playerName).updateChildValues(["done": true])
            }
            .buttonStyle(.borderedProminent)
            .disabled(role.isEmpty)

            NavigationLink("", isActive: $showNight) {
                NightView(code: code, playerName: playerName, isHost: isHost)
                    .environmentObject(phaseListener)
            }
        }
        .padding()
        .onAppear {
            loadRole()
            if isHost { manager.observeCompletion(for: .roles) } // roles → night
        }
        .onChange(of: phaseListener.phase) { newPhase in
            if newPhase == Phase.night.rawValue { showNight = true }
        }
    }

    private func loadRole() {
        db.child("players").child(playerName).observeSingleEvent(of: .value) { snap in
            if let data = snap.value as? [String: Any],
               let r = data["role"] as? String { role = r }
        }
    }
}
