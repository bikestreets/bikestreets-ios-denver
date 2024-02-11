//
//  GlobalSettings.swift
//  VAMOS
//
//  Created by Matt Robinson on 1/5/24.
//

import Foundation

struct GlobalSettings {

  // MARK: -- Live Routing

  enum LiveRoutingConfiguration {
    /// Use Mapbox's built-in live navigation UI.
    case mapbox
    /// Use DIY BikeStreets navigation UI.
    case custom
  }

  static let liveRoutingConfiguration: LiveRoutingConfiguration = .mapbox
}
