//
//  LocationSearchTableViewController.swift
//  BikeStreets
//
//  Created by Matt Robinson on 8/4/23.
//

import Foundation
import MapKit
import UIKit

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
  private var matchingItems: [TableItem] = []
  private var isSearchActive: Bool = false

  weak var delegate: LocationSearchDelegate?

  let searchController = UISearchController(searchResultsController: nil)

  init(configuration: SearchConfiguration) {
    self.configuration = configuration

    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    self.matchingItems = recentLocations
    
    searchController.searchBar.placeholder = configuration.searchBarPlaceholder

    searchController.searchResultsUpdater = self
    searchController.hidesNavigationBarDuringPresentation = false

    // Configure search bar visual appearance
    searchController.searchBar.barStyle = .default
    searchController.searchBar.searchBarStyle = .minimal
  }

  // MARK: -- Helpers
  
  private var showCurrentLocation: Bool {
    switch configuration {
    case .initialDestination, .newDestination:
      return false
    case .newOrigin:
      return true
    }
  }
  
  private var recentLocations: [TableItem] {
    var locations: [TableItem] = RecentLocationManager.loadRecentLocations().map { .mapItem($0) }
    if showCurrentLocation {
      locations.insert(.currentLocation, at: 0)
    }
    return locations
  }
  
  private var showRecentLocations: Bool {
    return !isSearchActive && matchingItems.count > 0
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
    switch item {
    case .currentLocation:
      cell.imageView?.tintColor = .systemBlue
      cell.imageView?.image = UIImage(systemName: "location.fill")?.withRenderingMode(.alwaysTemplate)
    case .mapItem(_):
      cell.imageView?.tintColor = .label
      if showRecentLocations {
        cell.imageView?.image = UIImage(systemName: "clock")?.withRenderingMode(.alwaysTemplate)
      } else {
        cell.imageView?.image = UIImage(systemName: "mappin.and.ellipse")?.withRenderingMode(.alwaysTemplate)
      }
    }
    return cell
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let item = matchingItems[indexPath.row]

    let selectedLocation: SelectedLocation = {
      switch item {
      case .currentLocation: return .currentLocation
      case .mapItem(let mapItem):
        RecentLocationManager.saveLocation(mapItem)
        return .mapItem(mapItem)
      }
    }()

    delegate?.didSelect(configuration: configuration, location: selectedLocation)
    tableView.deselectRow(at: indexPath, animated: true)
  }
}

// MARK: - UISearchResultsUpdating

extension LocationSearchTableViewController: UISearchResultsUpdating {
  func updateSearchResults(for searchController: UISearchController) {
    guard let searchBarText = searchController.searchBar.text, !searchBarText.isEmpty else {
      // reset to initial state
      matchingItems = recentLocations
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
            self.matchingItems = response.mapItems.filter {
              $0.isNearby()
            }.map {
              .mapItem($0)
            }
            if self.showCurrentLocation {
              self.matchingItems.insert(.currentLocation, at: 0)
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

