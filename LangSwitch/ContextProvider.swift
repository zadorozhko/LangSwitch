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
    
    func push(code:Int){
        if isDirty() {
            flush();
            self.dirty[self.currentContext!] = false;
        }
        appendValue(forKey: currentContext ?? "none", value: code);
        print("\(self.pull()) \(currentContext ?? "no")")
    }
    func pull() -> [Int] {
        if let codes = scancodes[self.currentContext!] {
            return codes;
        } else {
            return [];
        }
    }
    func count() -> Int {
        if let codes = scancodes[self.currentContext!] {
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
