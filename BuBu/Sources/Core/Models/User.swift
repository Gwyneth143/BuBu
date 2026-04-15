//
//  User.swift
//  BuBu
//
//  Created by Gwyneth on 2026/3/16.
//
import Foundation

struct User: Identifiable, Hashable {
    let id: UUID
    var name: String
    var books: [String]
}
