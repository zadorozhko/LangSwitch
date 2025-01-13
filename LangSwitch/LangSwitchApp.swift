//
//  LangSwitchApp.swift
//  LangSwitch
//
//  Created by ANTON NIKEEV on 05.07.2023.
//

import SwiftUI

@main
struct LangSwitchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var permissionsService = PermissionsService()
    
    var body: some Scene {
        Settings {
            if self.permissionsService.isTrusted {
                EmptyView().frame(width:.zero)
            } else {
                PermissionsView()
            }
        }
    }
}
