//
//  EntryView.swift
//  Mafia
//
//  Created by Jack Friar on 10/11/25.
//

import SwiftUI
import FirebaseDatabase

struct EntryView: View {
    @State private var name = ""
    @State private var code = ""
    @State private var isHost = false
    @State private var navigate = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("MAF").font(.largeTitle).bold()
                TextField("NAME", text: $name).textFieldStyle(.roundedBorder)
                HStack {
                    TextField("Lobby code (e.g. 1234)", text: $code)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                    Button("New") {
                        code = String(Int.random(in: 1000...9999))
                        isHost = true
                    }
                }
                Toggle("I am the host", isOn: $isHost)

                Button(isHost ? "Create Lobby" : "Join Lobby") { joinOrCreate() }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.isEmpty || code.isEmpty)

                NavigationLink("", isActive: $navigate) {
                    LobbyView(code: code, playerName: name, isHost: isHost)
                }
            }
            .padding()
        }
    }

    private func joinOrCreate() {
        let lobby = Database.database().reference().child("lobbies").child(code)
        // Ensure meta exists; host sets host + phase
        if isHost {
            lobby.child("meta").updateChildValues([
                "phase": Phase.lobby.rawValue,
                "host": name
            ])
        }
        // Add/ensure player record
        lobby.child("players").child(name).updateChildValues([
            "name": name,
            "role": "Unassigned",
            "done": false,
            "alive": true
        ])
        navigate = true
    }
}
