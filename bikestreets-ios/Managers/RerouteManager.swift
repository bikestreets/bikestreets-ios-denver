//
//  RerouteManager.swift
//  VAMOS
//
//  Created by Jason Keglovitz on 2/29/24.
//

import Foundation
import CoreLocation
import AVFoundation

final class RerouteManager {
  enum State {
    case idle
    case rerouting
  }
  
  var location: CLLocation?
  private var audioPlayer: AVAudioPlayer?
  private var lastRerouteCompletionTime: Date? = Date()
  private let cooldownInterval: TimeInterval = 0.0 // initially thought we needed cooldown, but testing to see how this works with zero cooldown
  
  var state: State = .idle {
    didSet {
      if state == .idle {
        lastRerouteCompletionTime = Date()
      }
    }
  }
  
  var canRequestReroute: Bool {
    guard state == .idle else { return false }
    
    guard let lastRerouteCompletionTime else { return true }
    
    return Date().timeIntervalSince(lastRerouteCompletionTime) > cooldownInterval
  }
  
  init() {
    preloadAudioPlayer()
  }
  
  private func preloadAudioPlayer() {
    guard let soundURL = Bundle.main.url(forResource: "reroute", withExtension: "wav") else {
      print("Unable to locate audio file.")
      return
    }
    
    do {
      audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
      audioPlayer?.prepareToPlay()
    } catch {
      print("Failed to initialize the audio player: \(error.localizedDescription)")
    }
  }
  
  func playRerouteSound() {
    audioPlayer?.play()
  }
}
