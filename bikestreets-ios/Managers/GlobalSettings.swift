//
//  GlobalSettings.swift
//  VAMOS
//
//  Created by Matt Robinson on 1/5/24.
//

import Foundation

struct GlobalSettings {

  // MARK: -- Directions Preview

  enum DirectionsPreviewConfiguration {
    /// Show just the Mapbox Directions result on the directions preview screen.
    case mapbox
    /// Show both the OSRM and Mapbox result on the directions preview screen.
    case combined
  }

  static let directionsPreviewConfiguration: DirectionsPreviewConfiguration = .combined

  // MARK: -- Live Routing

  enum LiveRoutingConfiguration {
    /// Use Mapbox's built-in live navigation UI.
    case mapbox
    /// Use DIY BikeStreets navigation UI.
    case custom
  }

  static let liveRoutingConfiguration: LiveRoutingConfiguration = .mapbox
}
