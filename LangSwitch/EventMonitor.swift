//
//  EventMonitor.swift
//  LangSwitch
//
//  Created by OpenCode Zen :: Big Pickle 2026
//

import AppKit

final class EventMonitor {
    typealias KeyHandler = (UInt16, Int, Bool) -> Void
    typealias FlagsHandler = (UInt16, NSEvent.ModifierFlags) -> Void
    
    private var keyDownMonitor: Any?
    private var flagsChangedMonitor: Any?
    private var mouseMonitor: Any?
    
    private let keyboardManager: KeyboardManager
    private let contextProvider: ContextProvider
    private var onSpace: (() -> Void)?
    private var onEnter: (() -> Void)?
    private var onBackspace: (() -> Void)?
    private var onKeyCode: ((Int) -> Void)?
    private var onGlobeKey: ((NSEvent.ModifierFlags) -> Void)?
    private var onOptionLeft: (() -> Void)?
    private var onOptionRight: (() -> Void)?
    private var onShiftChange: ((Bool) -> Void)?
    
    private var anotherClicked = false
    private var lastPressTime = Date()
    
    init(keyboardManager: KeyboardManager, contextProvider: ContextProvider) {
        self.keyboardManager = keyboardManager
        self.contextProvider = contextProvider
    }
    
    func start(
        onSpace: @escaping () -> Void,
        onEnter: @escaping () -> Void,
        onBackspace: @escaping () -> Void,
        onKeyCode: @escaping (Int) -> Void,
        onGlobeKey: @escaping (NSEvent.ModifierFlags) -> Void,
        onOptionLeft: @escaping () -> Void,
        onOptionRight: @escaping () -> Void,
        onShiftChange: @escaping (Bool) -> Void
    ) {
        self.onSpace = onSpace
        self.onEnter = onEnter
        self.onBackspace = onBackspace
        self.onKeyCode = onKeyCode
        self.onGlobeKey = onGlobeKey
        self.onOptionLeft = onOptionLeft
        self.onOptionRight = onOptionRight
        self.onShiftChange = onShiftChange
        
        startMonitoring()
    }
    
    private func startMonitoring() {
        keyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyDown(event)
        }
        
        flagsChangedMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }
    }
    
    func stop() {
        if let monitor = keyDownMonitor {
            NSEvent.removeMonitor(monitor)
            keyDownMonitor = nil
        }
        if let monitor = flagsChangedMonitor {
            NSEvent.removeMonitor(monitor)
            flagsChangedMonitor = nil
        }
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
    }
    
    private func handleKeyDown(_ event: NSEvent) {
        let code = Int(event.keyCode)
        
        if event.keyCode == keyboardManager.SPACE {
            contextProvider.push(code: code, shift: keyboardManager.isShiftPressed)
            contextProvider.markDirty()
            onSpace?()
            return
        }
        
        if event.keyCode == keyboardManager.ENTER {
            // clear buffer
            contextProvider.flush()
            onEnter?()
            return
        }
        
        if event.keyCode == keyboardManager.BACKSPACE {
            contextProvider.backspace()
            onBackspace?()
            return
        }
        
        if keyboardManager.keyCodes.contains(Int(event.keyCode)) {
            contextProvider.push(code: code, shift: keyboardManager.isShiftPressed)
            onKeyCode?(code)
        }
    }
    
    private func handleFlagsChanged(_ event: NSEvent) {
        if event.keyCode == keyboardManager.GLOBE && 
           event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.function) {
            anotherClicked = false
            lastPressTime = Date()
        }
        
        if !event.modifierFlags.intersection([.shift, .control, .option, .command]).isEmpty {
            anotherClicked = true
        }
        
        if event.keyCode == keyboardManager.GLOBE &&
            !anotherClicked &&
            event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty {
            let timePassed = Date().timeIntervalSince(lastPressTime)
            if timePassed < keyboardManager.longPressThreshold {
                onGlobeKey?(event.modifierFlags)
            }
        }
        
        if [keyboardManager.SHIFT_LEFT, keyboardManager.SHIFT_RIGHT].contains(event.keyCode) {
            let isShiftPressed = event.modifierFlags.rawValue != 256
            keyboardManager.updateShiftState(isPressed: isShiftPressed)
            onShiftChange?(isShiftPressed)
        }
        
        if event.keyCode == keyboardManager.OPTION_LEFT && event.modifierFlags.rawValue == 256 {
            onOptionLeft?()
        }
        
        if event.keyCode == keyboardManager.OPTION_RIGHT && event.modifierFlags.rawValue == 256 {
            onOptionRight?()
        }
    }
    
    deinit {
        stop()
    }
}
