//
//  AppDelegate.swift
//  LangSwitch
//
//  Created by Ilia Zadorozhko 2024.
//

import SwiftUI
import AppKit
import Accessibility
import ServiceManagement

@available(macOS 12.0, *)
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarItem: NSStatusItem?
    private let soundManager = SoundManager()
    private let keyboardManager = KeyboardManager()
    private let aboutWindowManager = AboutWindowManager()
    private let permissionsService = PermissionsService()
    private let spellChecker = WordChecker(ignoredWords: [], ignoredPatternsOfWords: [], ignoredPatternsOfFilesOrDirectories: [])
    private let contextProvider = ContextProvider()
    private var eventMonitor: EventMonitor?
    private var observationTokens: [NSKeyValueObservation] = []
    
    private var shift: Bool = false
    private var variants: [String]?
    
    private var currentLanguage: String {
        keyboardManager.currentLanguage
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        launchAtLogin()
        setupStatusBar()
        setupObservers()
        setupPermissions()
        setupEventMonitor()
    }
    
    @objc func launchAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                if SMAppService.mainApp.status == .enabled {
                    // do nothing
                    print("Login item already registered.")
                } else {
                    try SMAppService.mainApp.register()
                }
            } catch {
                print("Failed to enable login item: \(error)")
            }
        } else {
            // Fallback on earlier versions
            print("Login item functionality is not available on this version of macOS.")
        }
    }

    
    private func setupStatusBar() {
        NSApplication.shared.setActivationPolicy(.accessory)
        
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        //statusBarItem?.button?.image = NSImage(systemSymbolName: "dollarsign", accessibilityDescription: nil)
        let fontSize: CGFloat = 21.0 // Flag icon size
        //self.statusBarItem?.button?.frame = CGRectMake(0.0, 0.0, 10.0, 8.0)
        self.statusBarItem?.button?.font = NSFont.systemFont(ofSize: fontSize)
        self.statusBarItem?.button?.title = "🇺🇸"
        statusBarItem?.isVisible = true
        
        let menu = NSMenu()
        menu.addItem(withTitle: "About LangSwitch", action: #selector(showAboutWindow), keyEquivalent: "")
        menu.addItem(withTitle: "Hide Icon", action: #selector(hideStatusBarIcon), keyEquivalent: "")
        menu.addItem(withTitle: "Request permissions", action: #selector(showPermissionWindow), keyEquivalent: "")
        menu.addItem(withTitle: "Exit", action: #selector(exitAction), keyEquivalent: "")
        statusBarItem?.menu = menu
        // hide menu bar if the button was pressed once
         let userDefaults = UserDefaults.standard
         if userDefaults.bool(forKey: "hideStatusBarIcon") {
             statusBarItem?.isVisible = false
         }
        NSApp.setActivationPolicy(.accessory)
        NSApp.hide(nil)
    }
    
    private func setupObservers() {
        let token = NSWorkspace.shared.observe(\.frontmostApplication, options: [.initial, .new]) { [weak self] _, _ in
            self?.handleApplicationChange()
        }
        observationTokens.append(token)
    }
    
    private func setupPermissions() {
        permissionsService.pollAccessibilityPrivileges()
    }
    
    // Play! ⚽️ ??
    private func setupEventMonitor() {
        eventMonitor = EventMonitor(keyboardManager: keyboardManager, contextProvider: contextProvider)
        
        eventMonitor?.start(
            onSpace: { [weak self] in
                self?.checkSpelling()
            },
            onEnter: { [weak self] in
                self?.contextProvider.flush()
            },
            onBackspace: { [weak self] in
            },
            onKeyCode: { _ in
            },
            onGlobeKey: { [weak self] (_: NSEvent.ModifierFlags) in
                self?.switchKeyboardLanguage()
            },
            onOptionLeft: { [weak self] in
                self?.switchKeyboardLanguage()
                self?.soundManager.play(soundName: "switch")
                self?.removeOld()
                self?.typeNew()
            },
            onOptionRight: { [weak self] in
                self?.checkSpelling()
            },
            onShiftChange: { [weak self] isPressed in
                self?.shift = isPressed
            }
        )
    }
    
    private func handleApplicationChange() {
        contextProvider.switchContext(
            ctx: NSWorkspace.shared.frontmostApplication!,
            currLang: currentLanguage
        )
        print("\(contextProvider.pull()) \(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "none")")
    }
    
    private func switchKeyboardLanguage() {
        keyboardManager.onLanguageChanged = { [weak self] (newSourceName: String) in
            guard let self = self else { return }
            if newSourceName == "ABC" {
                //self.statusBarItem?.button?.image = NSImage(systemSymbolName: "dollarsign", accessibilityDescription: nil)
                self.statusBarItem?.button?.title = keyboardManager.flag(code: "en") // 🇺🇸
                self.soundManager.play(soundName: "en")
            } else {
                //self.statusBarItem?.button?.image = NSImage(systemSymbolName: "rublesign", accessibilityDescription: nil)
                self.statusBarItem?.button?.title = keyboardManager.flag(code: "ru") // 🇷🇺
                self.soundManager.play(soundName: "ru")
            }
        }
        keyboardManager.switchLanguage()
    }
    
    private func typeNew() {
        for key in contextProvider.pull() {
            keyboardManager.simulateKeyPress(key)
        }
    }
    
    private func removeOld() {
        guard contextProvider.count() > 0 else { return }
        for _ in 1...contextProvider.count() {
            keyboardManager.simulateKeyPress(Int(keyboardManager.BACKSPACE))
        }
    }
    
    private func checkSpelling() {
        let lastWord = keyboardManager.getLastWord(from: contextProvider.pull())
        let spelling = spellChecker.checkAndSuggestCorrections(
            word: lastWord,
            languages: [currentLanguage]
        )
        print(spelling)
        self.variants = spelling[lastWord]
        guard let variants = variants, !variants.isEmpty else { return }
        soundManager.play(soundName: "misprint")
    }
    private func showSpellingMenu() {
        let corrMenu = NSMenu()
        for (index, suggestion) in self.variants!.enumerated() {
            let menuItem = NSMenuItem(title: suggestion, action: #selector(variantChosen(_:)), keyEquivalent: "")
            menuItem.tag = index
            corrMenu.addItem(menuItem)
        }
        statusBarItem?.popUpMenu(corrMenu)
    }
    
    @objc private func variantChosen(_ sender: NSMenuItem) {
        guard let word = variants?[sender.tag] else { return }
        
        print("VarCh: \(sender.tag) Var: \(word)")
        soundManager.play(soundName: "switch")
        
        for _ in 0..<contextProvider.count() {
            keyboardManager.simulateKeyPress(Int(keyboardManager.BACKSPACE))
        }
        
        for char in word {
            let (key, _) = keyboardManager.getKeyCode(for: char)
            if key != -1 {
                keyboardManager.simulateKeyPress(key)
            }
        }
        
        contextProvider.flush()
        keyboardManager.simulateKeyPress(Int(keyboardManager.SPACE))
    }
    
    @objc private func showPermissionWindow() {
        let promptFlag = kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString
        let myDict: CFDictionary = NSDictionary(dictionary: [promptFlag: true])
        AXIsProcessTrustedWithOptions(myDict)
        
        if AXIsProcessTrustedWithOptions(myDict) {
            print("AD: Access Granted")
        } else {
            print("AD: Access NOT Granted")
        }
    }
    
    @objc private func showAboutWindow() {
        aboutWindowManager.show()
    }
    
    @objc private func hideStatusBarIcon() {
        statusBarItem?.isVisible = false
        let userDefaults = UserDefaults.standard
        userDefaults.set(true, forKey: "hideStatusBarIcon")
        UserDefaults.standard.synchronize()
    }
    
    @objc private func exitAction() {
        NSApplication.shared.terminate(nil)
    }
}
