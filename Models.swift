//
//  Models.swift
//  Mafia
//
//  Created by Jack Friar on 10/11/25.
//

import Foundation

enum Phase: String, Codable, CaseIterable {
    case lobby, roles, night, dayRecap, block, vote, end
}

let mafiaRoles = ["Godfather", "Recruit"]
func isMafiaRole(_ role: String?) -> Bool { mafiaRoles.contains(role ?? "") }

struct Player: Identifiable, Hashable {
    let id: String
    var name: String
    var role: String?
    var alive: Bool
    var silenced: Bool
    var cleaned: Bool
    var usedOneShot: Bool
}

