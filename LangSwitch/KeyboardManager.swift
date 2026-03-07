//
//  KeyboardManager.swift
//  LangSwitch
//
//  Created by OpenCode Zen :: Big Pickle 2026
//

import AppKit
import Carbon

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
    func distance(of element: Element) -> Int? {
        guard let idx = firstIndex(of: element) else { return nil }
        return self.distance(from: startIndex, to: idx)
    }
}

final class KeyboardManager {
    let keyCodes: [Int] = [
        12, 13, 14, 15, 17, 16, 32, 34, 31, 35, 33, 30,
        0, 1, 2, 3, 5, 4, 38, 40, 37, 41, 39, 42,
        6, 7, 8, 9, 11, 45, 46, 43, 47
    ]
    
    private let keyen = "qwertyuiop[]asdfghjkl;'\\zxcvbnm,./"
    private let keyEN = "QWERTYUIOP[]ASDFGHJKL;'\\ZXCVBNM,.?"
    private var keyru = "йцукенгшщзхъфывапролджэёячсмитьбю/"
    private let keyRU = "ЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЁЯЧСМИТЬБЮ?"
    
    let longPressThreshold: TimeInterval = 0.2
    let GLOBE: UInt16 = 63
    let OPTION_LEFT: UInt16 = 58
    let OPTION_RIGHT: UInt16 = 61
    let BACKSPACE: UInt16 = 51
    let SHIFT_LEFT: UInt16 = 56
    let SHIFT_RIGHT: UInt16 = 60
    let SPACE: UInt16 = 49
    let ENTER: UInt16 = 36
    
    private(set) var currentLanguage: String = "en"
    private(set) var currentSource: String = "ABC"
    private(set) var isShiftPressed: Bool = false    
    private let flags: [[String]] = [
        ["English","en","🇺🇸"],["Русский","ru","🇷🇺"],["Deutsch", "de","🇩🇪"],["Français", "fr","🇫🇷"],["Español","es","🇪🇸"],
        ["Italiano","it","🇮🇹"],["Portuguese","pt","🇵🇹"],["Nederlands","nl","🇳🇱"],["Polski","pl","🇵🇱"],["Українська","uk","🇺🇦"],
        ["Čeština","cs","🇨🇿"],["Română","ro","🇷🇴"],["Magyar","hu","🇭🇺"],["Svenska","sv","🇸🇪"],["Dansk","da","🇩🇰"],
        ["Suomi","fi","🇫🇮"],["Norsk","no","🇳🇴"],["Ελληνικά","el","🇬🇷"],["Български","bg","🇧🇬"],
        ["Slovenčina","sk","🇸🇰"],["Hrvatski","hr","🇭🇷"],["Српски","sr","🇷🇸"],["Türkçe","tr","🇹🇷"],
    ]
    
    var onLanguageChanged: ((String) -> Void)?
    
    func flag(code: String) -> String {
        if let rowIndex = flags.firstIndex(where: { innerArray in
            return innerArray.count > 1 && innerArray[1] == code
        }) {
            print("Flag index: \(rowIndex)")
            return flags[rowIndex][2]
        } else {
            print("No flag found for '\(code)'")
            return "$"
        }
    }
    
    func simulateKeyPress(_ keyCode: Int) {
        var key = keyCode
        var shift = false
        
        if key > 128 {
            shift = true
            key -= 128
        }
        
        guard let src = CGEventSource(stateID: .hidSystemState) else { return }
        
        let shiftDownEvent = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(SHIFT_LEFT), keyDown: true)
        let shiftUpEvent = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(SHIFT_LEFT), keyDown: false)
        let keyDownEvent = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(key), keyDown: true)
        let keyUpEvent = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(key), keyDown: false)
        
        if shift { shiftDownEvent?.post(tap: .cghidEventTap) }
        keyDownEvent?.post(tap: .cghidEventTap)
        keyUpEvent?.post(tap: .cghidEventTap)
        if shift { shiftUpEvent?.post(tap: .cghidEventTap) }
    }
    
    func pressKey(_ keyCode: UInt16, withModifiers modifiers: CGEventFlags = .init()) {
        guard let src = CGEventSource(stateID: .hidSystemState) else { return }
        
        guard let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false) else {
            return
        }
        
        down.flags = modifiers
        up.flags = modifiers
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
    
    func getKeyCode(for character: Character) -> (keyCode: Int, needsShift: Bool) {
        if let pos = keyen.distance(of: character) {
            return (keyCodes[pos], false)
        }
        if let pos = keyru.distance(of: character) {
            return (keyCodes[pos], false)
        }
        if let pos = keyEN.distance(of: character) {
            return (keyCodes[pos], true)
        }
        if let pos = keyRU.distance(of: character) {
            return (keyCodes[pos], true)
        }
        return (-1, false)
    }
    
    func getKeyCodes(for word: String) -> [Int] {
        var codes: [Int] = []
        for char in word {
            let (key, needsShift) = getKeyCode(for: char)
            if key == -1 { continue }
            var code = key
            if needsShift { code |= 0x1000 }
            codes.append(code)
        }
        return codes
    }
    
    func getLastWord(from keyCodes: [Int]) -> String {
        var result = ""
        
        for code in keyCodes {
            if code == SPACE {
                return result
            }
            
            var shift = false
            let key = code > 128 ? code - 128 : code
            
            guard let pos = self.keyCodes.firstIndex(of: key) else {
                continue
            }
            
            if code > 128 { shift = true }
            
            if currentLanguage == "en" && !shift {
                result.append(keyen[pos])
            } else if currentLanguage == "en" && shift {
                result.append(keyEN[pos])
            } else if currentLanguage == "ru" && !shift {
                result.append(keyru[pos])
            } else if currentLanguage == "ru" && shift {
                result.append(keyRU[pos])
            }
        }
        
        return result
    }
    
    func switchLanguage() {
        guard let currentSource = TISCopyCurrentKeyboardInputSource()?.takeUnretainedValue() else {
            print("Failed to get current keyboard language.")
            return
        }
        
        guard let inputSources = getInputSources() as? [TISInputSource],
              !inputSources.isEmpty else {
            print("Failed to get keyboard languages.")
            return
        }
        
        guard let currentIndex = inputSources.firstIndex(where: { $0 == currentSource }) else {
            print("Failed to switch keyboard language.")
            return
        }
        
        let nextIndex = (currentIndex + 1) % inputSources.count
        let nextSource = inputSources[nextIndex]
        
        TISSelectInputSource(nextSource)
        
        let newSourceName = Unmanaged<CFString>.fromOpaque(
            TISGetInputSourceProperty(nextSource, kTISPropertyLocalizedName)
        ).takeUnretainedValue() as String
        
        if newSourceName == "ABC" {
            self.currentLanguage = "en"
        } else {
            self.currentLanguage = "ru"
        }
        
        self.currentSource = newSourceName
        onLanguageChanged?(newSourceName)
        print("Switched to: \(newSourceName)")
    }
    
    func getInputSources() -> [TISInputSource] {
        guard let inputSourceNSArray = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else {
            return []
        }
        
        return inputSourceNSArray.filter {
            $0.category == TISInputSource.Category.keyboardInputSource && $0.isSelectable
        }
    }
    
    func updateShiftState(isPressed: Bool) {
        self.isShiftPressed = isPressed
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

