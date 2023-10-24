//
//  MapsViewController.swift
//  MapboxTester
//
//  Created by Matt Robinson on 6/30/23.
//

import MapboxMaps
import MapboxSearch
import MapKit

protocol ExampleController: UIViewController {}

class MapsViewController: UIViewController, ExampleController {
  let mapView = MapView(frame: .zero)
  lazy var polylineAnnotationManager = mapView.annotations.makePolylineAnnotationManager()
  lazy var annotationsManager = mapView.annotations.makePointAnnotationManager()
  lazy var circleAnnotationsManager = mapView.annotations.makeCircleAnnotationManager()

  var isBikeStreetsNetworkEnabled: Bool = true {
    didSet {
      loadMapFromShippedResources()
    }
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    view.addSubview(mapView)

    mapView.disableTranslatesAutoresizingMaskIntoConstraints()
    [
      view.leftAnchor.constraint(equalTo: mapView.leftAnchor),
      view.rightAnchor.constraint(equalTo: mapView.rightAnchor),

      view.topAnchor.constraint(equalTo: mapView.topAnchor),
      view.bottomAnchor.constraint(equalTo: mapView.bottomAnchor),
    ].activate()

    // Start with map in Denver.
    let cameraOptions = CameraOptions(
      center: .denver,
      zoom: 15.5
    )
    mapView.mapboxMap.setCamera(to: cameraOptions)

    // Start by focusing on user's location, if present.
    let newState = self.mapView.viewport.makeFollowPuckViewportState(
      options: FollowPuckViewportStateOptions(
        padding: UIEdgeInsets(top: 200, left: 0, bottom: 200, right: 0),
        // Intentionally avoid bearing sync in search mode.
        bearing: .none,
        pitch: 0
      )
    )
    mapView.viewport.transition(to: newState, transition: self.mapView.viewport.makeImmediateViewportTransition())

    // Show user location puck
    mapView.location.options.puckType = .puck2D()

    // Hide Mapbox 'i' button
      mapView.ornaments.options.attributionButton.margins = .init(x: -10000, y: 0)

    // Show Mapbox styles
    updateMapStyle()
    DispatchQueue.main.async {
      // Initially, always load the BikeStreets map layers.
      self.loadMapFromShippedResources()
    }
  }

  // MARK: -- Annotations

  struct SearchAnnotation {
    let name: String
    let coordinate: CLLocationCoordinate2D

    init(searchResult: SearchResult) {
      name = searchResult.name
      coordinate = searchResult.coordinate
    }

    init(favoriteRecord: FavoriteRecord) {
      name = favoriteRecord.name
      coordinate = favoriteRecord.coordinate
    }

    init(item: MKMapItem) {
      name = item.name ?? "NO NAME"
      coordinate = item.placemark.coordinate
    }
  }

  func showAnnotation(_ item: SearchAnnotation, cameraShouldFollow: Bool = true) {
    showAnnotations([item], cameraShouldFollow: cameraShouldFollow)
  }

  func showAnnotations(_ items: [SearchAnnotation], cameraShouldFollow: Bool = true) {
    annotationsManager.annotations = items.map(PointAnnotation.init)

    circleAnnotationsManager.annotations = items.map { result in
      var annotation = CircleAnnotation(centerCoordinate: result.coordinate)
      annotation.circleColor = .init(.red)
      return annotation
    }

    if cameraShouldFollow {
      cameraToAnnotations(annotationsManager.annotations)
    }
  }

  // MARK: -- Camera

  func cameraToAnnotations(_ annotations: [PointAnnotation]) {
    cameraToCoordinates(annotations.map(\.point.coordinates))
  }

  func cameraToCoordinates(_ coordinates: [CLLocationCoordinate2D], topInset: CGFloat = 24, bottomInset: CGFloat = 24) {
    if coordinates.count == 1, let coordinate = coordinates.first {
      mapView.camera.fly(to: .init(center: coordinate, zoom: 15), duration: 0.25, completion: nil)
    } else {
      let coordinatesCamera = mapView.mapboxMap.camera(for: coordinates,
                                                       padding: UIEdgeInsets(top: topInset, left: 24, bottom: bottomInset, right: 24),
                                                       bearing: nil,
                                                       pitch: nil)
      mapView.camera.fly(to: coordinatesCamera, duration: 0.25, completion: nil)
    }
  }

  // MARK: -- Error Handling

  func showError(_ error: Error) {
    let alertController = UIAlertController(title: nil, message: error.localizedDescription, preferredStyle: .alert)
    alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))

    present(alertController, animated: true, completion: nil)
  }
}

// MARK: -- Dark Mode

extension MapsViewController {
  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)

    if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
      updateMapStyle()
    }
  }

  private func updateMapStyle() {
    let style: StyleURI
    if traitCollection.userInterfaceStyle == .dark {
      style = .dark
    } else {
      style = .streets
    }

    // Only update anything if style is different.
    guard mapView.mapboxMap.style.uri != style else {
      return
    }

    mapView.mapboxMap.loadStyleURI(style) { _ in
      // Resetting the style URI will unload the BikeStreets layers.
      self.loadMapFromShippedResources()
    }
  }
}

// MARK: - Load Bike Streets Data

extension MapsViewController {
  /**
   * Load the default Bike Streets map from KML resources files bundled into the app
   */
  private func loadMapFromShippedResources() {
    // TODO: Versioning scheme for the geojson data
    // TODO: Do we have a cached/downloaded version of the geojson data?
    // TODO: Is our cached version of geojson the latest & greatest?
    if let fileURLs = Bundle.main.urls(forResourcesWithExtension: "geojson", subdirectory: nil) {
      for fileURL in fileURLs {
        loadMapLayerFrom(fileURL)
      }
    }
  }

  /// Load GeoJSON file from local bundle and decode into a `FeatureCollection`.
  ///
  /// From: https://docs.mapbox.com/ios/maps/examples/line-gradient/
  private func decodeGeoJSON(from filePath: URL) throws -> FeatureCollection? {
    var featureCollection: FeatureCollection?
    do {
      let data = try Data(contentsOf: filePath)
      featureCollection = try JSONDecoder().decode(FeatureCollection.self, from: data)
    } catch {
      print("Error parsing data: \(error)")
    }
    return featureCollection
  }

  /// From: https://docs.mapbox.com/ios/maps/examples/line-gradient/
  private func loadMapLayerFrom(_ fileURL: URL) {
    // Attempt to decode GeoJSON from file bundled with application.
    guard let featureCollection = try? decodeGeoJSON(from: fileURL /* "GradientLine" */ ) else { return }

    //    let geoJSONDataSourceIdentifier = "geoJSON-data-source"
    // Get the layer name from the file name. We'll use it in a couple of places
    guard let geoJSONDataSourceIdentifier = fileURL.lastPathComponent.layerName() else {
      fatalError("Unable to locate layer name in file name \(fileURL.lastPathComponent)")
    }

    // Only reload if not currently present since these layers don't change.
    if mapView.mapboxMap.style.layerExists(withId: geoJSONDataSourceIdentifier) {
      if !isBikeStreetsNetworkEnabled {
        try! mapView.mapboxMap.style.removeLayer(withId: geoJSONDataSourceIdentifier)
        try! mapView.mapboxMap.style.removeSource(withId: geoJSONDataSourceIdentifier)
      }
    } else {
      // Create a GeoJSON data source.
      var geoJSONSource = GeoJSONSource()
      geoJSONSource.data = .featureCollection(featureCollection)
      geoJSONSource.lineMetrics = true // MUST be `true` in order to use `lineGradient` expression
      
      // Create a line layer
      let lineLayer = BikeStreetsStyles.style(forLayer: geoJSONDataSourceIdentifier, source: geoJSONDataSourceIdentifier)
      
      // Add the source and style layer to the map style.
      try! mapView.mapboxMap.style.addSource(geoJSONSource, id: geoJSONDataSourceIdentifier)
      try! mapView.mapboxMap.style.addLayer(lineLayer, layerPosition: nil)
    }
  }
}

// MARK: -

private extension String {
  func layerName() -> String? {
    let fileNameComponents = components(separatedBy: "-")
    if fileNameComponents.count >= 2 {
      return fileNameComponents[1]
    }
    return nil
  }
}

// MARK: -

extension PointAnnotation {
  init(item: MapsViewController.SearchAnnotation) {
    self.init(coordinate: item.coordinate)
    textField = item.name
  }
}

// MARK: -

extension CLLocationCoordinate2D {
  static let sanFrancisco = CLLocationCoordinate2D(latitude: 37.7911551, longitude: -122.3966103)
  static let denver = CLLocationCoordinate2D(latitude: 39.753580116073685, longitude: -105.04056378182935)
}
