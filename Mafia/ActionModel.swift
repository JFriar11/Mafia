//
//  ActionModel.swift
//  Mafia
//
//  Created by Jack Friar on 10/13/25.
//

import Foundation

// What an action looks like in /lobbies/{code}/actions/{night}/{autoid}
struct NightAction: Codable {
    let actor: String           // player name
    let role: String            // Godfather, Medic, Cop, Vis, Diddy, Kazee, Recruit
    let kind: String            // "kill" | "recruit" | "save" | "check" | "silence"
    let target: String          // primary target
    let ts: TimeInterval        // client timestamp
}

// Convenience builders
enum ActionKind {
    static let kill = "kill"
    static let recruit = "recruit"
    static let save = "save"
    static let check = "check"
    static let silence = "silence"
}
