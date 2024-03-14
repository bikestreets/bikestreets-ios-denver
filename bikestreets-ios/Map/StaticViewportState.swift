//
//  StaticViewportState.swift
//  VAMOS
//
//  Created by Jason Keglovitz on 3/13/24.
//

import Foundation
import MapboxMaps

internal final class StaticViewportState: ViewportState {
  // This is a no-op ViewportState that stands in as a stub so that we can capture viewport transitions, for example, when previewing the route with NavigationMapView.showcase() which does not use OverviewViewportState
  func observeDataSource(with handler: @escaping (MapboxMaps.CameraOptions) -> Bool) -> MapboxMaps.Cancelable {
    return StaticCancelable()
  }
  
  func startUpdatingCamera() {
    // no-op
  }
  
  func stopUpdatingCamera() {
    // no-op
  }
}

internal final class StaticCancelable: MapboxMaps.Cancelable {
  func cancel() {
    // no-op
  }
}
