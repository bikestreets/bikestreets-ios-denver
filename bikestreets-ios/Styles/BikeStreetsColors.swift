//
//  BikeStreetsColors.swift
//  BikeStreets
//
//  Created by Matt Robinson on 8/11/23.
//

import Foundation
import UIKit

extension UIColor {
  static let vamosBlue = UIColor(red: 53.0 / 255.0, green: 90.0 / 255.0, blue: 168.0 / 255.0, alpha: 1)
  static let vamosPurple = UIColor(red: 151.0 / 255.0, green: 27.0 / 255.0, blue: 138.0 / 255.0, alpha: 1)
  static let vamosYellow = UIColor(
    red: 254.0 / 255.0,
    green: 205.0 / 255.0,
    blue: 59.0 / 255.0,
    alpha: 1
  )
  
  // colors eye-dropper pulled from Apple Maps
  static let directionsPreviewBackgroundColor = UIColor { traitCollection in
      switch traitCollection.userInterfaceStyle {
      case .dark:
          return UIColor(rgb: 0x25272C)
      default:
          return UIColor(rgb: 0xF6F6F4)
      }
  }
  
  static let accessoryButtonTintColor = UIColor { traitCollection in
      switch traitCollection.userInterfaceStyle {
      case .dark:
          return UIColor(rgb: 0xA3A4Ad)
      default:
          return UIColor(rgb: 0x818085)
      }
  }
  
  static let accessoryButtonBackgroundColor = UIColor { traitCollection in
      switch traitCollection.userInterfaceStyle {
      case .dark:
          return UIColor(rgb: 0x393B3F)
      default:
          return UIColor(rgb: 0xe7e6e7)
      }
  }
}

