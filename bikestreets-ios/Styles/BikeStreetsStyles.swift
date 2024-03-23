//
//  BikeStreetsStyles.swift
//  BikeStreets
//
//  Created by Matt Robinson on 7/25/23.
//

import Foundation
import MapboxMaps
import MapboxNavigation
import UIKit

// MARK: - Map Styles

extension StyleURI {
  /// Avi's custom map style designed to minimize highway prevalence.
  /// This style started out as `.streets` with customizations.
  static let vamosStreets = StyleURI(
    rawValue: "mapbox://styles/mkbitbucket/clqgwgexa007s01rjhxpwcpaw"
  )!
  
  static let vamosStreetsLight = StyleURI(
    rawValue: "mapbox://styles/mkbitbucket/cltt4qtxa01lx01o80ujx0dvl"
  )!
  
  static let vamosStreetsDark = StyleURI(
    rawValue: "mapbox://styles/mkbitbucket/cltt4wy2g01l801oic0udggc7"
  )!
}

/// Day style used by NavigationViewController for light mode and day hours.
/// Will be used in day hours with dark mode enabled unless NavigationViewController.usesNightStyleInDarkMode is true
/// Additional UIView.appearance modifications can be made in apply(). See CustomStyleUIElements class in Mapbox's Navigation-Examples project for extensive examples.
class VamosDayStyle: DayStyle {
  required init() {
    super.init()
    mapStyleURL = URL(string: StyleURI.vamosStreetsLight.rawValue)!
    styleType = .day
  }
  
}

/// Night style used by NavigationViewController for dark mode, night hours, and tunnels.
/// Additional UIView.appearance modifications can be made in apply(). See CustomStyleUIElements class in Mapbox's Navigation-Examples project for extensive examples.
class VamosNightStyle: NightStyle {
  required init() {
    super.init()
    mapStyleURL = URL(string: StyleURI.vamosStreetsDark.rawValue)!
    styleType = .night
  }
  
}

// MARK: -

extension UIColor {
  /**
   * Convenience initalizer for creating a color from R, G, & B hex values
   *
   * Usage: let color = UIColor(red: 0xFF, green: 0xFF, blue: 0xFF)
   */
  convenience init(red: Int, green: Int, blue: Int, alpha: CGFloat = 1.0) {
    assert(red >= 0 && red <= 255, "Invalid red component")
    assert(green >= 0 && green <= 255, "Invalid green component")
    assert(blue >= 0 && blue <= 255, "Invalid blue component")

    self.init(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: alpha)
  }

  /**
   * Convenience initalizer for creating a color from an RGB Hex value
   *
   * Usage: let color = UIColor(rgb: 0xFFFFFF)
   */
  convenience init(rgb: Int, alpha: CGFloat = 1.0) {
    self.init(red: (rgb >> 16) & 0xFF,
              green: (rgb >> 8) & 0xFF,
              blue: rgb & 0xFF,
              alpha: alpha)
  }
}

/**
 * List of available map styles, which are URLs in mapbox. List of available styles here: https://docs.mapbox.com/api/maps/#styles
 */
enum BikeStreetsMapTypes {
  static let bikeStreets = Bundle.main.url(forResource: "bike streets map style", withExtension: "json")
  static let street = URL(string: "mapbox://styles/mapbox/streets-v11")
  static let satellite = URL(string: "mapbox://styles/mapbox/satellite-v9")
  static let satelliteWithLabels = URL(string: "mapbox://styles/mapbox/satellite-streets-v9")
}

/**
 * Style elements for Bike Streets
 */
enum BikeStreetsStyles {
  // Use `NSExpression` to smoothly adjust the line width from 2pt to 20pt between zoom levels 14 and 18. The `interpolationBase` parameter allows the values to interpolate along an exponential curve.
  private static let lineWidth: Value<Double> = .expression(
    Exp(.interpolate) {
      Exp(.linear)
      Exp(.zoom)
      14
      2
      18
      8
    }
  )

  /// From: https://docs.mapbox.com/ios/maps/examples/line-gradient/
  static func style(
    forLayer layerName: String,
    source: String,
    lineColor: StyleColor,
    lineWidth: Value<Double> = BikeStreetsStyles.lineWidth
  ) -> LineLayer {
    var lineLayer = LineLayer(id: layerName /* "line-layer" */ )
    lineLayer.filter = Exp(.eq) {
      "$type"
      "LineString"
    }

    // Setting the source
    lineLayer.source = source

    // Set the line join and cap to a rounded end.
    lineLayer.lineJoin = .constant(.round)
    lineLayer.lineCap = .constant(.round)

    lineLayer.lineColor = .constant(lineColor)
    lineLayer.lineWidth = lineWidth

    return lineLayer
  }
}
