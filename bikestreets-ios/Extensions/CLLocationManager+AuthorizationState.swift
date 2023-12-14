//
//  CLLocationManager+AuthorizationState.swift
//  BikeStreets
//
//  Created by Matt Robinson on 12/7/23.
//

import Foundation
import CoreLocation

extension CLLocationManager {
  enum InternalAuthorizationStatus {
    /// Application has not request permissions yet.
    case requestPermissions
    /// Application permissions need changed.
    case insufficientAuthorization
    /// Application permissions are acceptable.
    case granted
  }

  var internalAuthorizationStatus: InternalAuthorizationStatus {
    switch authorizationStatus {
    case .notDetermined: return .requestPermissions
    case .restricted, .denied: return .insufficientAuthorization
    case .authorizedAlways, .authorizedWhenInUse: return .granted
    @unknown default: return .insufficientAuthorization
    }
  }
}
