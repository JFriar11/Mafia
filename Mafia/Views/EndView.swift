//
//  EndView.swift
//  Mafia
//
//  Created by Jack Friar on 10/12/25.
//

import SwiftUI
import FirebaseDatabase

struct EndView: View {
    let code: String
    let playerName: String
    @EnvironmentObject var phaseListener: PhaseListener

    private var db: DatabaseReference {
        Database.database().reference().child("lobbies").child(code)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("🏁 Game Over").font(.largeTitle).bold()
            Text("Thanks for playing, \(playerName)!").font(.title3)

            Button("Return to Lobby") {
                db.child("meta").updateChildValues(["phase": Phase.lobby.rawValue])
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
