//
//  RouteAudioManager.swift
//  VAMOS
//
//  Created by Jason Keglovitz on 3/21/24.
//

import Foundation
import AVFoundation
import MapboxNavigation
import MapboxDirections

final class RouteAudioManager: NSObject {
  private var audioPlayer: AVAudioPlayer
  private var speechSynthesizer: SpeechSynthesizing
  
  public init(speechSynthesizer: SpeechSynthesizing) {
    self.speechSynthesizer = speechSynthesizer
    audioPlayer = try! AVAudioPlayer(contentsOf: Bundle.main.url(forResource: "reroute", withExtension: "wav")!)
    super.init()
    
    self.speechSynthesizer.managesAudioSession = false
    self.speechSynthesizer.delegate = self
    
    audioPlayer.delegate = self
    AVAudioSession.sharedInstance().tryIdleAudio()
  }
  
  deinit {
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }
  
  func playRerouteSound() {
    guard !speechSynthesizer.muted else { return }
    
    speechSynthesizer.stopSpeaking()
    AVAudioSession.sharedInstance().tryActiveAudio()
    audioPlayer.currentTime = 0
    audioPlayer.prepareToPlay()
    audioPlayer.play()
  }
}

// MARK: AVAudioPlayerDelegate

extension RouteAudioManager: AVAudioPlayerDelegate {
  func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    // Note: this does not get called if the sound is interrupted, by speechSynthesizer, for instance.
    AVAudioSession.sharedInstance().tryIdleAudio()
  }
}

// MARK: SpeechSynthesizingDelegate

extension RouteAudioManager: SpeechSynthesizingDelegate {
  func speechSynthesizer(_ speechSynthesizer: SpeechSynthesizing, willSpeak instruction: SpokenInstruction) -> SpokenInstruction? {
    AVAudioSession.sharedInstance().tryActiveAudio()
    return instruction
  }
  
  func speechSynthesizer(_ speechSynthesizer: SpeechSynthesizing, didSpeak instruction: SpokenInstruction, with error: SpeechError?) {
    AVAudioSession.sharedInstance().tryIdleAudio()
  }
}

// MARK: AVSession Handling

extension AVAudioSession {
  func tryActiveAudio() {
    do {
      try setActive(false, options: .notifyOthersOnDeactivation)
      try setCategory(.playback, options: [.duckOthers, .mixWithOthers])
      try setActive(true)
    } catch {
      print("AVAudioSession.tryActiveAudio failed: \(error)")
    }
  }
  
  func tryIdleAudio() {
    do {
      try setActive(false, options: .notifyOthersOnDeactivation)
      try setCategory(.ambient, options: .mixWithOthers)
      try setActive(true)
    } catch {
      print("AVAudioSession.tryIdleAudio failed: \(error)")
    }
  }
}
