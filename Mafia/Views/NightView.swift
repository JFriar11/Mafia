//
//  NightView.swift
//  Mafia
//
//  Created by Jack Friar on 10/12/25.
//

import SwiftUI
import FirebaseDatabase

struct NightView: View {
    let code: String
    let playerName: String
    let isHost: Bool

    @EnvironmentObject var phaseListener: PhaseListener

    @State private var role = ""
    @State private var players: [String] = []
    @State private var selectedTarget: String?
    @State private var gfMode: String = ActionKind.kill // Godfather: kill or recruit
    @State private var usedOneShot = false
    @State private var showRecap = false

    private var db: DatabaseReference {
        Database.database().reference().child("lobbies").child(code)
    }

    private let resolver: NightResolver
    
    init(code: String, playerName: String, isHost: Bool) {
        self.code = code
        self.playerName = playerName
        self.isHost = isHost
        // Use the new resolver (rename if you renamed ImprovedNightResolverV2 to NightResolver)
        self.resolver = NightResolver(code: code)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("🌙 Night Phase").font(.largeTitle)
            Text("Role: \(role)")
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)

            if isPassive(role) {
                VStack(spacing: 12) {
                    Text("You sleep peacefully…")
                        .font(.headline)
                        .padding(.top, 12)
                    
                    Text("You have no night action")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("I'm in bed 😴") {
                        db.child("players").child(playerName).updateChildValues(["done": true])
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                VStack(spacing: 16) {
                    if role == "Godfather" {
                        Picker("Action", selection: $gfMode) {
                            Text("Kill").tag(ActionKind.kill)
                            Text("Recruit").tag(ActionKind.recruit)
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    if role == "Vis" && usedOneShot {
                        Text("You've already used your one-time kill")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(8)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                    }

                    Text("Choose a target")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(players.filter { $0 != playerName }, id: \.self) { n in
                                Button {
                                    selectedTarget = n
                                } label: {
                                    HStack {
                                        Text(n)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        if selectedTarget == n {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                        }
                                    }
                                    .padding()
                                    .background(
                                        selectedTarget == n
                                            ? Color.green.opacity(0.2)
                                            : Color.gray.opacity(0.12)
                                    )
                                    .cornerRadius(10)
                                }
                            }
                        }
                    }

                    Button("Submit \(buttonLabel)") {
                        submitAction()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canAct)
                }
            }

            NavigationLink("", isActive: $showRecap) {
                DayRecapView(code: code, playerName: playerName, isHost: isHost)
                    .environmentObject(phaseListener)
            }
        }
        .padding()
        .onAppear {
            loadSelf()
            loadPlayers()
            if isHost {
                resolver.startObserving()
            }
        }
        .onDisappear {
            if isHost {
                resolver.stopObserving()
            }
        }
        .onChange(of: phaseListener.phase) { newPhase in
            if newPhase == Phase.dayRecap.rawValue {
                showRecap = true
            }
        }
    }

    // MARK: Helpers

    private func isPassive(_ r: String) -> Bool {
        // Roles with NO night action
        return r == "Civi" || r == "Judge" || r == "Recruit"
    }

    private var canAct: Bool {
        guard let _ = selectedTarget else { return false }
        if role == "Vis" && usedOneShot { return false }
        return true
    }

    private var buttonLabel: String {
        switch role {
        case "Godfather":
            return gfMode == ActionKind.recruit ? "Recruit" : "Kill"
        case "Medic": return "Save"
        case "Cop":   return "Check"
        case "Vis":   return "Kill"
        case "Diddy": return "Silence"
        case "Kazee": return "Kill"
        default:      return "Submit"
        }
    }

    private func loadSelf() {
        db.child("players").child(playerName).observeSingleEvent(of: .value) { snap in
            if let d = snap.value as? [String: Any] {
                role = (d["role"] as? String) ?? "Civi"
                usedOneShot = d["usedOneShot"] as? Bool ?? false
            }
        }
    }

    private func loadPlayers() {
        db.child("players").observeSingleEvent(of: .value) { snap in
            var list: [String] = []
            for case let c as DataSnapshot in snap.children {
                if let d = c.value as? [String: Any], (d["alive"] as? Bool ?? true) {
                    let n = (d["name"] as? String) ?? c.key
                    list.append(n)
                }
            }
            players = list.sorted()
        }
    }

    private func submitAction() {
        // Passive roles never write an action — just mark done
        if isPassive(role) {
            db.child("players").child(playerName).updateChildValues(["done": true])
            return
        }
        guard let target = selectedTarget else { return }

        db.child("meta/night").observeSingleEvent(of: .value) { nightSnap in
            let night = (nightSnap.value as? Int) ?? 1
            let kind = actionKindForRole()
            let payload: [String: Any] = [
                "actor": playerName,
                "role": role,
                "kind": kind,
                "target": target,
                "ts": Date().timeIntervalSince1970
            ]
            db.child("actions").child("\(night)").childByAutoId().setValue(payload)

            if role == "Vis" {
                db.child("players").child(playerName).updateChildValues(["usedOneShot": true])
            }
            db.child("players").child(playerName).updateChildValues(["done": true])
        }
    }

    private func actionKindForRole() -> String {
        switch role {
        case "Godfather": return gfMode
        case "Medic": return ActionKind.save
        case "Cop": return ActionKind.check
        case "Vis": return ActionKind.kill
        case "Diddy": return ActionKind.silence
        case "Kazee": return ActionKind.kill
        default: return ActionKind.kill // ignored for passives
        }
    }
}
