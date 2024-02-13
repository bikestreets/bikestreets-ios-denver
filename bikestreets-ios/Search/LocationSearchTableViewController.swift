//
//  LocationSearchTableViewController.swift
//  BikeStreets
//
//  Created by Matt Robinson on 8/4/23.
//

import Foundation
import MapKit
import UIKit

enum SelectedLocation {
  case currentLocation
  case mapItem(MKMapItem)
}

protocol LocationSearchDelegate: AnyObject {
  // MARK: -- Searching

  func mapSearchRegion() -> MKCoordinateRegion?

  // MARK: -- Selection

  func didSelect(configuration: SearchConfiguration, location: SelectedLocation)
}

final class LocationSearchTableViewController: UITableViewController {
  private enum TableItem {
    case currentLocation
    case mapItem(MKMapItem)

    // MARK: -- Helpers

    var textLabel: String {
      switch self {
      case .currentLocation: return "Current Location"
      case .mapItem(let mapItem): return mapItem.name ?? "No Name"
      }
    }

    var detailLabel: String? {
      switch self {
      case .currentLocation: return nil
      case .mapItem(let mapItem): return mapItem.placemark.prettyAddress
      }
    }
  }

  private let configuration: SearchConfiguration

  /// Exists to debounce many search requests while typing. This helps avoid API overuse errors from Apple.
  private var searchTask: DispatchWorkItem?
  private var matchingItems: [TableItem]
  private var initialMatchingItems: [TableItem]
  private var isSearchActive: Bool = false

  weak var delegate: LocationSearchDelegate?

  let searchController = UISearchController(searchResultsController: nil)

  init(configuration: SearchConfiguration) {
    self.configuration = configuration

    self.initialMatchingItems = {
      switch configuration {
      case .initialDestination, .newDestination: return RecentLocationManager.loadRecentLocations().map { .mapItem($0) }
      case .newOrigin: return [.currentLocation]
      }
    }()
    
    self.matchingItems = initialMatchingItems

    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    searchController.searchBar.placeholder = configuration.searchBarPlaceholder

    searchController.searchResultsUpdater = self
    searchController.hidesNavigationBarDuringPresentation = false

    // Configure search bar visual appearance
    searchController.searchBar.barStyle = .default
    searchController.searchBar.searchBarStyle = .minimal
    
    // Dynamically hiding/showing a section header -- this keeps the top position of the table content relatively the same
    tableView.sectionHeaderTopPadding = 0
  }

  // MARK: -- Helpers

  private var showRecentLocations: Bool {
    switch configuration {
    case .initialDestination, .newDestination:
      // search is not active and there's at least 1 recent location to show
      return !isSearchActive && matchingItems.count > 0
    case .newOrigin:
      return false
    }
  }
}

// MARK: - UITableView

extension LocationSearchTableViewController {
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    matchingItems.count
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "cell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "cell")

    let item = matchingItems[indexPath.row]
    cell.textLabel?.text = item.textLabel
    cell.detailTextLabel?.text = item.detailLabel

    return cell
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let item = matchingItems[indexPath.row]

    let selectedLocation: SelectedLocation = {
      switch item {
      case .currentLocation: return .currentLocation
      case .mapItem(let mapItem):
        switch self.configuration {
        case .initialDestination, .newDestination:
          RecentLocationManager.saveLocation(mapItem)
        case .newOrigin: break
        }
        
        return .mapItem(mapItem)
      }
    }()

    delegate?.didSelect(configuration: configuration, location: selectedLocation)
    tableView.deselectRow(at: indexPath, animated: true)
  }
  
  override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    guard showRecentLocations else { return 0 }
    return UITableView.automaticDimension
  }
  
  override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    guard showRecentLocations else { return nil }
    
    let headerView = UITableViewHeaderFooterView()
    headerView.textLabel?.text = "Recent"
    headerView.textLabel?.font = .preferredFont(forTextStyle: .callout, weight: .bold)
    return headerView
  }
}

// MARK: - UISearchResultsUpdating

extension LocationSearchTableViewController: UISearchResultsUpdating {
  func updateSearchResults(for searchController: UISearchController) {
    guard let searchBarText = searchController.searchBar.text, !searchBarText.isEmpty else {
      // reset to initial state
      matchingItems = initialMatchingItems
      isSearchActive = false
      tableView.reloadData()
      return
    }

    isSearchActive = true
    // Invalidate and reinitiate
    self.searchTask?.cancel()

    let task = DispatchWorkItem { [weak self] in
      DispatchQueue.main.async { [weak self] in
        guard let self = self else { return }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchBarText
        if let searchRegion = self.delegate?.mapSearchRegion() {
          request.region = searchRegion
        }
        let search = MKLocalSearch(request: request)
        search.start { response, _ in
          guard let response = response else {
            return
          }
          DispatchQueue.main.async {
            let initialLocations: [TableItem] = {
              switch self.configuration {
              case .initialDestination, .newDestination: return []
              case .newOrigin: return [.currentLocation]
              }
            }()
            
            self.matchingItems = initialLocations + response.mapItems.filter {
              $0.isNearby()
            }.map {
              .mapItem($0)
            }
            self.tableView.reloadData()
          }
        }
      }
    }

    self.searchTask = task

    // Wait 0.25 seconds before executing search to debounce typing
    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.25, execute: task)
  }
}

extension MKMapItem {
  func isNearby() -> Bool {
    return LocationSearchFilter.isNearby(mapItem: self)
  }
}

class LocationSearchFilter {
  // Union Station, Denver, CO
  static private let center = CLLocation(latitude: 39.752928, longitude: -104.999826)
  static private let maxDistanceInMiles: Double = 14
  static private let maxDistanceInMeters = Measurement(value: maxDistanceInMiles, unit: UnitLength.miles).converted(to: UnitLength.meters).value
  
  static func isNearby(mapItem: MKMapItem) -> Bool {
    let mapItemLocation = CLLocation(latitude: mapItem.placemark.coordinate.latitude, longitude: mapItem.placemark.coordinate.longitude)
    let distance = center.distance(from: mapItemLocation)
    return distance <= maxDistanceInMeters
  }
}

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

