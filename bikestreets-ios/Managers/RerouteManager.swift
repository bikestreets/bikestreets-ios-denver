//
//  RerouteManager.swift
//  VAMOS
//
//  Created by Jason Keglovitz on 2/29/24.
//

import Foundation
import CoreLocation

// TODO: Encapsulate RerouteManager inside StateManager
final class RerouteManager {
  enum State {
    case idle
    case rerouting
  }
  
  var location: CLLocation?
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
}

