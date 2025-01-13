//
//  PermissionsService.swift
//  LangSwitch
//
//  Created by Zadorozhko Ilia on 08.01.2025.
//


import Cocoa

final class PermissionsService: ObservableObject {
    // Store the active trust state of the app.
    @Published var isTrusted: Bool = false

    // Poll the accessibility state every 1 second to check
    //  and update the trust status.
    @objc func pollAccessibilityPrivileges() {
        //PermissionsView()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.acquireAccessibilityPrivileges()
        }
    }

    // Request accessibility permissions, this should prompt
    //  macOS to open and present the required dialogue open
    //  to the correct page for the user to just hit the add 
    //  button.
    func acquireAccessibilityPrivileges() {
        let promptFlag = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString
        let myDict: CFDictionary = NSDictionary(dictionary: [promptFlag: true])
        AXIsProcessTrustedWithOptions(myDict)
        if (AXIsProcessTrustedWithOptions(myDict)) {
            //we have permission granted here
            self.isTrusted = true
            print("PS: Access Granted")
        } else {
            self.isTrusted = false
            print("PS: Access Not Enabled")
            PermissionsView()
        }
    }
}
