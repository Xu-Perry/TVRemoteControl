//
//  TVRemoteControllerApp.swift
//  TVRemoteController
//
//  Created by Perry on 2026/4/30.
//

import SwiftUI

@main
struct TVRemoteControllerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @State private var state: RemotePageState
    @State private var viewModel: RemotePageViewModel

    init() {
        let state = RemotePageState()
        _state = State(initialValue: state)
        _viewModel = State(initialValue: AppEnvironment.makeRemotePageViewModel(state: state))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(state: state, viewModel: viewModel)
        }
    }
}
