//
//  MapLayerSpec.swift
//  VAMOS
//
//  Created by Matt Robinson on 12/23/23.
//

import Foundation
import MapboxMaps
import Turf

/// Mapping of all the GeoJSON files that are stored in the root of the app bundle
/// to be used for drawing the Vamos network as a map overlay.
enum MapLayerSpec: String, CaseIterable {
  case bikestreets = "1-bikestreets-master-v0.3"
  case trails = "2-trails-master-v0.3"
  case bikelanes = "3-bikelanes-master-v0.3"
  case bikesidewalks = "4-bikesidewalks-master-v0.3"
  case walk = "5-walk-master-v0.3"

  private static let bikeStreetAlpha: CGFloat = 1.0

  // MARK: - Attributes

  private var rgb: Int {
    switch self {
    case .bikestreets:
      return 0x345AA8
    case .trails:
      return 0x7A8A47
    case .bikelanes:
      return 0x58595B
    case .bikesidewalks:
      return 0xE82E8B
    case .walk:
      return 0xD8282C
    }
  }

  var mapLayerColor: StyleColor {
    let color = UIColor(rgb: rgb, alpha: MapLayerSpec.bikeStreetAlpha)
    return StyleColor(color)
  }

  // MARK: - Helpers

  /// Identifier for the layer.
  var geoJSONDataSourceIdentifier: String {
    rawValue
  }

  /// File URL for the GeoJSON file in the main bundle.
  var fileURL: URL {
    guard let url = Bundle.main.url(forResource: rawValue, withExtension: "geojson") else {
      fatalError("Unable to find GeoJSON file for '\(self)'")
    }
    return url
  }

  // MARK: - Decoding

  /// Load GeoJSON file from local bundle and decode into a `FeatureCollection`.
  ///
  /// From: https://docs.mapbox.com/ios/maps/examples/line-gradient/
  func decodeGeoJSON() throws -> FeatureCollection? {
    var featureCollection: FeatureCollection?
    do {
      let data = try Data(contentsOf: fileURL)
      featureCollection = try JSONDecoder().decode(FeatureCollection.self, from: data)
    } catch {
      print("Error parsing data: \(error)")
    }
    return featureCollection
  }
}
