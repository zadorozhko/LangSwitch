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
import Accessibility

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem?
    var menu: NSMenu?
    var aboutWindow: NSWindow?
    let soundManager = SoundManager()
    let keyboardManager = KeyboardManager()
    var permissionsService: PermissionsService = PermissionsService()
    let spellChecker = WordChecker(ignoredWords: Set<String>(), ignoredPatternsOfWords: [], ignoredPatternsOfFilesOrDirectories: [])
    private var observationTokens: [NSKeyValueObservation] = []
    var contextProvider: ContextProvider = ContextProvider();
    var shift: Bool = false;
    var variants: [String]?;
    
    private var keyCodes: [Int] { keyboardManager.keyCodes }
    private var BACKSPACE: Int { Int(keyboardManager.BACKSPACE) }
    private var SPACE: Int { Int(keyboardManager.SPACE) }
    private var ENTER: Int { Int(keyboardManager.ENTER) }
    private var GLOBE: UInt16 { keyboardManager.GLOBE }
    private var OPTION_LEFT: UInt16 { keyboardManager.OPTION_LEFT }
    private var OPTION_RIGHT: UInt16 { keyboardManager.OPTION_RIGHT }
    private var SHIFT_LEFT: UInt16 { keyboardManager.SHIFT_LEFT }
    private var SHIFT_RIGHT: UInt16 { keyboardManager.SHIFT_RIGHT }
    private var longPressThreshold: TimeInterval { keyboardManager.longPressThreshold }
    
    var currentLanguage: String {
        get { keyboardManager.currentLanguage }
        set { }
    }
    
    private func simulateKeyPress(_ keyCode: Int) {
        keyboardManager.simulateKeyPress(keyCode)
    }
    
    func shiftKey(_ pressed: Bool) {
        let src = CGEventSource(stateID: .hidSystemState)
        let keyEvent = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(self.SHIFT_LEFT), keyDown: pressed)
        keyEvent?.post(tap: .cghidEventTap)
    }
    
    @objc func addException(word: String){
        // TODO:
    }
    
    // Deprecated
    @objc func variantChosen(_ sender: NSMenuItem){
        let variant = sender.tag;
        let word = self.variants?[variant];
        print("VarCh: \(variant) Var: \(word ?? "###")")
        self.soundManager.play(soundName: "switch");
        for _ in 0..<contextProvider.count() { // remove old word
            self.simulateKeyPress(self.BACKSPACE); // 8 - backspace, 46 - delete ??? Real backspace code is 51
        }
        for char in word ?? "" { // and type another
            let (key, shift) = self.getKeyCode(char: char)
            //print(key)
            if(shift){
                //self.shiftKey(true);
                print("S\(key)")
                self.simulateKeyPress(key);
                //self.shiftKey(false);
            } else {
                self.simulateKeyPress(key);
            }
        }
        contextProvider.flush()
        self.simulateKeyPress(Int(self.SPACE)); // restore space at end
    }
    
    func frontmostApplicationDidChange(context:NSRunningApplication) {
        //print("CL:\(self.currentLanguage) SH:\(self.shift) CTX:\(self.contextProvider.currentContext)")
        //for app in self.contextProvider.scancodes {
        //  print(app) йц
        //}
        //print("From \(self.contextProvider.currentContext ?? "±")");
        self.contextProvider.switchContext(ctx:NSWorkspace.shared.frontmostApplication!, currLang: self.currentLanguage);
        print("\(self.contextProvider.pull()) \(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "none")");
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set activation policy to .accessory to keep the app in the background
        // but still allow it to show menus and non-activating panels/windows.
        NSApplication.shared.setActivationPolicy(.accessory)
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
        
        let token = NSWorkspace.shared.observe(\.frontmostApplication, options: [.initial, .new]) { [weak self] _, _ in
            self?.frontmostApplicationDidChange(context: NSWorkspace.shared.frontmostApplication!)
                }
                observationTokens.append(token)

        var anotherClicked = false;
        var lastPressTime = Date();
 
        permissionsService.pollAccessibilityPrivileges()
       
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [self] event in
            let code = Int(event.keyCode);
            if event.keyCode == keyboardManager.SPACE {
                self.contextProvider.push(code:code, shift:self.shift);
                self.contextProvider.markDirty(); //v2
                self.checkSpeling();
            }
            if event.keyCode == keyboardManager.BACKSPACE {
                self.contextProvider.backspace(); //v.2
            } else {
                if (self.keyCodes.contains(Int(event.keyCode))){
                    self.contextProvider.push(code:code, shift:self.shift);
                }
            }
        }
        // Register for mouse buttons
        //NSEvent.addGlobalMonitorForEvents(matching: .otherMouseDown) { [self] event in
        //    print("Mouse %d down", event.buttonNumber)
        //}
        
        // Register for Fn button press events 
        NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [self] event in
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
            //print("Fn keyCode: \(event.keyCode) mod: \(event.modifierFlags.rawValue)")
            if [self.SHIFT_LEFT, self.SHIFT_RIGHT].contains(event.keyCode) {
                if(event.modifierFlags.rawValue != 256) {
                    self.shift = true;
                } else {
                    self.shift = false;
                }
                print("Shift:\(self.shift)");
            }
            if (event.keyCode == self.OPTION_LEFT && event.modifierFlags.rawValue == 256) { // Option key down
                //print(event.modifierFlags)
                self.switchKeyboardLanguage();
                self.soundManager.play(soundName: "switch");
                removeOld();
                typeNew();
            }
            if ((self.OPTION_RIGHT == event.keyCode) && (event.modifierFlags.rawValue == 256)) {
                checkSpeling();
                //print("CL:\(self.currentLanguage) SH:\(self.shift) CTX:\(self.contextProvider.currentContext)")
                //for app in self.contextProvider.scancodes {
                //  print(app)
                //}
            }
        }
    }
    
    func typeNew(){
        for key in self.contextProvider.pull() { // and type another
            self.simulateKeyPress(key);
        }
    }
    
    func removeOld(){
        if(0 == self.contextProvider.count()) {return;}
        for _ in 1...self.contextProvider.count() { // remove old word
            self.simulateKeyPress(self.BACKSPACE); // 8 - backspace, 46 - delete ??? Real backspace code is 51
        }
    }
    
    func checkSpeling(){
        // check spelling here закурим закурим пакурим пкурим
        let lastWord = self.getLastWord();
        let spelling = self.spellChecker.checkAndSuggestCorrections(word: lastWord,languages:Set<String>( arrayLiteral: self.currentLanguage))
        print(spelling);
        self.variants = spelling[lastWord];
        if(self.variants != nil){
            let sugg_count = self.variants?.count;
            if (sugg_count == 1 && self.variants?.first != lastWord){ // The only variant, autofix
                print("AF:\(self.variants?.first)");
                
            }
  /* Menu grabs focus - need to invent context menu */
            //print("Corrections: \(self.variants ?? ["###"])")
            self.soundManager.play(soundName: "misprint");
            let corrMenu = NSMenu();
            //corrMenu.addItem(withTitle: "Add exception", action: #selector(addException), keyEquivalent: "");
            var variant_idx = 0
            for suggestion in (self.variants ?? []) {
                let menuItem = NSMenuItem(title: suggestion, action: #selector(variantChosen(_:)), keyEquivalent: "");
                menuItem.tag = variant_idx;
                corrMenu.addItem(menuItem);
                variant_idx += 1;
            }
            if (variant_idx != 0) {
                self.statusBarItem?.popUpMenu(corrMenu);
            }
        }
    }
    
    func getKeyCodes(word: String) -> [Int] {
        var codes:[Int] = [];
        for char in word {
            let (pos,shift) = getKeyCode(char: char)
            if (pos == -1) { continue }
            var code = keyCodes[pos];
            if(shift){ code |= 0x1000}
            codes.append(code);
        }
        return codes;
    }
    
    func getKeyCode(char:Character) -> (Int, Bool) {
        return keyboardManager.getKeyCode(for: char)
    }
    
    func getLastWord() -> String {
        return keyboardManager.getLastWord(from: contextProvider.pull())
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

        if (AXIsProcessTrustedWithOptions(myDict)) {
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
            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "bug"
            let versionLabel = NSTextField(labelWithString: "LangSwitch v\(version)-\(build)")
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
    
    func switchKeyboardLanguage() {
        keyboardManager.onLanguageChanged = { [weak self] (newSourceName: String) in
            guard let self = self else { return }
            if newSourceName == "ABC" {
                self.statusBarItem?.button?.image = NSImage(systemSymbolName: "dollarsign", accessibilityDescription: nil)
                self.soundManager.play(soundName: "en")
            } else {
                self.statusBarItem?.button?.image = NSImage(systemSymbolName: "rublesign", accessibilityDescription: nil)
                self.soundManager.play(soundName: "ru")
            }
        }
        keyboardManager.switchLanguage()
    }
}
