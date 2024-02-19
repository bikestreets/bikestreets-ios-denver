//
//  SearchViewController.swift
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

final class SearchViewController: UIViewController {
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
  private let stateManager: StateManager
  private let sheetManager: SheetManager
  private var tableView: UITableView!
  
  /// Exists to debounce many search requests while typing. This helps avoid API overuse errors from Apple.
  private var searchTask: DispatchWorkItem?
  private var matchingItems: [TableItem] = []
  private var isSearchActive: Bool = false
  
  lazy var searchController: UISearchController = {
    return UISearchController(searchResultsController: nil)
  }()
  
  weak var delegate: LocationSearchDelegate?

  init(configuration: SearchConfiguration, stateManager: StateManager, sheetManager: SheetManager) {
    self.configuration = configuration
    self.stateManager = stateManager
    self.sheetManager = sheetManager
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  deinit {
    NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
    NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    isModalInPresentation = true
    
    // Header
    let headerLabel = UILabel()
    headerLabel.text = configuration.sheetTitle
    headerLabel.font = .preferredFont(forTextStyle: .title2, weight: .bold)
    
    view.addSubview(headerLabel)
    headerLabel.disableTranslatesAutoresizingMaskIntoConstraints()
    [
      headerLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
      headerLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
      headerLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8)
    ].activate()
    
    // TableView
    tableView = UITableView()
    view.addSubview(tableView)
    tableView.disableTranslatesAutoresizingMaskIntoConstraints()
    [
      tableView.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 2),
      tableView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
      tableView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
      tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
    ].activate()
    
    // SearchBar
    definesPresentationContext = true
    searchController.searchBar.placeholder = configuration.searchBarPlaceholder
    searchController.searchResultsUpdater = self
    searchController.searchBar.barStyle = .default
    searchController.searchBar.searchBarStyle = .minimal
    searchController.searchBar.showsCancelButton = false
    searchController.searchBar.returnKeyType = .done
    searchController.searchBar.backgroundColor = .systemBackground
    searchController.searchBar.layoutMargins = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
    
    tableView.tableHeaderView = searchController.searchBar
    
    // DismissButton
    configureDismissButton(action: #selector(dismissButtonClicked))
    
    // Keyboard Notifications
    NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame), name: UIResponder.keyboardWillHideNotification, object: nil)
    
    // Link up delegates
    tableView.delegate = self
    tableView.dataSource = self
    
    self.matchingItems = recentLocations
  }
  
  private var hasBeenPresented = false
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if !hasBeenPresented {
      hasBeenPresented = true
      // Doing this after this run loop finishes allows it to work.
      DispatchQueue.main.async {
        self.searchController.searchBar.becomeFirstResponder()
      }
    }
  }
  
  // https://www.hackingwithswift.com/example-code/uikit/how-to-adjust-a-uiscrollview-to-fit-the-keyboard
  @objc func keyboardWillChangeFrame(notification: NSNotification) {
    guard let keyboardValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }

    let keyboardScreenEndFrame = keyboardValue.cgRectValue
    let keyboardViewEndFrame = view.convert(keyboardScreenEndFrame, from: view.window)

    if notification.name == UIResponder.keyboardWillHideNotification {
        tableView.contentInset = .zero
    } else {
      tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: keyboardViewEndFrame.height - view.safeAreaInsets.bottom, right: 0)
    }

    tableView.scrollIndicatorInsets = tableView.contentInset
  }
  
  func didSelect(configuration: SearchConfiguration, location: SelectedLocation) {
    delegate?.didSelect(configuration: configuration, location: location)

    // Consider searching to be done.
    searchController.searchBar.endEditing(true)
    searchController.isActive = false
    
    // Dismiss on selection when not in initial state.
    switch configuration {
    case .newDestination, .newOrigin:
      sheetManager.dismiss(viewController: self, animated: true)
    case .initialDestination:
      // Only push direction preview from initial destination selection.
      let directionPreviewViewController = DirectionPreviewViewController(stateManager: stateManager, sheetManager: sheetManager)
      directionPreviewViewController.modalTransitionStyle = .crossDissolve
      self.sheetManager.present(
        directionPreviewViewController,
        animated: true,
        sheetOptions: .init(
          detents: [.small(), .medium(), .large()],
          selectedDetentIdentifier: .medium
        )
      )
      animateSelectedDetentIdentifier(to: .medium)
    }
  }
  
  func updateCanceledState() {
    switch stateManager.state {
    case .searchDestination:
      stateManager.state = .initial
    case .updateOrigin(preview: let preview), .updateDestination(preview: let preview):
      stateManager.state = .previewDirections(preview: preview)
    default:
      fatalError("Unexpected state")
    }
  }
  
  @objc func dismissButtonClicked() {
    searchController.isActive = false
    updateCanceledState()
    sheetManager.dismiss(viewController: self, animated: true)
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
  
  func mapSearchRegion() -> MKCoordinateRegion? {
    return delegate?.mapSearchRegion()
  }
}

// MARK: - UITableViewDataSource, UITableViewDelegate

extension SearchViewController: UITableViewDataSource, UITableViewDelegate {
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    matchingItems.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
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

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let item = matchingItems[indexPath.row]

    let selectedLocation: SelectedLocation = {
      switch item {
      case .currentLocation: return .currentLocation
      case .mapItem(let mapItem):
        RecentLocationManager.saveLocation(mapItem)
        return .mapItem(mapItem)
      }
    }()

    didSelect(configuration: configuration, location: selectedLocation)
    tableView.deselectRow(at: indexPath, animated: true)
  }
}

// MARK: - UISearchResultsUpdating

extension SearchViewController: UISearchResultsUpdating {
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

// MARK: - LocationSearchFilter

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

extension MKMapItem {
  func isNearby() -> Bool {
    return LocationSearchFilter.isNearby(mapItem: self)
  }
}
