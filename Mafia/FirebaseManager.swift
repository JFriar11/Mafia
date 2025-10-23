//
//  FirebaseManager.swift
//  Mafia
//
//  Created by Jack Friar on 10/11/25.
//

import FirebaseDatabase
import AVFoundation

final class DB {
    let code: String
    init(_ code: String) { self.code = code }

    var root: DatabaseReference { Database.database().reference().child("lobbies").child(code) }
    var meta: DatabaseReference { root.child("meta") }
    var players: DatabaseReference { root.child("players") }
    func actions(_ n: Int) -> DatabaseReference { root.child("actions").child("\(n)") }
    func votes(_ d: Int) -> DatabaseReference { root.child("votes").child("\(d)") }
    func recap(_ d: Int) -> DatabaseReference { root.child("recap").child("\(d)") }
}

final class AudioCtl {
    private var player: AVAudioPlayer?
    func play(_ name: String) {
        if let url = Bundle.main.url(forResource: name, withExtension: "mp3") {
            player = try? AVAudioPlayer(contentsOf: url)
            player?.play()
        }
    }
    func sequence(_ names: [String]) {
        for n in names { play(n) }
    }
}

