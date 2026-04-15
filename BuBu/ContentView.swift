//
//  ContentView.swift
//  BuBu
//
//  Created by Gwyneth on 2026/3/4.
//
import SwiftUI

struct ContentView: View {
    var body: some View {
        RootTabView()
    }
}

#Preview {
    RootTabView()
        .environmentObject(AppEnvironment.bootstrap())
}
