//
//  RecentLocationManager.swift
//  VAMOS
//
//  Created by Jason Keglovitz on 2/18/24.
//

import Foundation
import MapKit

class RecentLocationManager {
  private static let recentLocationsKey = "RecentLocations"

  static func saveLocation(_ mapItem: MKMapItem?) {
    guard let mapItem = mapItem else { return }
    let defaults = UserDefaults.standard
    
    do {
      let data = try NSKeyedArchiver.archivedData(withRootObject: mapItem, requiringSecureCoding: true)
      
      var locationsData = defaults.array(forKey: recentLocationsKey) as? [Data] ?? []
      
      // Avoid repeats/duplicates:
      // Find the first item that has the same coordinates and remove it from the list. It will pop to the top on .insert below
      let coordinate = mapItem.placemark.coordinate
      if let index = locationsData.firstIndex(where: { data -> Bool in
        guard let item = try? NSKeyedUnarchiver.unarchivedObject(ofClass: MKMapItem.self, from: data) else { return false }
        return item.placemark.coordinate.latitude == coordinate.latitude && item.placemark.coordinate.longitude == coordinate.longitude
      }) {
        locationsData.remove(at: index)
      }
      
      // Insert at the beginning of the array, and trim list
      let maxSavedLocationCount = 10
      locationsData.insert(data, at: 0)
      if locationsData.count > maxSavedLocationCount {
        locationsData.removeSubrange(maxSavedLocationCount...)
      }
      
      defaults.set(locationsData, forKey: recentLocationsKey)
    } catch {
      print("Error saving location. Failed to encode MKMapItem: \(error)")
    }
  }

  static func loadRecentLocations() -> [MKMapItem] {
    let defaults = UserDefaults.standard
    guard let locationsData = defaults.array(forKey: recentLocationsKey) as? [Data] else { return [] }
    
    return locationsData.compactMap { data in
      try? NSKeyedUnarchiver.unarchivedObject(ofClass: MKMapItem.self, from: data)
    }
  }
}

