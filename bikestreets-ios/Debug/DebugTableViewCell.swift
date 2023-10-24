//
//  DebugTableViewCell.swift
//  BikeStreets
//
//  Created by Matt Robinson on 9/17/23.
//

import MapboxDirections
import MapboxMaps
import UIKit

final class DebugTableViewCell: UITableViewCell {
  private let titleLabel = UILabel(frame: .zero)
  private let mapView = MapView(frame: .zero)
  private lazy var polylineAnnotationManager = mapView.annotations.makePolylineAnnotationManager()

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)

    contentView.addSubviews(titleLabel, mapView)

    mapView.isUserInteractionEnabled = false

    installConstraints()

    // Trigger zoom on load if configuration happens before map is loaded
    // on first configuration.
    mapView.mapboxMap.onNext(event: .mapLoaded) { [weak self] _ in
      guard let self, let route else { return }
      self.zoom(to: route)
    }
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func installConstraints() {
    [
      titleLabel,
      mapView,
    ].disableTranslatesAutoresizingMaskIntoConstraints()

    [
      contentView.topAnchor.constraint(equalTo: titleLabel.topAnchor, constant: -15),
      contentView.leftAnchor.constraint(equalTo: titleLabel.leftAnchor, constant: -15),
      contentView.rightAnchor.constraint(equalTo: titleLabel.rightAnchor, constant: 15),

      titleLabel.bottomAnchor.constraint(equalTo: mapView.topAnchor, constant: -15),
      contentView.bottomAnchor.constraint(equalTo: mapView.bottomAnchor, constant: 15),
      contentView.leftAnchor.constraint(equalTo: mapView.leftAnchor, constant: -15),
      contentView.rightAnchor.constraint(equalTo: mapView.rightAnchor, constant: 15),
    ].activate()
  }

  // MARK: -- Annotations

  private var route: Route?

  func configure(title: String, route: Route) {
    self.route = route

    titleLabel.text = title
    updateMapAnnotation(route: route)
    zoom(to: route)
  }

  private func zoom(to route: Route) {
    let state = mapView.viewport.makeOverviewViewportState(
      options: .init(
        geometry: LineString(route.shape?.coordinates ?? []),
        padding: .init(top: 8, left: 8, bottom: 8, right: 8)
      )
    )

    mapView.viewport.transition(to: state, transition: mapView.viewport.makeImmediateViewportTransition()) { _ in
      // the transition has been completed with a flag indicating whether the transition succeeded
    }
  }

  private func updateMapAnnotation(route: Route) {
    let selectedRouteAnnotations: [PolylineAnnotation] = route.legs.flatMap { leg -> [MapboxDirections.RouteStep] in
      leg.steps
    }.map { step -> PolylineAnnotation in
      return .activeRouteAnnotation(
        coordinates: step.shape?.coordinates ?? [],
        isRouting: false,
        isHikeABike: step.transportType == .walking
      )
    }

    polylineAnnotationManager.annotations = selectedRouteAnnotations
  }
}
