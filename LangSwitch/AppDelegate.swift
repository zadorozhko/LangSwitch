//
//  AppDelegate.swift
//  LangSwitch
//
//  Created by Ilia Zadorozhko 2024.
//

import SwiftUI
import Carbon
import Foundation
import AppKit
import AVFoundation
import Accessibility


class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem?
    var aboutWindow: NSWindow?
    var soundPlayer: AVAudioPlayer!
    var permissionsService: PermissionsService = PermissionsService()
    var currentLanguage = "en";
    var shift: Bool = false;
    var word: String;
    var keyBuffer: [Int] = [];
    var keyCodes = [12,13,14,15,17,16,32,34,31,35,33,30, /* qwertyuiop[] */
                    0,1,2,3,5,4,38,40,37,41,39,42,       /* asdfghjkl;'\ */
                    6,7,8,9,11,45,46,43,47];             /* zxcvbnm,.  56,60 - L/R Shift */
    var keyen = "qwertyuiop[]asdfghjkl;'\\zxcvbnm,.";
    var keyEN = "QWERTYUIOP[]ASDFGHJKL;'\\ZXCVBNM,. ";
    var keyru = "йцукенгшщзхъфывапролджэёячсмитьбю/";
    var keyRU = "ЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЁЯЧСМИТЬБЮ?";
    let longPressThreshold: TimeInterval = 0.2;
    let GLOBE = 63;
    let OPTION = 58;
    let BACKSPACE = 51;
    let SHIFT_LEFT :UInt16 = 56;
    let SHIFT_RIGHT :UInt16 = 60;
    let SPACE :UInt16 = 49;
    let ENTER :UInt16 = 36;
    
    func simulateKeyPress(_ keyCode: Int) {
        let src = CGEventSource(stateID: .hidSystemState)
        let keyDownEvent = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(keyCode), keyDown: true)
        let keyUpEvent = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(keyCode), keyDown: false)
        
        keyDownEvent?.post(tap: .cghidEventTap)
        keyUpEvent?.post(tap: .cghidEventTap)
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create a status bar item with a system icon
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength + 1)
        statusBarItem?.button?.image = NSImage(systemSymbolName: "dollarsign", accessibilityDescription: nil)
        statusBarItem?.isVisible = true
        
        // Add a menu to the status bar item
        let menu = NSMenu()
        menu.addItem(withTitle: "About LangSwitch", action: #selector(showAboutWindow), keyEquivalent: "")
        menu.addItem(withTitle: "Hide Icon", action: #selector(hideStatusBarIcon), keyEquivalent: "")
        menu.addItem(withTitle: "Request permissions", action: #selector(showPermissionWindow), keyEquivalent: "")
        menu.addItem(withTitle: "Exit", action: #selector(exitAction), keyEquivalent: "")
        statusBarItem?.menu = menu
        
        NSApp.setActivationPolicy(.accessory)
        NSApp.hide(nil)
        
        var anotherClicked = false;
        var lastPressTime = Date();
        
        permissionsService.pollAccessibilityPrivileges()
       
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            if ([self.SPACE, self.ENTER].contains(event.keyCode)) { // Space, Enter
                self.keyBuffer=[];
            } else if(event.keyCode == self.BACKSPACE) { //Backspace
                if (self.keyBuffer.count > 0){
                    self.keyBuffer.removeLast();
                    print("CL:\(self.currentLanguage) Code: \(event.keyCode) Buf:\(self.keyBuffer)");
                }
            } else {
                if (self.keyCodes.contains(Int(event.keyCode))){
                    self.keyBuffer.append(Int(event.keyCode));
                    print("CL:\(self.currentLanguage) Code: \(event.keyCode) Buf:\(self.keyBuffer)");
                }
            }
        }
        
        // Register for Fn button press events
        NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { event in
            if (event.keyCode == self.GLOBE && event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.function)) {
                anotherClicked = false;
                lastPressTime = Date();
            }
            
            if (!event.modifierFlags.intersection([.shift, .control, .option, .command]).isEmpty) {
                anotherClicked = true;
            }

            if (event.keyCode == self.GLOBE &&
                !anotherClicked &&
                event.modifierFlags.intersection(.deviceIndependentFlagsMask) == []) {
                let timePassed = Date().timeIntervalSince(lastPressTime);
                if (timePassed < self.longPressThreshold) {
                    self.switchKeyboardLanguage();
                }
            }
            print("Fn keyCode: \(event.keyCode)")
            if [self.SHIFT_LEFT, self.SHIFT_RIGHT].contains(event.keyCode) {
                self.shift = true;
            } else {
                self.shift = false;
            }
          
            if (event.keyCode == self.OPTION && event.modifierFlags.rawValue == 256) { // Option key down
                //print(event.modifierFlags)
                self.switchKeyboardLanguage();
                self.playSound(soundToPlay: "switch")
                for _ in self.keyBuffer { // remove old word
                    self.simulateKeyPress(self.BACKSPACE) // 8 - backspace, 46 - delete ??? Real backspace code is 51
                }
                for key in self.keyBuffer { // and type another
                    self.simulateKeyPress(key)
                }
                self.keyBuffer = []; //TODO: Dont clear buffer, reverse correction possible
            }
        }
    }
    
    @objc func press(_ key: Int, withModifiers modifiers: CGEventFlags = .init()) {
        let src = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(key), keyDown: true)!
        let up = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(key), keyDown: false)!
        down.flags = modifiers
        up.flags = modifiers
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
    
    @objc func showPermissionWindow() {
        let promptFlag = kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString
        let myDict: CFDictionary = NSDictionary(dictionary: [promptFlag: true])
        AXIsProcessTrustedWithOptions(myDict)

        if (AXIsProcessTrustedWithOptions(myDict))
        {
            print("AD: Access Granted")
        } else {
            print("AD: Access NOT Granted")
        }
    }
        
    @objc func showAboutWindow() {
        if aboutWindow == nil {
            let windowWidth: CGFloat = 300
            let windowHeight: CGFloat = 180
            
            let windowContent = NSView(frame: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight))
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown version"

            let versionLabel = NSTextField(labelWithString: "LangSwitch v\(version)")
            versionLabel.frame = NSRect(x: (windowWidth - 150) / 2, y: 130, width: 150, height: 20)
            versionLabel.alignment = .center // Центрирование текста
            windowContent.addSubview(versionLabel)
            
            let gitHubButton = NSButton(title: "GitHub Page", target: self, action: #selector(openGitHub))
            gitHubButton.frame = NSRect(x: (windowWidth - 100) / 2, y: 90, width: 100, height: 30)
            windowContent.addSubview(gitHubButton)

            let checkUpdatesButton = NSButton(title: "Check for Updates", target: self, action: #selector(checkForUpdates))
            checkUpdatesButton.frame = NSRect(x: (windowWidth - 150) / 2, y: 50, width: 150, height: 30)
            windowContent.addSubview(checkUpdatesButton)

            aboutWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
                                   styleMask: [.titled, .closable],
                                   backing: .buffered,
                                   defer: false)
            aboutWindow?.contentView = windowContent
            aboutWindow?.center()
        }
        aboutWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }


    @objc func openGitHub() {
        if let url = URL(string: "https://github.com/zadorozhko/LangSwitch") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc func checkForUpdates() {
        guard let url = URL(string: "https://api.github.com/repos/zadorozhko/LangSwitch/releases/latest") else { return }

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                self.showAlert(message: "Failed to check for updates.")
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let latestVersion = json["tag_name"] as? String {
                    let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"

                    if latestVersion > "v\(currentVersion)" {
                        self.showAlert(message: "New version \(latestVersion) is available! Download it from GitHub.")
                    } else {
                        self.showAlert(message: "You're up to date.")
                    }
                }
            } catch {
                self.showAlert(message: "Error parsing update information.")
            }
        }
        task.resume()
    }
    
    func showAlert(message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = message
            alert.runModal()
        }
    }
    
    @objc func hideStatusBarIcon() {
        statusBarItem?.isVisible = false
    }
    
    @objc func exitAction() {
        NSApplication.shared.terminate(nil)
    }
    
    func playSound(soundToPlay: String) {
        let url = Bundle.main.url(forResource: soundToPlay, withExtension: "wav")
        if (url) != nil {
            do {
                soundPlayer = try! AVAudioPlayer(contentsOf: url!)
                soundPlayer.volume = 1.0
                soundPlayer.play()
            }
        } else {
            print("Error: Sound \(soundToPlay) not found")
        }
    }
    
    func switchKeyboardLanguage() {
        // Get the current keyboard input source
        guard let currentSource = TISCopyCurrentKeyboardInputSource()?.takeUnretainedValue() else {
            print("Failed to get current keyboard language.")
            return
        }
        
        // Get all enabled keyboard input sources
        guard let inputSources = getInputSources() as? [TISInputSource],
              !inputSources.isEmpty else {
            print("Failed to get keyboard languages.")
            return
        }
        
        // Find the index of the current input source
        guard let currentIndex = inputSources.firstIndex(where: { $0 == currentSource }) else {
            print("Failed to switch keyboard language.")
            return
        }
        
        // Calculate the index of the next input source
        let nextIndex = (currentIndex + 1) % inputSources.count
        
        // Retrieve the next input source
        let nextSource = inputSources[nextIndex]
        
        // Switch to the next input source
        TISSelectInputSource(nextSource)
        
        // Print the new input source's name
        let newSourceName = Unmanaged<CFString>.fromOpaque(TISGetInputSourceProperty(nextSource, kTISPropertyLocalizedName)).takeUnretainedValue() as String
        if (newSourceName == "ABC") {
            statusBarItem?.button?.image = NSImage(systemSymbolName: "dollarsign", accessibilityDescription: nil)
            self.currentLanguage = "en";
            playSound(soundToPlay: "en")
        } else {
            statusBarItem?.button?.image = NSImage(systemSymbolName: "rublesign", accessibilityDescription: nil)
            self.currentLanguage = "ru";
            playSound(soundToPlay: "ru")
        }
        
        print("Switched to: \(newSourceName)")
    }
    
    func getInputSources() -> [TISInputSource] {
        let inputSourceNSArray = TISCreateInputSourceList(nil, false)
            .takeRetainedValue() as NSArray
        var inputSourceList = inputSourceNSArray as! [TISInputSource]
        
        inputSourceList = inputSourceList.filter({
            $0.category == TISInputSource.Category.keyboardInputSource
        })
        
        let inputSources = inputSourceList.filter(
            {
                $0.isSelectable
            })
        
        return inputSources
    }
}

extension TISInputSource {
    enum Category {
        static var keyboardInputSource: String {
            return kTISCategoryKeyboardInputSource as String
        }
    }
    
    private func getProperty(_ key: CFString) -> AnyObject? {
        let cfType = TISGetInputSourceProperty(self, key)
        if (cfType != nil) {
            return Unmanaged<AnyObject>.fromOpaque(cfType!)
                .takeUnretainedValue()
        } else {
            return nil
        }
    }
    
    var category: String {
        return getProperty(kTISPropertyInputSourceCategory) as! String
    }
    
    var isSelectable: Bool {
        return getProperty(kTISPropertyInputSourceIsSelectCapable) as! Bool
    }
}
