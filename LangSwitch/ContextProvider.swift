//
//  ContextProvider.swift
//  LangSwitch
//
//  Created by Zadorozhko Ilia on 15.07.2025.
//
import AppKit
internal class ContextProvider {
    var currentContext:String? = "";
    var ctxLang:[String:String] = [:];
    var dirty:[String:Bool] = [:];
    var scancodes:[String:[Int]] = [:]; /* ["app1"] => [5,7,10,4], ["app2"] => [] */
    // For debug only - this logic is in AppDelegate
    let keyCodes = [12,13,14,15,17,16,32,34,31,35,33,30, /* qwertyuiop[] */
                    0,1,2,3,5,4,38,40,37,41,39,42,       /* asdfghjkl;'\ */
                    6,7,8,9,11,45,46,43,47];             /* zxcvbnm,.  56,60 - L/R Shift */
    let keyen = "qwertyuiop[]asdfghjkl;'\\zxcvbnm,./±"; //Last char is a placeholder for "notfound"
    
    func debugPrint(){
        print("\(self.pull()) \(self.pullStr()) \(currentContext ?? "no_ctx")")
    }
    func pullStr() -> String {
        var str:String = "";
        for c in self.pull() {
            str.append(keyen[keyCodes.firstIndex(of: c) ?? 36])
        }
        return str;
    }
    func push(code:Int, shift:Bool){
        if isDirty() {
            flush();
            self.dirty[self.currentContext!] = false;
        }
        let scode = shift ? (code + 128) : code;
        appendValue(forKey: currentContext ?? "none", value: scode);
        self.debugPrint()
    }
    func pull() -> [Int] {
        if let codes = scancodes[self.currentContext ?? "none"] {
            return codes;
        } else {
            return [];
        }
    }
    func count() -> Int {
        if let codes = scancodes[self.currentContext ?? "none"] {
            return codes.count;
        } else {
            return 0;
        }
    }
    func isDirty() -> Bool { //Dirty logic: Space or Enter pressed, last chance to convert. Next char will clear buffer
        if (self.currentContext == nil) || (self.currentContext == "") {
            self.currentContext = "none"; // Repair broken buffer
            return false;
        }
        return self.dirty[self.currentContext!] ?? false;
    }
    
    func markDirty(){
        self.dirty[self.currentContext!] = true;
    }
    
    func switchContext(ctx:NSRunningApplication, currLang:String){ //called on focus change
        ctxLang[self.currentContext ?? "none"] = currLang; // save prev ctx lang
        self.currentContext = ctx.bundleIdentifier;        // get new ctx
    }
    
    func backspace(){
        if var existingValues = scancodes[self.currentContext!] {
            if(existingValues.count > 0) {
                existingValues.removeLast();
                scancodes[self.currentContext!] = existingValues
            }
        } // else context not exists !!!
        self.debugPrint()
    }
    
    func flush(){
        scancodes[self.currentContext!] = []; //TODO: drop scancodes app element
    }
    
    func appendValue(forKey key: String, value: Int) {
        if var existingValues = scancodes[key] {
            existingValues.append(value)
            scancodes[key] = existingValues
        } else {
            scancodes[key] = [value]
        }
    }
}
