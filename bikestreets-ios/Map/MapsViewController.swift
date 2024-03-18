//
//  MapsViewController.swift
//  MapboxTester
//
//  Created by Matt Robinson on 6/30/23.
//

import MapboxMaps
import MapboxSearch
import MapboxNavigation
import MapKit

class MapsViewController: UIViewController {
  internal let navigationMapView = NavigationMapView(frame: .zero)
  
  internal lazy var mapView: MapView = {
    return navigationMapView.mapView
  }()

  lazy var polylineAnnotationManager = mapView.annotations.makePolylineAnnotationManager()
  lazy var annotationsManager = mapView.annotations.makePointAnnotationManager()
  lazy var circleAnnotationsManager = mapView.annotations.makeCircleAnnotationManager()
  
  init() {
    super.init(nibName: nil, bundle: nil)

    mapView.mapboxMap.onNext(event: .mapLoaded) { _ in
      self.loadMapFromShippedResources()
    }
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()

    view.addSubview(mapView)

    navigationMapView.disableTranslatesAutoresizingMaskIntoConstraints()
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

    // Hide Mapbox 'i' button
    mapView.ornaments.options.attributionButton.margins = .init(x: -10000, y: 0)
    // Move Mapbox compass
    mapView.ornaments.options.compass.position = .bottomRight
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
  
  // MARK: -- Layer Placement
  
  internal var belowRoadLabelLayer: LayerPosition? {
    let id = "road-label"
    let roadLabelId =  mapView.mapboxMap.style.styleManager.styleLayerExists(forLayerId: id) ? id : nil
    
    guard let roadLabelId else { return nil }
    return .below(roadLabelId)
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

  private var currentMapboxStyle: StyleURI {
    if traitCollection.userInterfaceStyle == .dark {
      return .dark
    } else {
      return .vamosStreets
    }
  }

  private func updateMapStyle() {
    let style: StyleURI = currentMapboxStyle

    // Only update anything if style is different.
    guard mapView.mapboxMap.style.uri != style else {
      return
    }

    mapView.mapboxMap.loadStyleURI(style, completion: nil)
  }
}

// MARK: - Load Bike Streets Data

extension MapsViewController {
  /**
   * Load the default Bike Streets map from KML resources files bundled into the app
   */
  private func loadMapFromShippedResources() {
    MapLayerSpec.allCases.forEach { spec in
      loadMapLayer(from: spec)
    }
  }

  /// From: https://docs.mapbox.com/ios/maps/examples/line-gradient/
  private func loadMapLayer(from spec: MapLayerSpec) {
    // Attempt to decode GeoJSON from file bundled with application.
    guard let featureCollection = try? spec.decodeGeoJSON() else { return }

    // Only reload if not currently present since these layers don't change.
    if mapView.mapboxMap.style.layerExists(withId: spec.identifier) {
      // Remove layers in the future, if desired
      //  try! mapView.mapboxMap.style.removeLayer(withId: geoJSONDataSourceIdentifier)
      //  try! mapView.mapboxMap.style.removeSource(withId: geoJSONDataSourceIdentifier)
    } else {
      // Create a GeoJSON data source.
      var geoJSONSource = GeoJSONSource()
      geoJSONSource.data = .featureCollection(featureCollection)
      geoJSONSource.lineMetrics = true // MUST be `true` in order to use `lineGradient` expression

      // Create a line layer
      let lineLayer = BikeStreetsStyles.style(
        forLayer: spec.identifier,
        source: spec.identifier,
        lineColor: spec.mapLayerColor
      )

      // Add the source and style layer to the map style.
      try! mapView.mapboxMap.style.addSource(
        geoJSONSource,
        id: spec.identifier
      )
      
      try! mapView.mapboxMap.style.addPersistentLayer(lineLayer, layerPosition: belowRoadLabelLayer)
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

// MARK: - Locations

extension CLLocationCoordinate2D {
  /// Union Station
  static let denver = CLLocationCoordinate2D(
    latitude: 39.75318695812184,
    longitude: -105.00017364813098
  )
}

struct MapZoomOptions {
  static let defaultZoomLevel = 14.5
}
