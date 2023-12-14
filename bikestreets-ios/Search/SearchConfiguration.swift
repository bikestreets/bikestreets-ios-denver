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

  var searchBarPlaceholder: String {
    switch self {
    case .initialDestination, .newDestination: return "Search for a destination"
    case .newOrigin: return "Search for a starting point"
    }
  }
}
