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
    var menu: NSMenu?
    var aboutWindow: NSWindow?
    var soundPlayer: AVAudioPlayer!
    var permissionsService: PermissionsService = PermissionsService()
    let spellChecker = WordChecker(ignoredWords: Set<String>(), ignoredPatternsOfWords: [], ignoredPatternsOfFilesOrDirectories: [])
    private var observationTokens: [NSKeyValueObservation] = []
    var contextProvider: ContextProvider = ContextProvider();
    var currentLanguage = "en";
    var currentSource = "ABC";
    var shift: Bool = false;
    var variants: [String]?;
    //var keyBuffer: [Int] = [];
    let keyCodes = [12,13,14,15,17,16,32,34,31,35,33,30, /* qwertyuiop[] */
                    0,1,2,3,5,4,38,40,37,41,39,42,       /* asdfghjkl;'\ */
                    6,7,8,9,11,45,46,43,47];             /* zxcvbnm,.  56,60 - L/R Shift */
    let keyen = "qwertyuiop[]asdfghjkl;'\\zxcvbnm,.";
    let keyEN = "QWERTYUIOP[]ASDFGHJKL;'\\ZXCVBNM,. ";
    var keyru = "йцукенгшщзхъфывапролджэёячсмитьбю/";
    let keyRU = "ЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЁЯЧСМИТЬБЮ?";
    let longPressThreshold: TimeInterval = 0.2;
    let GLOBE = 63;
    let OPTION_LEFT = 58;
    let OPTION_RIGHT = 61;
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
        self.playSound(soundToPlay: "switch");
//        for _ in self.keyBuffer { // remove old word
            self.simulateKeyPress(self.BACKSPACE); // 8 - backspace, 46 - delete ??? Real backspace code is 51
 //       }
        for char in word ?? "" { // and type another
            let (key, shift) = self.getKeyCode(char: char)
            //print(key)
            if(shift){
                //self.shiftKey(true);
                self.simulateKeyPress(key);
                //self.shiftKey(false);
            } else {
                self.simulateKeyPress(key);
            }
        }
        //self.simulateKeyPress(Int(self.SPACE)); // restore space at end
        //self.keyBuffer.removeAll();
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
            let code = Int(event.keyCode); //v.2
            if([self.SPACE, self.ENTER].contains(event.keyCode)){
                self.contextProvider.push(code:code);
                self.contextProvider.markDirty(); //v2
                self.checkSpeling();
            }
            if(event.keyCode == self.BACKSPACE) { //Backspace v.1
                self.contextProvider.backspace(); //v.2
            } else {
                if (self.keyCodes.contains(Int(event.keyCode))){
                    self.contextProvider.push(code:code);
                }
            }
        }
        // Register for mouse buttons
        NSEvent.addGlobalMonitorForEvents(matching: .otherMouseDown) { [self] event in
            print("Mouse %d down", event.buttonNumber)
        }
        
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
                self.playSound(soundToPlay: "switch");
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
  /* Menu grabs focus - need to invent context menu
            print("Corrections: \(self.variants ?? ["###"])")
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
                //self.statusBarItem?.popUpMenu(corrMenu);
            }
   */
            self.playSound(soundToPlay: "misprint");
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
        var pos = self.keyen.distance(of: char)
        var shift = false;
        if (pos == nil) { pos = self.keyru.distance(of: char) }
        if (pos == nil) { pos = self.keyEN.distance(of: char); shift=true }
        if (pos == nil) { pos = self.keyRU.distance(of: char); shift=true };
        return (keyCodes[pos ?? -1], shift);
    }
    
    func getLastWord() -> String { // This convert FROM keycodes to currentLanguage давай закурим
        var str:String = "";
        for code in self.contextProvider.pull() {
            if(code == self.SPACE || code == self.ENTER) {
                return str;
            }
            let pos = self.keyCodes.firstIndex(of: code)
            if (self.currentLanguage == "en" && !self.shift) {
                str.append(keyen[pos!]);
            } else if (self.currentLanguage == "en" && self.shift) {
                str.append(keyEN[pos!]);
            } else if (self.currentLanguage == "ru" && !self.shift) {
                str.append(keyru[pos!]);
            } else if (self.currentLanguage == "ru" && self.shift) {
                str.append(keyRU[pos!]);
            }
            //print("\(pos ?? -1):\(code) = \(str)")
        }
        print("S:\(self.shift) last:\(str)")
        return str;
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
        self.currentSource = newSourceName;
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

extension String {
    var length: Int {
        return count
    }
    subscript (i: Int) -> String {
        return self[i ..< i + 1]
    }
    func substring(fromIndex: Int) -> String {
        return self[min(fromIndex, length) ..< length]
    }
    func substring(toIndex: Int) -> String {
        return self[0 ..< max(0, toIndex)]
    }
    subscript (r: Range<Int>) -> String {
        let range = Range(uncheckedBounds: (lower: max(0, min(length, r.lowerBound)),
                                            upper: min(length, max(0, r.upperBound))))
        let start = index(startIndex, offsetBy: range.lowerBound)
        let end = index(start, offsetBy: range.upperBound - range.lowerBound)
        return String(self[start ..< end])
    }
}
extension StringProtocol {
    func distance(of element: Element) -> Int? { firstIndex(of: element)?.distance(in: self) }
    func distance<S: StringProtocol>(of string: S) -> Int? { range(of: string)?.lowerBound.distance(in: self) }
}
extension Collection {
    func distance(to index: Index) -> Int { distance(from: startIndex, to: index) }
}
extension String.Index {
    func distance<S: StringProtocol>(in string: S) -> Int { string.distance(to: self) }
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
