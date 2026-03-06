//
//  AboutWindowManager.swift
//  LangSwitch
//
//  Created by OpenCode Zen :: Big Pickle 2026
//

import AppKit
import SwiftUI

@available(macOS 12.0, *)
final class AboutWindowManager {
    private var window: NSWindow?
    
    func show() {
        if window == nil { //TODO: On second call to About it fails here with EXC_BAD_ACCESS
            createWindow()
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    var compileDate:Date
    {
        let bundleName = Bundle.main.infoDictionary!["CFBundleName"] as? String ?? "Info.plist"
        if let infoPath = Bundle.main.path(forResource: bundleName, ofType: nil),
           let infoAttr = try? FileManager.default.attributesOfItem(atPath: infoPath),
           let infoDate = infoAttr[FileAttributeKey.creationDate] as? Date
        { return infoDate }
        return Date()
    }
    
    private func createWindow() {
        let windowWidth: CGFloat = 460
        let windowHeight: CGFloat = 180
        
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = compileDate.formatted()
        
        let aboutView = AboutView(
            version: version,
            build: build,
            onGitHubClick: { [weak self] in self?.openGitHub() },
            onCheckUpdatesClick: { [weak self] in self?.checkForUpdates() }
        )
        
        let hostingView = NSHostingView(rootView: aboutView)
        hostingView.frame = NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight)
        
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window?.contentView = hostingView
        window?.center()
    }
    
    private func openGitHub() {
        if let url = URL(string: "https://github.com/zadorozhko/LangSwitch") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func checkForUpdates() {
        guard let url = URL(string: "https://api.github.com/repos/zadorozhko/LangSwitch/releases/latest") else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let data = data, error == nil else {
                self?.showAlert(message: "Failed to check for updates.")
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let latestVersion = json["tag_name"] as? String {
                    let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
                    
                    if latestVersion > "v\(currentVersion)" {
                        self?.showAlert(message: "New version \(latestVersion) is available! Download it from GitHub.")
                    } else {
                        self?.showAlert(message: "You're up to date.")
                    }
                }
            } catch {
                self?.showAlert(message: "Error parsing update information.")
            }
        }.resume()
    }
    
    private func showAlert(message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = message
            alert.runModal()
        }
    }
}

struct AboutView: View {
    let version: String
    let build: String
    let onGitHubClick: () -> Void
    let onCheckUpdatesClick: () -> Void
    
    var body: some View {
        VStack(spacing: 15) {
            Text("LangSwitch v\(version)-\(build)")
                .font(.system(size: 16, weight: .medium))
            
            Button("GitHub Page") {
                onGitHubClick()
            }
            .buttonStyle(.bordered)
            
            Button("Check for Updates") {
                onCheckUpdatesClick()
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}
