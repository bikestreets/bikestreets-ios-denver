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
import MessageUI
import SwiftUI
import UIKit
  
final class DefaultMapsViewController: MapsViewController {
  private let locationManager = CLLocationManager()

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
  private var viewportTransitionFailureCount = 0
  private let rerouteManager = RerouteManager()

  /// Camera bottom inset based on the presented sheet height.
  private var cameraBottomInset: CGFloat {
    (sheetHeightInspectionView.lastFrameBroadcast?.height ?? 0) + 24
  }

  override init() {
    screenManager = ScreenManager(stateManager: stateManager)
    super.init()
    subscribeForNotifications()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  deinit {
    unsubscribeFromNotifications()
  }
  
  // MARK: - Notifications observer methods
  
  func subscribeForNotifications() {
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(progressDidChange(_:)),
                                           name: .routeControllerProgressDidChange,
                                           object: nil)
  }
  
  func unsubscribeFromNotifications() {
    NotificationCenter.default.removeObserver(self,
                                              name: .routeControllerProgressDidChange,
                                              object: nil)
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    view.addSubview(mapControlView)
    [
      mapControlView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8),
      mapControlView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8)
    ].activate()

    mapView.viewport.addStatusObserver(self)

    locationManager.delegate = self
    sheetManager.delegate = self

    sheetHeightInspectionView.delegate = self
    view.addSubview(self.sheetHeightInspectionView)

    stateManager.add(listener: self)
    mapCameraManager.add(listener: self)

    // Configure initial state. Intentionally force
    // user to accept terms on each launch until we
    // decide otherwise.
    DispatchQueue.main.async {
      self.stateManager.state = .initialTerms
    }
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
    // Only show search sheet after terms and location accepted.
    switch stateManager.state {
    case .initialTerms,
        .requestingLocationPermissions,
        .insufficientLocationPermissions: return
    default: break
    }

    let initialViewController = SearchLegendViewController(
      stateManager: stateManager
    )

    sheetManager.present(
      initialViewController,
      animated: true,
      sheetOptions: .init(
        detents: [.tiny(), .medium()],
        selectedDetentIdentifier: .medium
      ),
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
  private func updateMapAnnotations(routes: [MapboxDirections.Route]?) {
    let geoJSONDataSourceIdentifier = "current-route"
    let geoJSONDataSourceIdentifierOSRM = "current-route-osrm"

    func removeLayer(withId identifier: String) {
      if mapView.mapboxMap.style.layerExists(withId: identifier) {
        try! mapView.mapboxMap.style.removeLayer(withId: identifier)
        try! mapView.mapboxMap.style.removeSource(withId: identifier)
      }
    }

    func addLayer(
      withIdentifier identifier: String,
      color: UIColor,
      route: MapboxDirections.Route,
      layerPosition: LayerPosition
    ) {
      guard let routeGeometry = route.shape?.geometry else {
        return
      }

      // Create a GeoJSON data source.
      var geoJSONSource = GeoJSONSource()
      geoJSONSource.data = .geometry(routeGeometry)

      let lineLayer = BikeStreetsStyles.style(
        forLayer: identifier,
        source: identifier,
        lineColor: StyleColor(color),
        lineWidth: .expression(
          Exp(.interpolate) {
            Exp(.linear)
            Exp(.zoom)
            14
            6
            18
            12
          }
        )
      )

      // Add the source and style layer to the map style.
      try! mapView.mapboxMap.style.addSource(geoJSONSource, id: identifier)
      try! mapView.mapboxMap.style.addPersistentLayer(
        lineLayer,
        layerPosition: layerPosition
      )
    }

    var layerIdsToRemove: [String] = [geoJSONDataSourceIdentifier]
    layerIdsToRemove.append(contentsOf: mapView.mapboxMap.style.allLayerIdentifiers
                              .map { $0.id }
                              .filter { $0.hasPrefix(geoJSONDataSourceIdentifierOSRM) }
                            )
    layerIdsToRemove.forEach(removeLayer(withId:))

    guard let routes else { return }
    for (routeIndex, route) in routes.enumerated() {
      addLayer(
        withIdentifier: "\(geoJSONDataSourceIdentifierOSRM)-\(routeIndex)",
        color: .vamosYellow,
        route: route,
        layerPosition: .below(MapLayerSpec.bottomLayerIdentifier)
      )
    }
  }
  
  // MARK: - Route Requests
  private func requestRoute(request: StateManager.RouteRequest) {
    RouteRequester.getOSRMDirections(
      startPoint: request.origin.coordinate,
      endPoint: request.destination.coordinate,
      bearing: request.bearing
    ) { [weak self] result in
      DispatchQueue.main.async {
        self?.handleRouteResponse(result, forRequest: request)
      }
    }
  }
  
  private func handleRouteResponse(_ result: Result<CustomRouteResponse, Error>, forRequest request: StateManager.RouteRequest) {
    switch result {
    case .success(let result):
      switch rerouteManager.state {
      case .rerouting:
        // Do nothing if a reroute is requested but returns no options
        guard result.routes?.first != nil, let router = navigationViewController?.navigationService.router else {
            rerouteManager.state = .idle
            break 
        }
        
        router.updateRoute(with: IndexedRouteResponse(routeResponse: result.osrm, routeIndex: 0), routeOptions: nil, completion: {
          [weak self] _ in
          guard let self else { return }
          self.rerouteManager.state = .idle
        })
        
      case .idle:
        // Ensure we only process routes when they exists, otherwise don't change state.        
        if result.routes?.first != nil {
          // On initial state update, assume first route is selected.
          self.stateManager.state = .previewDirections(
            preview: .init(
              request: request,
              response: result
            )
          )
        } else {
          // TODO: Improve the state when a route is requested but returns no options.
          self.stateManager.state = .initial
        }
      }
    case .failure(let error):
      // TODO: Handle route request errors.
      rerouteManager.state = .idle
      print(error)
    }
  }
}

// MARK: -- NavigationViewControllerDelegate

extension DefaultMapsViewController: NavigationViewControllerDelegate {
  func navigationViewController(_ navigationViewController: NavigationViewController, shouldRerouteFrom location: CLLocation) -> Bool {
    // Location passed here does not contain course (direction) info. Use location stashed by progressDidChange.
    guard rerouteManager.canRequestReroute, let activeLocation = rerouteManager.location, case .routing(let routing) = stateManager.state else { return false }
    
    let request = StateManager.RouteRequest(
      origin: .currentLocation(coordinate: activeLocation.coordinate),
      destination: routing.request.destination,
      bearing: activeLocation.course
    )
    
    rerouteManager.state = .rerouting
    requestRoute(request: request)
    
    return false
  }
  
  func navigationViewController(_ navigationViewController: NavigationViewController, didRerouteAlong route: MapboxDirections.Route) {
    rerouteManager.playRerouteSound()
  }

  func navigationViewControllerDidDismiss(
    _ navigationViewController: NavigationViewController,
    byCanceling canceled: Bool
  ) {
    self.navigationViewController = nil

    // If still in routing state, transition back to initial.
    if case .routing = stateManager.state {
      stateManager.state = .initial
    }
  }

  func navigationViewController(
    _ navigationViewController: NavigationViewController,
    didSubmitArrivalFeedback feedback: EndOfRouteFeedback
  ) {
    guard MFMailComposeViewController.canSendMail() else { return }
    stateManager.state = .routingFeedback(feedback: feedback)
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
    case .initialTerms:
      let alertViewController = CustomAlertViewController(
        configuration: .init(
          body: "You must accept our Release and Waiver, Terms of Service, and Privacy Policy to use the app.",
          buttons: [
            .openURL(text: "View", url: URL(string: "https://www.bikestreets.com/terms")!),
            .accept(text: "Accept", callback: { [weak self] presentedViewController in
              guard let self else { return }
              presentedViewController.dismiss(animated: true)

              self.stateManager.state = {
                switch self.locationManager.internalAuthorizationStatus {
                case .requestPermissions:
                  return .requestingLocationPermissions
                case .insufficientAuthorization:
                  return .insufficientLocationPermissions
                case .granted:
                  return .initial
                }
              }()
            }),
          ]
        )
      )
      present(alertViewController, animated: true)
    case .requestingLocationPermissions:
      // Make the request for location with the system.
      locationManager.requestWhenInUseAuthorization()
    case .insufficientLocationPermissions:
      let alertViewController = CustomAlertViewController(
        configuration: .init(
          body: "To use the VAMOS app, you need to share your location.",
          buttons: [
            .accept(text: "Open Settings", callback: { presentedViewController in
              guard let url = URL(string: UIApplication.openSettingsURLString) else {
                 return
              }
              if UIApplication.shared.canOpenURL(url) {
                 UIApplication.shared.open(url, options: [:])
              }
            }),
          ]
        )
      )
      present(alertViewController, animated: true)
    case .initial:
      let shouldPresentSearchViewController: Bool = {
        switch oldState {
        case .initialTerms,
            .requestingLocationPermissions,
            .insufficientLocationPermissions,
            .previewDirections,
            .routing,
            .routingFeedback:
          return true
        default:
          return false
        }
      }()

      // Restart from the initial launch state.
      if shouldPresentSearchViewController {
        sheetManager.dismissAllSheets(animated: true) {
          self.presentInitialSearchViewController()
        }
      }

      // Clean any annotations.
      updateMapAnnotations(routes: nil)
    case .searchDestination:
      let searchViewController = SearchViewController(
        configuration: .initialDestination,
        stateManager: stateManager,
        sheetManager: sheetManager
      )
      searchViewController.modalTransitionStyle = .crossDissolve
      searchViewController.delegate = self
      sheetManager.present(
        searchViewController,
        animated: true,
        sheetOptions: .init(
          detents: [.small(), .medium(), .large()],
          selectedDetentIdentifier: .medium
        )
      )
    case .requestingRoutes(let request):
      // Potentially show destination on map
      // showAnnotation(.init(item: mapItem), cameraShouldFollow: false)
      // Potentially shift to smaller sheet presentation
      // sheetNavigationController.sheetPresentationController?.selectedDetentIdentifier = UISheetPresentationController.Detent.small().identifier
      requestRoute(request: request)
    case .previewDirections(let preview):
      updateMapAnnotations(routes: preview.routes)
    case .updateDestination:
      let searchViewController = SearchViewController(
        configuration: .newDestination,
        stateManager: stateManager,
        sheetManager: sheetManager
      )
      searchViewController.modalTransitionStyle = .crossDissolve
      searchViewController.delegate = self
      sheetManager.present(
        searchViewController,
        animated: true,
        sheetOptions: .init(
          detents: [.small(), .medium(), .large()],
          selectedDetentIdentifier: .medium,
          largestUndimmedDetentIdentifier: nil
        )
      )
    case .updateOrigin:
      let searchViewController = SearchViewController(
        configuration: .newOrigin,
        stateManager: stateManager,
        sheetManager: sheetManager
      )
      searchViewController.modalTransitionStyle = .crossDissolve
      searchViewController.delegate = self
      sheetManager.present(
        searchViewController,
        animated: true,
        sheetOptions: .init(
          detents: [.small(), .medium(), .large()],
          selectedDetentIdentifier: .medium,
          largestUndimmedDetentIdentifier: nil
        )
      )
    case .routing(let routing):
      switch GlobalSettings.liveRoutingConfiguration {
      case .mapbox:
        let indexedRouteResponse = IndexedRouteResponse(
          routeResponse: routing.response.osrm,
          routeIndex: routing.selectedRouteIndex
        )

        // Intentionally choose to NOT request any alternative routes since this,
        // generally, isn't a BikeStreets supported outcome and it drastically
        // increases battery drain by making constant requests to Mapbox despite
        // being unused/always failing.
        NavigationSettings.shared.initialize(with: .init(alternativeRouteDetectionStrategy: nil))

        let navigationService = MapboxNavigationService(
          indexedRouteResponse: indexedRouteResponse,
          customRoutingProvider: NavigationSettings.shared.directions,
          credentials: NavigationSettings.shared.directions.credentials,
          simulating: .onPoorGPS
        )
        #if targetEnvironment(simulator)
          // these 2 lines allow the route simulation to run faster.
          navigationService.simulationMode = .always
          navigationService.simulationSpeedMultiplier = 1.0
        #endif
        
        let navigationOptions = NavigationOptions(navigationService: navigationService)
        navigationViewController = NavigationViewController(
          for: indexedRouteResponse,
          navigationOptions: navigationOptions
        )
        navigationViewController?.modalPresentationStyle = .fullScreen
        navigationViewController?.delegate = self
        /// Disable "Report Problem" sheet that shows while navigating.
        navigationViewController?.showsReportFeedback = false
        navigationViewController?.showsEndOfRouteFeedback = false
        if let viewportDataSource = navigationViewController?.navigationMapView?.navigationCamera.viewportDataSource as? NavigationViewportDataSource {
          // Based on some experimentation, lowering the pitch for cycling seems appropriate compared to automobile, as speeds are lower and horizon doesn't need to be quite so far.
          viewportDataSource.options.followingCameraOptions.defaultPitch = 35.0
        }
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
        updateMapAnnotations(routes: [routing.selectedRoute])
      }
    case .routingFeedback(let feedback):
      // Can only present mail controller when sheets are dismissed.
      sheetManager.dismissAllSheets(animated: true)

      let vc = FeedbackEmailViewController(stateManager: stateManager, feedback: feedback)
      present(vc, animated: true)
    }

    // Sync up camera position/focus.
    mapCameraManager.state = {
      switch newState {
      case .initialTerms,
          .requestingLocationPermissions,
          .insufficientLocationPermissions:
        return .showDenver
      case .initial,
          .searchDestination,
          .requestingRoutes,
          .routingFeedback:
        return .followUserHeading
      case .previewDirections(let preview),
          .updateOrigin(let preview),
          .updateDestination(let preview):
        return .showRoute(routes: preview.routes)
      case .routing:
        switch GlobalSettings.liveRoutingConfiguration {
        case .mapbox: return .followUserHeading
        case .custom: return .routing
        }
      }
    }()
  }
  
  @objc func progressDidChange(_ notification: NSNotification) {
    let activeLocation = notification.userInfo?[RouteController.NotificationUserInfoKey.locationKey] as? CLLocation
    let routeProgress = notification.userInfo?[RouteController.NotificationUserInfoKey.routeProgressKey] as? RouteProgress
    
    rerouteManager.location = activeLocation
    
    if let navigationMapView = navigationViewController?.navigationMapView,
       let navigationViewportDataSource = navigationMapView.navigationCamera.viewportDataSource as? NavigationViewportDataSource {

      // Default camera settings for NavigationViewportDataSource will start to pitch forward at 180.0 meters before maneuvers, excepting "continue" and "merge" maneuvers. We want to get the center/zoom/overhead effect on all maneuvers, so we force the pitch towards zero as we approach any maneuver.
      var overridePitch = false
      let overridePitchDistanceThreshold: Double = 75.0
      if let distanceToNextManeuver = routeProgress?.currentLegProgress.currentStepProgress.distanceRemaining {
        if distanceToNextManeuver < overridePitchDistanceThreshold { overridePitch = true }
      }
      if overridePitch {
        navigationViewportDataSource.options.followingCameraOptions.pitchUpdatesAllowed = false
        navigationViewportDataSource.followingMobileCamera.pitch = 0.1
      } else {
        navigationViewportDataSource.options.followingCameraOptions.pitchUpdatesAllowed = true
        navigationViewportDataSource.followingMobileCamera.pitch = nil
      }
      
      // pitch = 0.0 seems to only be at the very beginning of the route when transitioning from overview.
      // Actual maneuver pitch is close to overhead at just above 0.0, so the goal here is to avoid rapid telescoping out/in at the point of departure
      if (navigationMapView.mapView.mapboxMap.cameraState.pitch < 20.0 && navigationMapView.mapView.mapboxMap.cameraState.pitch > 0.0) || overridePitch {
        navigationViewportDataSource.options.followingCameraOptions.zoomUpdatesAllowed = false
        navigationViewportDataSource.followingMobileCamera.zoom = navigationViewportDataSource.options.followingCameraOptions.zoomRange.upperBound + 1.0
        navigationViewportDataSource.options.followingCameraOptions.centerUpdatesAllowed = false
        navigationViewportDataSource.followingMobileCamera.center = activeLocation?.coordinate
      } else {
        navigationViewportDataSource.options.followingCameraOptions.zoomUpdatesAllowed = true
        navigationViewportDataSource.followingMobileCamera.zoom = nil
        navigationViewportDataSource.options.followingCameraOptions.centerUpdatesAllowed = true
        navigationViewportDataSource.followingMobileCamera.center = nil
      }
    }
  }
}

// MARK: - SizeTrackingListener

extension DefaultMapsViewController: SizeTrackingListener {
  func didChangeFrame(_ view: UIView, frame: CGRect) {
    // This is only valuable for the height, if it's 0, ignore.
    guard frame.height != 0 else { return }

    // Ensure the sheet size isn't hiding most of the screen.
    let screenHeight = UIScreen.main.bounds.size.height
    guard frame.height < screenHeight * 0.8 else { return }

    // Update map camera.
    syncCameraState(bottomInset: frame.height)

    // Update Mapbox ornaments. Mapbox insets the ornaments by the safe
    // area so include that in our ornament offset calculations.
    let safeAreaBottomPadding = UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0
    let mapboxOrnamentYInset = frame.height + 8 - safeAreaBottomPadding
    mapView.ornaments.options.logo.margins = .init(x: 8.0, y: mapboxOrnamentYInset)
    mapView.ornaments.options.compass.margins = .init(x: 8.0, y: mapboxOrnamentYInset)
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

    // Show puck in all cases except when showing Denver
    // since it requests location permissions as part of
    // setting this value.
    switch mapCameraManager.state {
    case .showDenver: break
    default:
      // Show user location puck
      mapView.location.options.puckType = .puck2D()
    }

    switch mapCameraManager.state {
    case .showDenver:
      let cameraOptions = CameraOptions(
        center: .denver,
        zoom: MapZoomOptions.defaultZoomLevel
      )
      mapView.mapboxMap.setCamera(to: cameraOptions)

      /// No new camera state.
      newState = nil
    case .followUserPosition:
      newState = mapView.viewport.makeFollowPuckViewportState(
        options: FollowPuckViewportStateOptions(
          padding: UIEdgeInsets(top: 200, left: 0, bottom: bottomInset, right: 0),
          zoom: MapZoomOptions.defaultZoomLevel,
          // Intentionally avoid bearing sync in search mode.
          bearing: .none,
          pitch: 0
        )
      )
    case .showRoute(let routes):
      // Zoom to show a single route or all routes.
      let cameraTopInset: CGFloat = self.view.safeAreaInsets.top

      let coordinates: [CLLocationCoordinate2D] = {
        return routes.flatMap { $0.coordinates }
      }()

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
    case .routing:
      newState = mapView.viewport.makeFollowPuckViewportState(
        options: FollowPuckViewportStateOptions(
          padding: UIEdgeInsets(
            // This ends up being the offset from the middle of the viewport.
            top: (view.bounds.height - bottomInset) * 0.75,
            left: 0,
            bottom: bottomInset, 
            right: 0
          ),
          // Higher is more zoomed in
          zoom: 20,
          bearing: .heading,
          // Less is closer to the straight on view of 0°
          pitch: 60
        )
      )
    case .followUserPositionIdle,
        .followUserHeadingIdle,
        .routingIdle,
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
    // on failure to transition, try one more time to transition to the attempted state
    switch reason {
    case .transitionFailed:
      viewportTransitionFailureCount += 1
      if viewportTransitionFailureCount <= 1 {
        switch fromStatus {
        case .transition(_, let state):
          mapView.viewport.transition(to: state)
          return
        default:
          break
        }
      } else {
        // retry failed -> reset the counter and proceed
        viewportTransitionFailureCount = 0
      }
    case .transitionSucceeded:
      viewportTransitionFailureCount = 0
    default: break
    }

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

// MARK: -- CLLocationManagerDelegate

extension DefaultMapsViewController: CLLocationManagerDelegate {
  public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
    // Only change state if location granted.
    switch stateManager.state {
    case .requestingLocationPermissions, .insufficientLocationPermissions: break
    default: return
    }

    switch manager.internalAuthorizationStatus {
    case .requestPermissions:
      // This happens when the user selects "Ask Next Time Or When I Share"
      // but the setting should just be updated in the Settings so redirect
      // them back to the permission screen.
      break
    case .insufficientAuthorization:
      stateManager.state = .insufficientLocationPermissions
    case .granted:
      stateManager.state = .initial
    }
  }
}
