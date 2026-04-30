//
//  ContentView.swift
//  SonyRemoteController
//
//  Created by Perry on 2026/4/30.
//

import SwiftUI

struct ContentView: View {
    let state: RemotePageState
    let viewModel: RemotePageViewModel

    var body: some View {
        RemotePageView(state: state, viewModel: viewModel)
    }
}

#Preview {
    let state = RemotePageState()
    let viewModel = AppEnvironment.makeRemotePageViewModel(state: state)
    ContentView(state: state, viewModel: viewModel)
}
