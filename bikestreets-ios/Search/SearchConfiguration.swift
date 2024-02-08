//
//  SearchConfiguration.swift
//  BikeStreets
//
//  Created by Matt Robinson on 8/25/23.
//

import Foundation

enum SearchConfiguration {
  case initialDestination
  case newDestination
  case newOrigin

  // MARK: -- Helpers

  var sheetTitle: String {
    switch self {
    case .initialDestination, .newDestination: return "Set Your Destination"
    case .newOrigin: return "Set Your Starting Point"
    }
  }

  var searchBarPlaceholder: String {
    switch self {
    case .initialDestination, .newDestination: return "Search for a Destination"
    case .newOrigin: return "Search for a Starting Point"
    }
  }
}
