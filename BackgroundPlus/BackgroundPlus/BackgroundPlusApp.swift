//
//  BackgroundPlusApp.swift
//  BackgroundPlus
//
//  Created by 经典 on 2026/3/19.
//

import SwiftUI

@main
struct BackgroundPlusApp: App {
    @StateObject private var viewModel = BTMViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }

        Settings {
            HelperSettingsContainerView(viewModel: viewModel)
        }
    }
}
