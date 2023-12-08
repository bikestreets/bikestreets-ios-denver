//
//  CLLocationManager+AuthorizationState.swift
//  BikeStreets
//
//  Created by Matt Robinson on 12/7/23.
//

import Foundation
import CoreLocation

extension CLLocationManager {
  var shouldPresentShareLocationView: Bool {
    switch authorizationStatus {
    case .notDetermined, .restricted, .denied:
      return true
    case .authorizedWhenInUse, .authorizedAlways:
      return false
    @unknown default:
      return false
    }
  }
}
