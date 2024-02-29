//
//  RerouteManager.swift
//  VAMOS
//
//  Created by Jason Keglovitz on 2/29/24.
//

import Foundation

final class RerouteManager {
  enum State {
    case idle
    case rerouting
  }
  
  private var lastRerouteCompletionTime: Date? = Date()
  private let cooldownInterval: TimeInterval = 5.0 // wait at least 5 seconds before submitting another reroute request
  
  var state: State = .idle {
    didSet {
      if state == .idle {
        lastRerouteCompletionTime = Date()
      }
    }
  }
  
  var canRequestReroute: Bool {
    guard state == .idle else { return false }
    
    if let lastRerouteTime = lastRerouteCompletionTime,
       Date().timeIntervalSince(lastRerouteTime) < cooldownInterval {
        return false
    }
    return true
  }
}
