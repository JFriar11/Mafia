//
//  LobbyView.swift
//  Mafia
//
//  Created by Jack Friar on 10/11/25.
//

import SwiftUI
import FirebaseDatabase

struct LobbyView: View {
    let code: String
    let playerName: String
    let isHost: Bool

    @State private var players: [String] = []
    @State private var showRoleReveal = false
    @State private var rolesConfig: [String: Int] = [
        "Godfather": 1, "Recruit": 0,
        "Cop": 1, "Medic": 1, "Judge": 0, "Vis": 0, "Diddy": 0, "Kazee": 0,
        "Civi": 2
    ]

    @StateObject private var phaseListener: PhaseListener

    private var db: DatabaseReference {
        Database.database().reference().child("lobbies").child(code)
    }

    init(code: String, playerName: String, isHost: Bool) {
        self.code = code
        self.playerName = playerName
        self.isHost = isHost
        _phaseListener = StateObject(wrappedValue: PhaseListener(code: code))
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("🎭 Lobby").font(.largeTitle).bold()
            Text("Code: \(code)").font(.headline)

            Divider()

            VStack(alignment: .leading) {
                Text("Players (\(players.count))").font(.headline)
                ScrollView {
                    ForEach(players, id: \.self) { Text("• \($0)") }
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 120)
            }

            Divider()

            if isHost {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Role Counts").font(.headline)
                    ForEach(roleList, id: \.self) { r in roleStepper(r) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button("Start Game") { startGame() }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 6)
                    .disabled(players.isEmpty)
            } else {
                Text("Waiting for host to start…").foregroundColor(.gray)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Configured Roles").font(.headline)
                    ForEach(rolesConfig.sorted(by: { $0.key < $1.key }), id: \.key) { k, v in
                        Text("\(k): \(v)")
                    }
                }
            }

            NavigationLink("", isActive: $showRoleReveal) {
                RoleRevealView(code: code, playerName: playerName, isHost: isHost)
                    .environmentObject(phaseListener)
            }
        }
        .padding()
        .onAppear {
            listenForPlayers()
            syncRolesConfig()
        }
        .onChange(of: phaseListener.phase) { newPhase in
            if newPhase == Phase.roles.rawValue { showRoleReveal = true }
        }
    }

    private var roleList: [String] {
        ["Godfather","Recruit","Cop","Medic","Judge","Vis","Diddy","Kazee","Civi"]
    }

    @ViewBuilder private func roleStepper(_ role: String) -> some View {
        HStack {
            Text(role).frame(width: 120, alignment: .leading)
            Stepper(value: Binding(
                get: { rolesConfig[role, default: 0] },
                set: { rolesConfig[role] = max(0, $0); saveRolesConfig() }
            ), in: 0...24) {
                Text("\(rolesConfig[role, default: 0])")
            }
        }
    }

    // MARK: Firebase
    private func listenForPlayers() {
        db.child("players").observe(.value) { snapshot in
            var list: [String] = []
            for case let child as DataSnapshot in snapshot.children {
                if let data = child.value as? [String: Any],
                   let n = data["name"] as? String { list.append(n) }
            }
            players = list.sorted()
        }
    }

    private func syncRolesConfig() {
        db.child("meta/rolesConfig").observe(.value) { snap in
            if let cfg = snap.value as? [String: Int] { rolesConfig = cfg }
        }
    }

    private func saveRolesConfig() {
        guard isHost else { return }
        db.child("meta").updateChildValues(["rolesConfig": rolesConfig])
    }

    private func startGame() {
        guard isHost else { return }

        // Reset transient nodes
        db.child("actions").removeValue()
        db.child("recap").removeValue()
        db.child("votes").removeValue()
        db.child("nominations").removeValue()
        db.child("intel").removeValue()

        // Persist config + set night counter
        db.child("meta").updateChildValues([
            "rolesConfig": rolesConfig,
            "night": 1,
        ])

        // Assign roles according to counts
        assignRoles(with: rolesConfig) {
            // Move to role reveal
            db.child("meta").updateChildValues(["phase": Phase.roles.rawValue])
        }
    }

    private func assignRoles(with config: [String: Int], completion: @escaping () -> Void) {
        db.child("players").observeSingleEvent(of: .value) { snapshot in
            var names: [String] = []
            for case let child as DataSnapshot in snapshot.children { names.append(child.key) }

            // Build deck
            var deck: [String] = []
            for (role, count) in config { for _ in 0..<max(0, count) { deck.append(role) } }
            while deck.count < names.count { deck.append("Civi") }
            if deck.count > names.count { deck = Array(deck.prefix(names.count)) }
            deck.shuffle()

            // Assign
            for (i, n) in names.enumerated() {
                self.db.child("players").child(n).updateChildValues([
                    "role": deck[i],
                    "done": false,
                    "alive": true,
                    "silenced": false,
                    "usedOneShot": false
                ])
            }
            completion()
        }
    }
}
