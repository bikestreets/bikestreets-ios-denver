//
//  DefaultMapsViewController.swift
//  BikeStreets
//
//  Created by Matt Robinson on 8/4/23.
//

import MapboxCoreNavigation
import MapboxDirections
import MapboxNavigation
import MapboxMaps
import MapboxSearchUI
import MapKit
import SwiftUI
import UIKit

final class DefaultMapsViewController: MapsViewController {
  private enum LiveRoutingConfiguration {
    case mapbox
    case custom
  }
  private let liveRoutingConfiguration: LiveRoutingConfiguration = .mapbox

  private lazy var mapControlView: MapControlView = {
    return MapControlView(mapCameraManager: mapCameraManager)
  }()
  private let sheetHeightInspectionView = SizeTrackingView()

  /// Retain the navigation view controller that presents the routing view.
  private var navigationViewController: NavigationViewController?

  private lazy var sheetManager: SheetManager = {
    SheetManager(rootViewController: self)
  }()

  private let stateManager = StateManager()
  private let mapCameraManager = MapCameraManager()
  private let screenManager: ScreenManager

  /// Camera bottom inset based on the presented sheet height.
  private var cameraBottomInset: CGFloat {
    (sheetHeightInspectionView.lastFrameBroadcast?.height ?? 0) + 24
  }

  init() {
    screenManager = ScreenManager(stateManager: stateManager)
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    view.addSubview(mapControlView)
    [
      mapControlView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
      mapControlView.bottomAnchor.constraint(equalTo: mapView.ornaments.logoView.topAnchor, constant: -16)
    ].activate()

    mapView.viewport.addStatusObserver(self)

    sheetManager.delegate = self

    sheetHeightInspectionView.delegate = self
    view.addSubview(self.sheetHeightInspectionView)

    stateManager.add(listener: self)
    mapCameraManager.add(listener: self)
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    attachHeightInspectorIfNeccessary()
  }

  private var attachedHeightInspector = false
  private func attachHeightInspectorIfNeccessary() {
    if !attachedHeightInspector {
      // Set up sheet height tracker.
      [
        sheetHeightInspectionView.leftAnchor.constraint(equalTo: view.leftAnchor),
        sheetHeightInspectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        sheetHeightInspectionView.rightAnchor.constraint(equalTo: view.rightAnchor),
        // Height is tracked on a per-sheet basis.
      ].activate()

      attachedHeightInspector = true
    }
  }

  private var hasAppeared = false
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    
    // Present the initial search view on initial appearance.
    if !hasAppeared {
      presentInitialSearchViewController()
      hasAppeared = true
    }
  }

  private func presentInitialSearchViewController() {
    let searchViewController = SearchViewController(
      configuration: .initialDestination,
      stateManager: stateManager,
      sheetManager: sheetManager
    )
    searchViewController.delegate = self

    sheetManager.present(
      searchViewController,
      animated: true,
      options: .init(shouldDismiss: false)
    )
  }

  private var heightInspectionConstraint: NSLayoutConstraint?
  private weak var heightInspectionViewController: UIViewController?
  private func inspectHeight(of viewController: UIViewController) {
    heightInspectionConstraint?.isActive = false

    heightInspectionConstraint = sheetHeightInspectionView.topAnchor.constraint(equalTo: viewController.view.topAnchor)
    heightInspectionConstraint?.isActive = true

    heightInspectionViewController = viewController
  }

  // MARK: - Map Movement

  // TODO: Make this smarter using approach from https://docs.mapbox.com/ios/maps/examples/line-gradient/
  private func updateMapAnnotations(
    isRouting: Bool,
    selectedRoute: MapboxDirections.Route,
    potentialRoutes: [MapboxDirections.Route]
  ) {
    let selectedRouteAnnotations: [PolylineAnnotation] = selectedRoute.legs.flatMap { leg -> [MapboxDirections.RouteStep] in
      leg.steps
    }.map { step -> PolylineAnnotation in
      return .activeRouteAnnotation(
        coordinates: step.shape?.coordinates ?? [],
        isRouting: isRouting,
        isHikeABike: step.transportType == .walking
      )
    }

    polylineAnnotationManager.annotations = selectedRouteAnnotations + potentialRoutes.map {
      .potentialRouteAnnotation(coordinates: $0.shape?.coordinates ?? [])
    }
  }

  // MARK: - State Handling

  private func requestDirections(request: StateManager.RouteRequest) {
    let startName: String
    let endName: String

    switch stateManager.state {
    case .requestingRoutes(let request):
      startName = request.origin.name
      endName = request.destination.name
    default:
      startName = "INCORRECT-STATE-FOR-NAME"
      endName = "INCORRECT-STATE-FOR-NAME"
    }

    RouteRequester.getOSRMDirections(
      originName: startName,
      startPoint: request.origin.coordinate,
      destinationName: endName,
      endPoint: request.destination.coordinate
    ) { result in
      switch result {
      case .success(let result):
        DispatchQueue.main.async {
          if let firstRoute = result.routes?.first {
            // On initial state update, assume first route is selected.
            self.stateManager.state = .previewDirections(
              preview: .init(request: request, response: result, selectedRoute: firstRoute)
            )
          } else {
            // TODO: Improve the state when a route is requested but returns no options.
            self.stateManager.state = .initial
          }
        }
      case .failure(let error):
        // TODO: Handle route request errors.
        print(error)
      }
    }
  }
}

// MARK: - State Management

extension DefaultMapsViewController: StateListener {
  /// Find the top-most presented view controller in the presented VC chain.
  private var topPresentedViewController: UIViewController? {
    var topController = self.presentedViewController
    while let newTopController = topController?.presentedViewController, !newTopController.isBeingDismissed {
      topController = newTopController
    }
    return topController
  }

  func didUpdate(from oldState: StateManager.State, to newState: StateManager.State) {
    switch newState {
    case .initial:
      // Assume routing was canceled. Restart from the initial launch state.
      if case .routing = oldState {
        sheetManager.dismissAllSheets(animated: true) {
          self.presentInitialSearchViewController()
        }
      }

      // Clean any annotations.
      polylineAnnotationManager.annotations = []
    case .requestingRoutes(let request):
      // Potentially show destination on map
      // showAnnotation(.init(item: mapItem), cameraShouldFollow: false)
      // Potentially shift to smaller sheet presentation
      // sheetNavigationController.sheetPresentationController?.selectedDetentIdentifier = UISheetPresentationController.Detent.small().identifier
      requestDirections(request: request)
    case .previewDirections(let preview):
      updateMapAnnotations(isRouting: false, selectedRoute: preview.selectedRoute, potentialRoutes: preview.response.routes ?? [preview.selectedRoute])
    case .updateDestination(let preview):
      let searchViewController = SearchViewController(
        configuration: .newDestination,
        stateManager: stateManager,
        sheetManager: sheetManager
      )
      searchViewController.delegate = self
      sheetManager.present(
        searchViewController,
        animated: true,
        options: .init(presentationControllerDidDismiss: { [weak self] in
          guard let self else { return }
          self.stateManager.state = .previewDirections(preview: preview)
        })
      )
    case .updateOrigin(let preview):
      let searchViewController = SearchViewController(
        configuration: .newOrigin,
        stateManager: stateManager,
        sheetManager: sheetManager
      )
      searchViewController.delegate = self
      sheetManager.present(
        searchViewController,
        animated: true,
        options: .init(presentationControllerDidDismiss: { [weak self] in
          guard let self else { return }
          self.stateManager.state = .previewDirections(preview: preview)
        })
      )
    case .routing(let routing):
      switch liveRoutingConfiguration {
      case .mapbox:
        // TODO: (@mattrob) This should be associated with the selected route not the `0` index.
        let indexedRouteResponse = IndexedRouteResponse(
          routeResponse: routing.response,
          routeIndex: 0
        )
        let navigationService = MapboxNavigationService(
          indexedRouteResponse: indexedRouteResponse,
          customRoutingProvider: NavigationSettings.shared.directions,
          credentials: NavigationSettings.shared.directions.credentials,
          simulating: .onPoorGPS
        )
        let navigationOptions = NavigationOptions(navigationService: navigationService)
        navigationViewController = NavigationViewController(
          for: indexedRouteResponse,
          navigationOptions: navigationOptions
        )
        navigationViewController?.modalPresentationStyle = .fullScreen
        navigationViewController?.delegate = self

        sheetManager.dismissAllSheets(animated: false) {
          self.present(self.navigationViewController!, animated: true, completion: nil)
        }
      case .custom:
        // Dismiss initial sheet, show routing sheet.
        sheetManager.dismissAllSheets(animated: true) { [weak self] in
          guard let self else { return }
          let viewController = RoutingViewController(stateManager: self.stateManager)
          self.sheetManager.present(
            viewController,
            animated: true,
            sheetOptions: .init(
              detents: [.tiny()],
              largestUndimmedDetentIdentifier: .tiny,
              prefersGrabberVisible: false
            ))
        }

        // Update route polyline display.
        updateMapAnnotations(isRouting: true, selectedRoute: routing.selectedRoute, potentialRoutes: [])
      }
    }

    // Sync up camera position/focus.
    mapCameraManager.state = {
      switch newState {
      case .initial, .requestingRoutes: return .followUserPosition
      case .previewDirections(let preview),
          .updateOrigin(let preview),
          .updateDestination(let preview):
        return .showRoute(route: preview.selectedRoute)
      case .routing: return .followUserHeading
      }
    }()

    // Disable BikeStreets network when routing.
    // TODO: Figure out if this is desired
    switch newState {
    case .routing:
      isBikeStreetsNetworkEnabled = false
    default:
      isBikeStreetsNetworkEnabled = true
    }
  }
}

// MARK: - SizeTrackingListener

extension DefaultMapsViewController: SizeTrackingListener {
  func didChangeFrame(_ view: UIView, frame: CGRect) {
    // This is only valuable for the height, if it's 0, ignore.
    guard frame.height != 0 else { return }

    // Find the likely selected sheet detent identifier.
    let selectedSheetDetentIdentifier: UISheetPresentationController.Detent.Identifier = (
      heightInspectionViewController?.sheetPresentationController?.selectedDetentIdentifier ?? .medium
    )

    // Adjust the map if we're not in the large selected detent.
    if selectedSheetDetentIdentifier != .large {
      // Update map camera.
      syncCameraState(bottomInset: frame.height)

      // Update Mapbox attribution.
      let mapboxOrnamentYInset = frame.height - 8
      mapView.ornaments.options.logo.margins = .init(x: 8.0, y: mapboxOrnamentYInset)
    }
  }
}

// MARK: - LocationSearchDelegate

extension DefaultMapsViewController: LocationSearchDelegate {
  func mapSearchRegion() -> MKCoordinateRegion? {
    var coordinates: [CLLocationCoordinate2D] = mapView.mapboxMap.coordinates(for: [
      CGPoint(x: mapView.frame.minX, y: mapView.frame.minY),
      CGPoint(x: mapView.frame.minX, y: mapView.frame.maxY),
      CGPoint(x: mapView.frame.maxX, y: mapView.frame.maxY),
      CGPoint(x: mapView.frame.maxX, y: mapView.frame.minY),
    ])


    let polygon = MKPolygon(coordinates: &coordinates, count: coordinates.count)
    let rect = polygon.boundingMapRect
    return MKCoordinateRegion(rect)
  }

  /// Return latest user location or fail if it cannot be found.
  private var userCurrentLocationOrFail: StateManager.RouteRequest.Location {
    guard let coordinate = mapView.location.latestLocation?.coordinate else {
      fatalError("No user location found")
    }
    return .currentLocation(coordinate: coordinate)
  }

  func didSelect(configuration: SearchConfiguration, location: SelectedLocation) {
    let origin: StateManager.RouteRequest.Location = {
      switch configuration {
      case .newOrigin:
        switch location {
        case .currentLocation:
          guard let coordinate = mapView.location.latestLocation?.coordinate else {
            fatalError("No user location found")
          }
          return .currentLocation(coordinate: coordinate)
        case .mapItem(let mapItem): return .mapLocation(item: mapItem)
        }
      case .initialDestination:
        guard let coordinate = mapView.location.latestLocation?.coordinate else {
          fatalError("No user location found")
        }
        return .currentLocation(coordinate: coordinate)
      case .newDestination:
        // Either pull the user's current location from the live location or the past request.
        switch stateManager.state {
        case .requestingRoutes(let request):
          switch request.origin {
          case .currentLocation:
            return userCurrentLocationOrFail
          case .mapLocation:
            return request.origin
          }
        case .previewDirections(let preview), .updateDestination(let preview):
          switch preview.request.origin {
          case .currentLocation:
            return userCurrentLocationOrFail
          case .mapLocation:
            return preview.request.origin
          }
        default:
          fatalError("No origin location found (likely no user location received)")
        }
      }
    }()

    let destination: StateManager.RouteRequest.Location = {
      switch configuration {
      case .initialDestination, .newDestination:
        switch location {
        case .currentLocation:
          return userCurrentLocationOrFail
        case .mapItem(let mapItem): return .mapLocation(item: mapItem)
        }
      case .newOrigin:
        switch stateManager.state {
        case .requestingRoutes(let request):
          return request.destination
        case .previewDirections(let preview), .updateOrigin(let preview):
          return preview.request.destination
        default:
          fatalError("Unable to select origin without a previous destination selected")
        }
      }
    }()

    stateManager.state = .requestingRoutes(
      request: .init(
        origin: origin,
        destination: destination
      )
    )
  }
}

// MARK: -- CompassStateListener

extension DefaultMapsViewController: MapCameraStateListener {
  func didUpdate(from oldState: MapCameraManager.State, to newState: MapCameraManager.State) {
    /// Force correction to normal view style for this mode. This will be expanded in
    /// the future to support more states of the camera.
    syncCameraState(bottomInset: cameraBottomInset)
  }

  func syncCameraState(bottomInset: CGFloat) {
    let newState: ViewportState?

    switch mapCameraManager.state {
    case .followUserPosition:
      newState = mapView.viewport.makeFollowPuckViewportState(
        options: FollowPuckViewportStateOptions(
          padding: UIEdgeInsets(top: 200, left: 0, bottom: bottomInset, right: 0),
          // Intentionally avoid bearing sync in search mode.
          bearing: .none,
          pitch: 0
        )
      )
    case .showRoute(let route):
      // Zoom to show a single route or all routes.
      let cameraTopInset: CGFloat = self.view.safeAreaInsets.top

      // TODO: Add handling for "possible routes" vs. just the selected route.
      // preview.response.routes.map(\.geometry.coordinates).flatMap { $0 }
      let coordinates: [CLLocationCoordinate2D] = route.shape?.coordinates ?? []

      newState = mapView.viewport.makeOverviewViewportState(
        options: .init(
          geometry: LineString(coordinates),
          padding: .init(top: cameraTopInset, left: 24, bottom: cameraBottomInset, right: 24)
        )
      )
    case .followUserHeading:
      newState = mapView.viewport.makeFollowPuckViewportState(
        options: FollowPuckViewportStateOptions(
          padding: UIEdgeInsets(top: 200, left: 0, bottom: bottomInset, right: 0),
          bearing: .heading,
          pitch: 0
        )
      )
    case .followUserPositionIdle,
        .followUserHeadingIdle,
        .showRouteIdle:
      // Idle, no viewport transition
      newState = nil
    }

    if let newState {
      mapView.viewport.transition(to: newState) { _ in
        // the transition has been completed with a flag indicating whether the transition succeeded
      }
    }
  }
}

// MARK: -- ViewportStatusObserver

extension DefaultMapsViewController: ViewportStatusObserver {
  func viewportStatusDidChange(
    from fromStatus: MapboxMaps.ViewportStatus,
    to toStatus: MapboxMaps.ViewportStatus,
    reason: MapboxMaps.ViewportStatusChangeReason
  ) {
    switch toStatus {
    case .idle:
      mapCameraManager.toIdle()
    case .state: break
    case .transition: break
    }
  }
}

// MARK: -- SheetManagerDelegate

extension DefaultMapsViewController: SheetManagerDelegate {
  func didUpdatePresentedViewController(_ presentedViewController: UIViewController) {
    // Adjust sheet sizing constraint to top-most presented VC. This is a less
    // than ideal way to ensure we get the top-most presented VC _after_ it has
    // been presented based on a state change. This could be refactored into
    // a more centralized approach to unify the handling of push/pop while
    // keeping internal catalog of the top-most VC.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
      guard let self = self else { return }
      self.inspectHeight(of: presentedViewController)
    }
  }
}

// MARK: -- DEBUG

extension DefaultMapsViewController {
  override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
    /// Intentionally avoid showing the debug TVC when routing. Having the phone
    /// on the handlebars generates lots of shakes that cause the app to crash.
    if case .routing = stateManager.state {
      return
    }

    if motion == .motionShake {
      let files = try! DebugLogHandler().files()
      sheetManager.present(DebugTableViewController(entries: files), animated: true)
    }
  }
}

// MARK: -- NavigationViewControllerDelegate

extension DefaultMapsViewController: NavigationViewControllerDelegate {
  func navigationViewController(
    _ navigationViewController: NavigationViewController,
    shouldRerouteFrom location: CLLocation
  ) -> Bool {
    false
  }

  func navigationViewControllerDidDismiss(
    _ navigationViewController: NavigationViewController,
    byCanceling canceled: Bool
  ) {
    self.navigationViewController = nil
    stateManager.state = .initial
  }
}
