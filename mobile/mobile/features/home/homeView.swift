//
//  homeView.swift
//  mobile
//
//  Created by Soohyeuk Choi on 6/17/25.
//

import SwiftUI

struct homeView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Text("Home View")

                NavigationLink("Go to Settings") {
                    ContentView()
                }
            }
            .navigationTitle("Home")
        }
    }
}

#Preview {
    homeView()
}
