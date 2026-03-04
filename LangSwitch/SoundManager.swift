//
//  SoundManager.swift
//  LangSwitch
//
//  Created by OpenCode Zen :: Big Pickle
//

import AVFoundation
import Foundation

final class SoundManager {
    private var soundPlayers: [String: AVAudioPlayer] = [:]
    
    init() {
        preloadSounds()
    }
    
    private func preloadSounds() {
        let soundNames = ["switch", "reverse", "misprint", "replace", "typerus", "typeeng", "ru", "en"]
        
        for name in soundNames {
            if let url = Bundle.main.url(forResource: name, withExtension: "wav") {
                do {
                    soundPlayers[name] = try AVAudioPlayer(contentsOf: url)
                    soundPlayers[name]?.prepareToPlay()
                } catch {
                    print("Error loading sound \(name): \(error)")
                }
            } else {
                print("Warning: Sound file \(name).wav not found")
            }
        }
    }
    
    func play(soundName: String) {
        guard let player = soundPlayers[soundName] else {
            print("Error: Sound \(soundName) not found")
            return
        }
        
        player.currentTime = 0
        player.play()
    }
    
    func setVolume(_ volume: Float) {
        soundPlayers.values.forEach { $0.volume = volume }
    }
}
